import SwiftUI

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
