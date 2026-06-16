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
