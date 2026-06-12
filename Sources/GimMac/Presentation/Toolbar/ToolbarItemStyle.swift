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
                ZStack {
                    if isEnabled {
                        if isPressed {
                            Color.primary.opacity(0.12)
                        } else if isHovered {
                            Color.primary.opacity(0.08)
                        } else {
                            Color.primary.opacity(0.04)
                        }
                    }
                    Color.clear.background(.regularMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        Color.primary.opacity(
                            !isEnabled ? 0.02 : (isPressed ? 0.2 : (isHovered ? 0.15 : 0.05))
                        ),
                        lineWidth: 1
                    )
            }
            .opacity(isEnabled ? 1.0 : 0.5)
            .onHover { isHovered = $0 }
            .onLongPressGesture(minimumDuration: 0, pressing: { isPressed = $0 }, perform: {})
    }
}

extension View {
    func toolbarItemStyle() -> some View {
        self.modifier(ToolbarItemStyle())
    }
}
