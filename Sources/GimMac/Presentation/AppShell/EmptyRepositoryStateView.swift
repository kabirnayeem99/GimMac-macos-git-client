import SwiftUI

struct EmptyRepositoryStateView: View {
    let openRepositoryAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didBounce = false
    @State private var isButtonHovered = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolEffect(.bounce, options: .nonRepeating, value: didBounce)
                .onAppear {
                    guard !reduceMotion else { return }
                    didBounce = true
                }

            Text("No Repository Selected")
                .font(.system(size: 22, weight: .semibold))

            Text("Select a local Git repository to view changes and history.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button("Select Repository") {
                openRepositoryAction()
            }
            .buttonStyle(EmptyStateButtonStyle(isHovered: isButtonHovered, reduceMotion: reduceMotion))
            .controlSize(.large)
            .onHover { isButtonHovered = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            openRepositoryAction()
        }
    }
}
