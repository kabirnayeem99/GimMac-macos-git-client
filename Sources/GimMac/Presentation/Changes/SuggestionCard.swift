import SwiftUI

struct SuggestionCard: View {
    let title: String
    let subtitle: String?
    let hint: String
    let button: String
    var highlighted: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var didConfirmAction = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: highlighted ? "arrow.up.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.leading)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .symbolReplacement(reduceMotion: reduceMotion)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }

                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .motion(Motion.snappy, reduceMotion: reduceMotion, value: isExpanded)

            Spacer()

            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(highlighted ? AnyShapeStyle(.tint.opacity(0.1)) : AnyShapeStyle(.clear))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onAppear {
            isExpanded = highlighted
        }
    }

    private func performAction() {
        didConfirmAction = true
        action()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            didConfirmAction = false
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        let label = HStack(spacing: 6) {
            if didConfirmAction {
                Image(systemName: "checkmark")
                    .symbolReplacement(reduceMotion: reduceMotion)
            }
            Text(button)
        }

        if highlighted {
            Button(action: performAction) {
                label
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityHint("Performs this suggested action on the working tree")
            .motion(Motion.feedback, reduceMotion: reduceMotion, value: didConfirmAction)
        } else {
            Button(action: performAction) {
                label
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityHint("Performs this suggested action on the working tree")
            .motion(Motion.feedback, reduceMotion: reduceMotion, value: didConfirmAction)
        }
    }
}
