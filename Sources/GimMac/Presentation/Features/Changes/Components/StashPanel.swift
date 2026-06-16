import SwiftUI

struct StashPanel: View {
    let entry: StashEntry
    let busy: Bool
    let onRestore: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "tray.full")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Stashed Changes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(entry.message)
                .font(.callout)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button("Restore", action: onRestore)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(busy)
                Button("Discard", role: .destructive, action: onDiscard)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(busy)
                Spacer()
            }
        }
        .padding(10)
        .liquidGlassBackground(fallbackMaterial: .bar)
        .overlay(alignment: .top) { Divider() }
    }
}
