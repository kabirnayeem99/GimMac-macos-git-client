import SwiftUI

struct ConfigureGitStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onGoBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Configure Git")
                    .font(.title2.weight(.semibold))
                Text("This identity is attached to every commit you create.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)

            Spacer()

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 14) {
                GridRow {
                    Text("Name")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField("Your name", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Email")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField("your@email.com", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 28)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Back") {
                    onGoBack()
                    viewModel.goBack()
                }
                .buttonStyle(.borderless)

                Spacer()

                if viewModel.isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                }

                Button("Finish") {
                    Task { await viewModel.save() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canFinish || viewModel.isSaving)

                if viewModel.completionOutcome == .success {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .symbolReplacement(reduceMotion: reduceMotion)
                        .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                        .onAppear { scheduleCompletion() }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .task { await viewModel.loadExistingConfig() }
    }

    private func scheduleCompletion() {
        let delay = reduceMotion ? 0.05 : 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak viewModel] in
            viewModel?.onComplete?()
            viewModel?.clearCompletionOutcome()
        }
    }
}
