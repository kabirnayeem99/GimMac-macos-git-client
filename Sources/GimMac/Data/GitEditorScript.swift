import Foundation

/// Builds a controlled, executable wrapper script used as `GIT_SEQUENCE_EDITOR`
/// / `GIT_EDITOR`. Git invokes those editor commands through a shell, so a path
/// interpolated directly into the command string (e.g. `cat "\(path)" >`) is
/// shell-parsed — quotes, `$`, or backticks in the path mis-parse or, in
/// adversarial conditions, execute. This writes the payload to a temp file and a
/// small script that copies it over Git's target file (`$1`), with the payload
/// path single-quote escaped so its bytes are never shell-interpreted.
enum GitEditorScript {
    struct Handle {
        /// Value to assign to the editor environment variable (absolute script path).
        let editorCommand: String
        /// Removes the payload file and script. Call from a `defer`.
        let cleanup: @Sendable () -> Void
    }

    static func make(payload: String, label: String) throws -> Handle {
        let tempDir = FileManager.default.temporaryDirectory
        let runID = UUID().uuidString
        let payloadURL = tempDir.appendingPathComponent("gimmac-\(label)-payload-\(runID)")
        let scriptURL = tempDir.appendingPathComponent("gimmac-\(label)-editor-\(runID).sh")

        try payload.write(to: payloadURL, atomically: true, encoding: .utf8)

        let script = "#!/bin/sh\ncat \(singleQuoted(payloadURL.path)) > \"$1\"\n"
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let cleanup: @Sendable () -> Void = {
            try? FileManager.default.removeItem(at: payloadURL)
            try? FileManager.default.removeItem(at: scriptURL)
        }
        return Handle(editorCommand: scriptURL.path, cleanup: cleanup)
    }

    /// Wraps `value` in single quotes, escaping embedded single quotes, so the
    /// shell treats every other character literally.
    private static func singleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
