import SwiftUI

struct ChangedFileRow: View {
    let file: ChangedFile
    let selected: Bool
    let checked: Bool
    let onToggleChecked: () -> Void

    private var statusIcon: String {
        switch file.status {
        case .modified:
            return "pencil"
        case .added, .untracked:
            return "plus.circle"
        case .deleted:
            return "trash"
        case .renamed:
            return "arrow.left.arrow.right"
        case .unmerged:
            return "exclamationmark.triangle"
        case .ignored:
            return "eye.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .modified:
            return .orange
        case .added, .untracked:
            return .green
        case .deleted:
            return .red
        case .renamed:
            return .blue
        case .unmerged:
            return .yellow
        case .ignored, .unknown:
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleChecked) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? .white.opacity(0.9) : .secondary)
            }
            .buttonStyle(.plain)

            Text(file.path)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Color.white.opacity(0.9) : statusColor)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor : Color.clear)
        .foregroundStyle(selected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
