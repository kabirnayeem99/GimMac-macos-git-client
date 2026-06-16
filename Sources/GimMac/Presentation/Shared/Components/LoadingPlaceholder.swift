import SwiftUI

struct LoadingPlaceholder: View {
    var title: String = "Loading…"
    var minHeight: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .padding(12)
        .transition(.opacity)
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: title)
        .accessibilityElement(children: .combine)
    }
}
