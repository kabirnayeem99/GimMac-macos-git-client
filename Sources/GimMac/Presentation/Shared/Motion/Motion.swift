import AppKit
import SwiftUI

enum OpOutcome: Equatable {
    case none
    case success
    case failure
}

enum Motion {
    static let feedback = Animation.easeInOut(duration: 0.18)
    static let snappy = Animation.snappy(duration: 0.22)
    static let spatial = Animation.spring(duration: 0.32)

    static func resolve(_ base: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : base
    }

    static func inlineStatus(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        )
    }

    static func contentCrossfade(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .opacity
    }
}

extension View {
    func motion(_ base: Animation, reduceMotion: Bool, value: some Equatable) -> some View {
        animation(Motion.resolve(base, reduceMotion: reduceMotion), value: value)
    }

    @ViewBuilder
    func symbolReplacement(reduceMotion: Bool) -> some View {
        if reduceMotion {
            contentTransition(.opacity)
        } else {
            contentTransition(.symbolEffect(.replace))
        }
    }

    func asyncDecodeFade(reduceMotion: Bool, isReady: Bool) -> some View {
        opacity(reduceMotion || isReady ? 1 : 0)
            .motion(Motion.feedback, reduceMotion: reduceMotion, value: isReady)
    }
}
