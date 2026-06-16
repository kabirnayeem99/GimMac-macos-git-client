import SwiftUI

struct RepositoryPickerRow: View {
    let repository: StoredRepository
    let isCurrent: Bool
    let title: String
    let path: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tint)
                    .opacity(isCurrent ? 1 : 0)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(path)
        .accessibilityHint(isCurrent ? "Selected repository" : "Selects this repository")
    }
}
