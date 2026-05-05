import SwiftUI

struct DiffViewer: View {
    let viewModel: RepositoryStoreViewModel

    private var lines: [DiffLine] {
        viewModel.selectedDiffDocument.lines.map { line in
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
                filePath: viewModel.selectedDiffDocument.filePath,
                addedCount: viewModel.selectedDiffDocument.addedCount,
                removedCount: viewModel.selectedDiffDocument.removedCount
            )

            if viewModel.isLoadingDiff {
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
