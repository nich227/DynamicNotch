import XCTest
@testable import DynamicNotch

@MainActor
final class FocusAssertionStateMemoTests: XCTestCase {
    private let onPayload = Data(#"{"data":[{"storeAssertionRecords":[{"assertionDetails":{"assertionDetailsModeIdentifier":"com.apple.focus.work"}}]}]}"#.utf8)
    private let offPayload = Data(#"{"data":[]}"#.utf8)

    func testReusesStateUntilFileIsRewritten() throws {
        let url = try makeAssertionsFile(contents: onPayload)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var reads = 0
        let memo = FocusAssertionStateMemo()
        let read: (URL) -> FocusAssertionState = { url in
            reads += 1
            return FocusAssertionsReader.shared.readState(at: url)
        }

        XCTAssertEqual(memo.state(at: url, read: read), .on(identifier: "com.apple.focus.work"))
        XCTAssertEqual(memo.state(at: url, read: read), .on(identifier: "com.apple.focus.work"))
        XCTAssertEqual(reads, 1)

        try offPayload.write(to: url)

        XCTAssertEqual(memo.state(at: url, read: read), .off)
        XCTAssertEqual(reads, 2)
    }

    func testReportsUnreadableAfterAccessIsLostWithoutRewrite() throws {
        let url = try makeAssertionsFile(contents: onPayload)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }

        let memo = FocusAssertionStateMemo()
        let read = FocusAssertionsReader.shared.readState(at:)

        XCTAssertEqual(memo.state(at: url, read: read), .on(identifier: "com.apple.focus.work"))

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        XCTAssertEqual(memo.state(at: url, read: read), .unreadable)

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        XCTAssertEqual(memo.state(at: url, read: read), .on(identifier: "com.apple.focus.work"))
    }

    func testMissingFileIsUnreadable() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Assertions.json")

        XCTAssertEqual(
            FocusAssertionStateMemo().state(at: url, read: FocusAssertionsReader.shared.readState(at:)),
            .unreadable
        )
    }

    private func makeAssertionsFile(contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Assertions.json")
        try contents.write(to: url)
        return url
    }
}
