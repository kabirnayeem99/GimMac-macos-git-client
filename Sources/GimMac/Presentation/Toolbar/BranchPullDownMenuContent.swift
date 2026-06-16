import SwiftUI

struct BranchPullDownMenuContent: View {
    let viewModel: BranchesViewModel
    let showFullBranchPicker: () -> Void
    let presentCreateBranch: () -> Void

    private let localBranchLimit = 12

    var body: some View {
        Section("Local Branches") {
            if viewModel.localBranches.isEmpty {
                Text(viewModel.isLoading ? "Loading Branches…" : "No Local Branches")
            } else {
                ForEach(viewModel.localBranches.prefix(localBranchLimit)) { branch in
                    Button {
                        Task {
                            await viewModel.switchBranch(to: branch)
                        }
                    } label: {
                        if branch.name == viewModel.currentBranchName {
                            Label(branch.name, systemImage: "checkmark")
                        } else {
                            Text(branch.name)
                        }
                    }
                }

                if viewModel.localBranches.count > localBranchLimit {
                    Button("More Branches…") {
                        showFullBranchPicker()
                    }
                }
            }
        }

        Divider()

        Section {
            Button {
                showFullBranchPicker()
            } label: {
                Label("Switch Branch…", systemImage: "arrow.triangle.branch")
            }

            Button {
                presentCreateBranch()
            } label: {
                Label("New Branch…", systemImage: "plus")
            }
        }
        .task {
            await viewModel.loadBranches()
        }
    }
}
