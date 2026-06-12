import SwiftUI

struct SuggestionCard: View {
    let title: String
    let subtitle: String?
    let hint: String
    let button: String
    var highlighted: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: highlighted ? "arrow.up.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Spacer()

            if highlighted {
                Button(button, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint("Performs this suggested action on the working tree")
            } else {
                Button(button, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint("Performs this suggested action on the working tree")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(highlighted ? AnyShapeStyle(.tint.opacity(0.1)) : AnyShapeStyle(.clear))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
