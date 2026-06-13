import SwiftUI

/// Icon-only toolbar control, styled after the Finder unified toolbar: a compact
/// rounded button showing a single SF Symbol plus a small disclosure chevron.
/// `title`/`value` are no longer rendered — they survive as the hover tooltip so
/// no information is lost when the row collapses to icons.
struct ToolbarCard: View {
    let icon: String
    let title: String
    let value: String
    /// When hosted inside an `NSViewRepresentable` (the branch popover button),
    /// hover/press can't be tracked by SwiftUI — the container draws the
    /// highlight in AppKit instead. Set false there to avoid a doubled/absent
    /// highlight and keep the rounded shape consistent across all toolbar items.
    var showsHighlight: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(height: 28)
        .padding(.horizontal, 10)
        .modifier(ConditionalToolbarItemStyle(enabled: showsHighlight))
        .help("\(title): \(value)")
    }
}

/// Applies `toolbarItemStyle()` only when `enabled`; otherwise leaves the
/// content transparent (the host container owns the highlight).
private struct ConditionalToolbarItemStyle: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.toolbarItemStyle()
        } else {
            content
        }
    }
}
