import SwiftUI

struct SyncToolbarButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.96)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .motion(Motion.snappy, reduceMotion: reduceMotion, value: configuration.isPressed)
    }
}
