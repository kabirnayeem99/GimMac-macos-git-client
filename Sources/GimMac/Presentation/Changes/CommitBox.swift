import SwiftUI
import Observation

struct CommitBox: View {
    @Bindable var viewModel: RepositoryStoreViewModel
    @State private var isShowingProfile = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(viewModel.currentGitUser.initials)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .onHover { isHovered in
                        isShowingProfile = isHovered
                    }
                    .popover(isPresented: $isShowingProfile, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentGitUser.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(viewModel.currentGitUser.email)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                    }

                TextField("Summary (required)", text: $viewModel.commitSummary)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            TextField("Description", text: $viewModel.commitDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .lineLimit(4...8)
                .frame(maxWidth: .infinity)

            Button {
            } label: {
                Text(viewModel.commitButtonLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewModel.lastCommitSectionTitle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Undo") {}
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }

                Text(viewModel.lastCommitSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .font(.system(size: 11))
        }
        .padding(12)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
