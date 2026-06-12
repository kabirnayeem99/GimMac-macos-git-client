import SwiftUI

struct ToolbarCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            // Fixed spacing instead of Spacer() allows the button to shrink to content
            // while maintaining a professional gap.
            Rectangle()
                .fill(.clear)
                .frame(width: 8)

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary) // More prominent than tertiary
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .toolbarItemStyle()
        .help(title)
    }
}
