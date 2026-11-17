import Foundation

/// This builds a child process that ends when the app does, including when the app is killed.
///
/// A child started with `Process` keeps running after its parent dies. The child's standard input
/// is a pipe that only this app holds open. When the app exits for any reason, the kernel closes
/// the pipe, and a watcher then ends the command.
nonisolated enum ParentBoundProcess {
    /// The shell replaces itself with the command, so the process is the command and `terminate()`
    /// reaches it. The watcher reads descriptor 3 because a background job's standard input is
    /// /dev/null.
    static let script = "exec 3<&0 </dev/null; ( /bin/cat <&3; kill $$ ) >/dev/null 2>&1 & exec \"$@\" 3<&-"

    /// This returns the process before it starts and the pipe that keeps it alive. Close the pipe's
    /// write end after the process ends so that the watcher also ends.
    ///
    /// - Parameter command: the executable path, then its arguments.
    static func make(command: [String]) -> (process: Process, lifeline: Pipe) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh"] + command

        let lifeline = Pipe()
        process.standardInput = lifeline

        return (process, lifeline)
    }
}
