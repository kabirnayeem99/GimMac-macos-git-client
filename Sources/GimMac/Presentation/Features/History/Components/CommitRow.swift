import SwiftUI

struct CommitRow: View {
    let authorName: String
    let title: String
    let subtitle: String
    let isUnpushed: Bool
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 9) {
            AuthorAvatar(name: authorName, size: 24, fontSize: 9)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isUnpushed {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
                    .background {
                        Circle()
                            .fill(Color.primary.opacity(0.12))
                    }
                    .help("This commit has not been pushed to the remote")
                    .accessibilityLabel("Unpushed commit")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            }
        }
        .motion(Motion.snappy, reduceMotion: reduceMotion, value: isSelected)
    }
}
