import SwiftUI

struct CommitRow: View {
    let title: String
    let subtitle: String
    let selected: Bool

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

            if selected {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .bold))
                    .padding(5)
                    .background(.white.opacity(0.18))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(selected ? Color.accentColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
