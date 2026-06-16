import AppKit
import SwiftUI

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
