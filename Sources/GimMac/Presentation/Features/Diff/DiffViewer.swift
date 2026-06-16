import SwiftUI

struct DiffViewer: View {
    let viewModel: RepositoryStoreViewModel
    var source: Source = .changes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        let mappedLines = document.lines.map { line in
            let kind: DiffKind
            switch line.kind {
            case .context:
                kind = .context
            case .added:
                kind = .added
            case .removed:
                kind = .removed
            case .hunk:
                kind = .hunk
            }

            return DiffLine(
                kind: kind,
                oldNumber: line.oldNumber,
                newNumber: line.newNumber,
                text: line.text,
                highlight: nil
            )
        }

        return DiffLineHighlighter.highlighted(mappedLines)
    }

    private var contentIdentity: String {
        if isLoading {
            return "loading:\(document.filePath)"
        }
        switch document.kind {
        case .binary:
            return "binary:\(document.filePath)"
        case .image:
            return "image:\(document.filePath)"
        case .submodule:
            return "submodule:\(document.filePath)"
        case .text:
            return lines.isEmpty ? "empty:\(document.filePath)" : "text:\(document.filePath)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DiffHeader(
                filePath: document.filePath,
                addedCount: document.addedCount,
                removedCount: document.removedCount
            )

            ZStack(alignment: .topLeading) {
                diffContent
                    .id(contentIdentity)
                    .transition(Motion.contentCrossfade(reduceMotion: reduceMotion))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .motion(Motion.spatial, reduceMotion: reduceMotion, value: contentIdentity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var diffContent: some View {
        if isLoading {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityElement()
                .accessibilityLabel("Diff")
                .accessibilityValue("Loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
        } else if case .binary = document.kind {
            DiffMessageView(symbol: "doc.zipper", message: "Binary file — content not shown.")
                .transition(.opacity)
        } else if case let .image(data) = document.kind {
            ImageDiffContentView(data: data)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
        } else if case let .submodule(data) = document.kind {
            SubmoduleDiffContentView(data: data)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
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
            .transition(.opacity)
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
            .defaultScrollAnchor(.topLeading)
            .transition(.opacity)
        }
    }
}
