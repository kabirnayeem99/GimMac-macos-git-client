import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            switch viewModel.step {
            case .welcome:
                WelcomeStepView(viewModel: viewModel)
            case .configureGit:
                ConfigureGitStepView(viewModel: viewModel)
            }
        }
        .frame(width: 480, height: 380)
        .animation(.easeInOut(duration: 0.18), value: viewModel.step)
    }
}

struct WelcomeStepView: View {
    let viewModel: OnboardingViewModel

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
                Button("Get Started") { viewModel.advance() }
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
            }

            Spacer()

            HStack {
                Button("Back") { viewModel.goBack() }
                    .buttonStyle(.borderless)
                Spacer()
                Button("Finish") {
                    Task { await viewModel.save() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canFinish || viewModel.isSaving)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .task { await viewModel.loadExistingConfig() }
    }
}
