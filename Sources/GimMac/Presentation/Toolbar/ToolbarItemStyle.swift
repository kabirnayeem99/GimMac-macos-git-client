import SwiftUI

/// A consistent style for toolbar items that handles hover, pressed, and disabled states.
/// This unifies the appearance of Repository (Menu), Branch (Popover), and Sync (Menu)
/// items in the top toolbar.
struct ToolbarItemStyle: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(highlightOpacity))
            )
            // Keep the whole rounded rect clickable, including the transparent
            // rest state, so hover/press track the full button — matching the
            // borderless Finder toolbar button hit area.
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(isEnabled ? 1.0 : 0.45)
            .onHover { isHovered = $0 }
            .onLongPressGesture(minimumDuration: 0, pressing: { isPressed = $0 }, perform: {})
    }

    /// Borderless native behavior: nothing at rest, a light fill on hover, a
    /// slightly stronger one while pressed.
    private var highlightOpacity: Double {
        guard isEnabled else { return 0 }
        if isPressed { return 0.12 }
        if isHovered { return 0.08 }
        return 0
    }
}

extension View {
    func toolbarItemStyle() -> some View {
        self.modifier(ToolbarItemStyle())
    }
}
