import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var slideDirection: SlideDirection = .forward

    var body: some View {
        VStack(spacing: 0) {
            progressIndicator
                .padding(.top, 16)

            ZStack {
                stepContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: 380)
    }

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(step == viewModel.step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: step == viewModel.step ? 18 : 8, height: 4)
                    .motion(Motion.snappy, reduceMotion: reduceMotion, value: viewModel.step)
            }
        }
        .frame(height: 4)
    }

    private var stepContent: some View {
        Group {
            switch viewModel.step {
            case .welcome:
                WelcomeStepView(
                    viewModel: viewModel,
                    onAdvance: { slideDirection = .forward }
                )
            case .configureGit:
                ConfigureGitStepView(
                    viewModel: viewModel,
                    onGoBack: { slideDirection = .backward }
                )
            }
        }
        .transition(stepTransition)
        .motion(Motion.spatial, reduceMotion: reduceMotion, value: viewModel.step)
    }

    private var stepTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        let enteringEdge: Edge = slideDirection == .forward ? .trailing : .leading
        let exitingEdge: Edge = slideDirection == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: enteringEdge).combined(with: .opacity),
            removal: .move(edge: exitingEdge).combined(with: .opacity)
        )
    }

    private enum SlideDirection {
        case forward, backward
    }
}

struct WelcomeStepView: View {
    let viewModel: OnboardingViewModel
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                VStack(spacing: 8) {
                    Text("Welcome to GimMac")
                        .font(.largeTitle.weight(.semibold))
                    Text("A native macOS Git client. Before you start, set up your Git identity so your commits are attributed correctly.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }
            }
            Spacer()
            HStack {
                Button("Skip") { viewModel.skip() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Get Started") {
                    onAdvance()
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }
}

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
