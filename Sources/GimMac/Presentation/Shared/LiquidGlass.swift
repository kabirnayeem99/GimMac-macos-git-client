import SwiftUI

extension View {
    /// Backs a floating surface with Liquid Glass on macOS 26+, falling back to
    /// a system material on macOS 14–25 where `glassEffect` is unavailable.
    ///
    /// Use only for genuinely floating/distinct surfaces (cards, inset panels) —
    /// not full structural panes like a sidebar root, where the system material
    /// remains the correct, lighter-weight choice.
    @ViewBuilder
    func liquidGlassBackground(
        fallbackMaterial: Material,
        in shape: some Shape = Rectangle()
    ) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(fallbackMaterial, in: shape)
        }
    }
}
