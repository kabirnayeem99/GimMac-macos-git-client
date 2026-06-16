import Foundation

extension GitDiffProvider {
    /// Images above this size are not loaded/encoded into memory; the caller
    /// falls back to a binary marker. Base64 encoding inflates by ~33%, so the
    /// peak cost of an at-limit image is roughly 23 MB.
    static let maxImageBytes = 10 * 1024 * 1024

    func workingDirectoryImage(in repositoryURL: URL, for path: String) async throws -> ImageDiffContent {
        let fileURL = repositoryURL.appendingPathComponent(path)
        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maxImageBytes else {
            throw GitAppError.invalidOutput(command: ["show"], details: "image exceeds \(Self.maxImageBytes)-byte limit")
        }
        let data = try Data(contentsOf: fileURL)
        return ImageDiffContent(mediaType: Self.mediaType(for: path), base64Contents: data.base64EncodedString())
    }

    func blobImage(in repositoryURL: URL, for path: String, at ref: String) async throws -> ImageDiffContent {
        // Probe blob size first so an oversized blob is never read into memory.
        let sizeOutput = try await client.run(["cat-file", "-s", "\(ref):\(path)"], in: repositoryURL, timeout: 10).stdout
        let size = Int(sizeOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard size <= Self.maxImageBytes else {
            throw GitAppError.invalidOutput(command: ["cat-file", "-s", "\(ref):\(path)"], details: "image exceeds \(Self.maxImageBytes)-byte limit")
        }
        let data = try await client.runReturningData(["show", "\(ref):\(path)"], in: repositoryURL, timeout: 10)
        return ImageDiffContent(mediaType: Self.mediaType(for: path), base64Contents: data.base64EncodedString())
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "ico", "webp", "bmp", "svg", "avif"]

    internal static func isImagePath(_ path: String) -> Bool {
        imageExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    /// Media type by extension. Mirrors GitHub Desktop's mapping (note `jpg`/`jpeg`
    /// both report `image/jpg`).
    private static func mediaType(for path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpg"
        case "gif": return "image/gif"
        case "ico": return "image/x-icon"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "svg": return "image/svg+xml"
        case "avif": return "image/avif"
        default: return "application/octet-stream"
        }
    }
}
