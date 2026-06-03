import SwiftUI

struct CommitRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let isUnpushed: Bool

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(selected ? Color.white.opacity(0.22) : Color.secondary.opacity(0.18))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(selected ? .white : .secondary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? .white.opacity(0.78) : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isUnpushed {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(selected ? Color.white : Color.accentColor)
                    .padding(5)
                    .background(selected ? Color.white.opacity(0.18) : Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
                    .help("This commit has not been pushed to the remote")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(selected ? Color.accentColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
