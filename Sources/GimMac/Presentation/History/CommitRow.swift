import SwiftUI

struct CommitRow: View {
    let title: String
    let subtitle: String
    let isUnpushed: Bool
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isUnpushed {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(5)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
                    .help("This commit has not been pushed to the remote")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .motion(Motion.snappy, reduceMotion: reduceMotion, value: isSelected)
    }
}
