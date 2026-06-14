import SwiftUI
import AppKit

struct DiffViewer: View {
    let viewModel: RepositoryStoreViewModel
    var source: Source = .changes

    enum Source {
        case changes
        case history
    }

    private var document: DiffDocument {
        switch source {
        case .changes: return viewModel.selectedDiffDocument
        case .history: return viewModel.historyDiffDocument
        }
    }

    private var isLoading: Bool {
        switch source {
        case .changes: return viewModel.isLoadingDiff
        case .history: return viewModel.isLoadingHistoryDiff
        }
    }

    private var lines: [DiffLine] {
        document.lines.map { line in
            let kind: DiffKind
            switch line.kind {
            case .context:
                kind = .context
            case .added:
                kind = .added
            case .removed:
                kind = .removed
            }

            return DiffLine(
                kind: kind,
                oldNumber: line.oldNumber,
                newNumber: line.newNumber,
                text: line.text
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DiffHeader(
                filePath: document.filePath,
                addedCount: document.addedCount,
                removedCount: document.removedCount
            )

            if isLoading {
                VStack(alignment: .leading, spacing: 0) {
                    ProgressView("Loading diff…")
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                    Spacer(minLength: 0)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: .textBackgroundColor))
            } else if case .binary = document.kind {
                DiffMessageView(symbol: "doc.zipper", message: "Binary file — content not shown.")
            } else if case let .image(data) = document.kind {
                ImageDiffContentView(data: data)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: .textBackgroundColor))
            } else if case let .submodule(data) = document.kind {
                SubmoduleDiffContentView(data: data)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: .textBackgroundColor))
            } else if lines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("No diff available")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { line in
                            DiffLineRow(line: line)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }
}

/// Simple centered-message placeholder (binary / informational states).
private struct DiffMessageView: View {
    let symbol: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.tertiary)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

/// Renders an image diff as before/after previews.
private struct ImageDiffContentView: View {
    let data: ImageDiffData

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                side("Previous", data.previous)
                side("Current", data.current)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func side(_ title: String, _ content: ImageDiffContent?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let content, let image = Self.image(from: content) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 320)
                    .border(Color(nsColor: .separatorColor))
            } else {
                Text(content == nil ? "—" : "Cannot preview")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 120, height: 120)
            }
        }
    }

    private static func image(from content: ImageDiffContent) -> NSImage? {
        guard let bytes = Data(base64Encoded: content.base64Contents) else { return nil }
        return NSImage(data: bytes)
    }
}

/// Renders a submodule gitlink change as a status summary.
private struct SubmoduleDiffContentView: View {
    let data: SubmoduleDiffData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .foregroundStyle(.tertiary)
                Text("Submodule \(data.path)")
                    .font(.system(size: 13, weight: .semibold))
            }
            if let old = data.oldSHA, let new = data.newSHA {
                Text("Commit \(String(old.prefix(7))) → \(String(new.prefix(7)))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                if data.commitChanged { Label("Commit changed", systemImage: "arrow.triangle.branch") }
                if data.modifiedChanges { Label("Modified content", systemImage: "pencil") }
                if data.untrackedChanges { Label("Untracked content", systemImage: "questionmark.circle") }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}
