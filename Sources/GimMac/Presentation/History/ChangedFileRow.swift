import SwiftUI

struct ChangedFileRow: View {
    let title: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)

            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            RoundedRectangle(cornerRadius: 2)
                .stroke(selected ? Color.white.opacity(0.8) : Color.orange, lineWidth: 1.3)
                .frame(width: 13, height: 13)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(selected ? Color.accentColor : Color.clear)
        .foregroundStyle(selected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
