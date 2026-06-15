import SwiftUI

struct RepositoryScreen: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if viewModel.selectedRepository == nil {
                EmptyRepositoryStateView(openRepositoryAction: openRepositoryAction)
                    .transition(.opacity)
            } else {
                // The former in-content `TopToolbar` is now the window's native
                // unified `NSToolbar`, built by `MainToolbarController`.
                // The content container keeps the Changes and History native
                // split controllers alive across tab switches so divider
                // positions and first responder are preserved.
                RepositoryContentView(viewModel: viewModel, viewTab: viewModel.viewTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .animation(Motion.resolve(Motion.spatial, reduceMotion: reduceMotion), value: viewModel.selectedRepository == nil)
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 1180, minHeight: 740)
        .sheet(isPresented: Binding(
            get: { viewModel.isResolvingConflicts },
            set: { if !$0 { viewModel.cancelConflictResolution() } }
        )) {
            ConflictsDialogView(viewModel: viewModel)
        }
        .task {
            await viewModel.refreshRepositoryScreenData()
            await viewModel.loadSavedRepositories()
        }
    }
}

private struct EmptyRepositoryStateView: View {
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

private struct EmptyStateButtonStyle: ButtonStyle {
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
