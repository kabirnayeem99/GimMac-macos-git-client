import SwiftUI

struct SuggestionCard: View {
    let title: String
    let subtitle: String?
    let hint: String
    let button: String
    var highlighted: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: highlighted ? "arrow.up.circle.fill" : "circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if highlighted {
                Button(button) {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Button(button) {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(highlighted ? Color.accentColor.opacity(0.08) : Color.clear)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
