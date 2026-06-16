import SwiftUI

struct EmptyStateButtonStyle: ButtonStyle {
    let isHovered: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(reduceMotion ? nil : Motion.snappy, value: configuration.isPressed)
            .animation(reduceMotion ? nil : Motion.snappy, value: isHovered)
    }
}
