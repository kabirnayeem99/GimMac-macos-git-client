import SwiftUI

/// Applies `toolbarItemStyle()` only when `enabled`; otherwise leaves the
/// content transparent because the host container owns the highlight.
struct ConditionalToolbarItemStyle: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.toolbarItemStyle()
        } else {
            content
        }
    }
}
