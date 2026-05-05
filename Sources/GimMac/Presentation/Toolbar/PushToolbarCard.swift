import SwiftUI

struct PushToolbarCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Push origin")
                    .font(.system(size: 13, weight: .semibold))

                Text("Fetched 4 min ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("1")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
