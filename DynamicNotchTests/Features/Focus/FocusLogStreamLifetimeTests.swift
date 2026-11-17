import XCTest
@testable import DynamicNotch

final class FocusLogStreamLifetimeTests: XCTestCase {
    /// It prints its own process ID, then runs as a command until something stops it.
    private let longRunningCommand = ["/bin/sh", "-c", "echo $$; exec /bin/sleep 600"]

    private func makeRunning(
        _ command: [String]
    ) throws -> (process: Process, lifeline: Pipe, output: Pipe, exited: XCTestExpectation) {
        let (process, lifeline) = ParentBoundProcess.make(command: command)
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        let exited = expectation(description: "the command exited")
        process.terminationHandler = { _ in exited.fulfill() }

        try process.run()
        return (process, lifeline, output, exited)
    }

    private func readProcessID(from output: Pipe) -> Int32? {
        let line = String(data: output.fileHandleForReading.availableData, encoding: .utf8)
        return Int32((line ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A process that ended but still waits for its parent to read its status is not running.
    private func isRunning(_ processID: Int32) -> Bool {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "state=", "-p", String(processID)]
        let output = Pipe()
        ps.standardOutput = output
        ps.standardError = FileHandle.nullDevice
        guard (try? ps.run()) != nil else { return false }
        let state = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        ps.waitUntilExit()
        let trimmed = state.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.hasPrefix("Z")
    }

    /// The watcher is a child of the command, because the shell that started it became the command.
    private func watcherProcessIDs(of commandProcessID: Int32) -> [Int32] {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-P", String(commandProcessID)]
        let output = Pipe()
        pgrep.standardOutput = output
        pgrep.standardError = FileHandle.nullDevice
        guard (try? pgrep.run()) != nil else { return [] }
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        pgrep.waitUntilExit()
        return text.split(whereSeparator: \.isNewline).compactMap { Int32($0) }
    }

    private func waitUntilNoneRuns(_ processIDs: [Int32]) async throws -> Bool {
        for _ in 0..<500 {
            if !processIDs.contains(where: isRunning) { return true }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }

    func testCommandEndsWhenTheLifelineCloses() async throws {
        let (process, lifeline, output, exited) = try makeRunning(longRunningCommand)
        XCTAssertEqual(readProcessID(from: output), process.processIdentifier)
        XCTAssertTrue(process.isRunning)

        // The kernel does the same when the app exits or is killed.
        lifeline.fileHandleForWriting.closeFile()

        await fulfillment(of: [exited], timeout: 5)
        XCTAssertEqual(process.terminationReason, .uncaughtSignal)
        XCTAssertEqual(process.terminationStatus, SIGTERM)
    }

    func testTerminateReachesTheCommandBecauseTheProcessIsTheCommand() async throws {
        let (process, lifeline, output, exited) = try makeRunning(longRunningCommand)
        let commandProcessID = try XCTUnwrap(readProcessID(from: output))
        XCTAssertEqual(commandProcessID, process.processIdentifier)

        let watchers = watcherProcessIDs(of: commandProcessID)
        XCTAssertFalse(watchers.isEmpty)

        process.terminate()

        await fulfillment(of: [exited], timeout: 5)
        XCTAssertFalse(isRunning(commandProcessID))

        lifeline.fileHandleForWriting.closeFile()
        let watchersEnded = try await waitUntilNoneRuns(watchers)
        XCTAssertTrue(watchersEnded, "the watcher must end once the lifeline closes")
    }

    func testCommandGetsItsArgumentsUnchangedAndWritesToTheOutputPipe() async throws {
        let (process, lifeline, output, exited) = try makeRunning(["/bin/echo", "a b", "c'd", "$HOME", "*"])

        await fulfillment(of: [exited], timeout: 5)
        lifeline.fileHandleForWriting.closeFile()

        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        XCTAssertEqual(text, "a b c'd $HOME *\n")
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testStreamBindsItsCommandToThisAppAndStopEndsBoth() async throws {
        let processIDFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusLogStreamLifetimeTests-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: processIDFile) }
        let stream = FocusLogStream(
            command: ["/bin/sh", "-c", "echo $$ > \"$0\"; exec /bin/sleep 600", processIDFile.path]
        )

        stream.start()

        var commandProcessID: Int32?
        for _ in 0..<500 where commandProcessID == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
            let text = (try? String(contentsOf: processIDFile, encoding: .utf8)) ?? ""
            commandProcessID = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let processID = try XCTUnwrap(commandProcessID)
        XCTAssertTrue(isRunning(processID))
        let watchers = watcherProcessIDs(of: processID)
        XCTAssertFalse(watchers.isEmpty, "the stream must start its command bound to this app")

        stream.stop()

        let allEnded = try await waitUntilNoneRuns([processID] + watchers)
        XCTAssertTrue(allEnded, "stop must end the command and its watcher")
    }
}
