import SwiftUI

struct ChangedFilesHeader: View {
    let viewModel: RepositoryStoreViewModel
    let filteredCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allChecked: Bool {
        !viewModel.changedFiles.isEmpty &&
            viewModel.checkedChangedFilePaths.count == viewModel.changedFilesCount
    }

    private var someChecked: Bool {
        !viewModel.checkedChangedFilePaths.isEmpty && !allChecked
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if allChecked {
                    viewModel.deselectAllChangedFiles()
                } else {
                    viewModel.selectAllChangedFiles()
                }
            } label: {
                Image(systemName: selectionSymbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .symbolReplacement(reduceMotion: reduceMotion)
                    .motion(Motion.feedback, reduceMotion: reduceMotion, value: selectionSymbol)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.changedFiles.isEmpty)
            .help(allChecked ? "Deselect all" : "Select all")
            .accessibilityLabel(allChecked ? "Deselect all files" : "Select all files")
            .accessibilityValue(selectionAccessibilityValue)

            Text(countLabel)
                .font(.callout.weight(.medium))
                .contentTransition(.numericText(value: Double(filteredCount)))
                .motion(Motion.feedback, reduceMotion: reduceMotion, value: filteredCount)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(.bar)
    }

    private var selectionSymbol: String {
        allChecked ? "checkmark.square.fill" : (someChecked ? "minus.square.fill" : "square")
    }

    private var selectionAccessibilityValue: String {
        allChecked ? "All selected" : (someChecked ? "Some selected" : "None selected")
    }

    private var countLabel: String {
        let totalCount = viewModel.changedFilesCount
        guard filteredCount != totalCount else {
            return "\(filteredCount) changed \(filteredCount == 1 ? "file" : "files")"
        }
        return "\(filteredCount) of \(totalCount) changed \(totalCount == 1 ? "file" : "files")"
    }
}
