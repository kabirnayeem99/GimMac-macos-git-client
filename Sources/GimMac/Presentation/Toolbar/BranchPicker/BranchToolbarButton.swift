import SwiftUI
import AppKit
import Observation

/// Branch picker control hosted by the unified window toolbar's `branch` item.
///
/// Pull-down behavior:
/// - Shows local branches directly.
/// - Provides "Switch Branch…" for the full searchable branch picker.
/// - Provides "New Branch…" as a directly branch-related command.
/// - Keeps the toolbar item always present but disabled when unavailable.
struct BranchToolbarButton: View {
    let viewModel: RepositoryStoreViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBranchPickerPresented = false
    @State private var branchesViewModel: BranchesViewModel?
    @State private var branchLoadTask: Task<Void, Never>?

    private var branchDisplay: String {
        RepositoryBranchDisplayFormatter.displayText(for: viewModel.tip)
    }

    private var isSelectorAvailable: Bool {
        branchesViewModel != nil
    }

    private var iconName: String {
        "point.3.connected.trianglepath.dotted"
    }

    private var accessibilityValue: String {
        isSelectorAvailable
            ? branchDisplay
            : "Selector Unavailable"
    }

    var body: some View {
        Menu {
            if let branchesViewModel {
                BranchPullDownMenuContent(
                    viewModel: branchesViewModel,
                    showFullBranchPicker: {
                        isBranchPickerPresented = true
                    },
                    presentCreateBranch: {
                        presentCreateBranch(viewModel: branchesViewModel)
                    }
                )
            } else {
                Text("Branch selector unavailable")
                    .foregroundStyle(.secondary)
            }
        } label: {
            branchLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.visible)
        .frame(minWidth: 96, minHeight: 24)
        .disabled(!isSelectorAvailable)
        .help(isSelectorAvailable ? "Branch: \(branchDisplay)" : "Branch selector unavailable")
        .accessibilityLabel("Branch")
        .accessibilityValue(accessibilityValue)
        .popover(isPresented: $isBranchPickerPresented, arrowEdge: .top) {
            if let branchesViewModel {
                BranchesPickerPopover(viewModel: branchesViewModel)
            }
        }
        .onAppear {
            branchesViewModel = viewModel.makeBranchesViewModel()
            refreshBranchesViewModel()
            scheduleBranchLoad()
        }
        .onChange(of: viewModel.tip) {
            refreshBranchesViewModel()
        }
        .onChange(of: viewModel.selectedRepository?.url) {
            refreshBranchesViewModel()
            scheduleBranchLoad()
        }
        .onDisappear {
            branchLoadTask?.cancel()
            branchLoadTask = nil
        }
    }

    private var branchLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(branchDisplay)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: 96, maxWidth: 220, minHeight: 24, alignment: .leading)
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: branchDisplay)
        .id(branchDisplay)
        .transition(.opacity)
    }

    private func refreshBranchesViewModel() {
        guard let branchesViewModel else { return }

        let currentName: String?
        if case .valid(let summary) = viewModel.tip {
            currentName = summary.name
        } else {
            currentName = nil
        }

        branchesViewModel.setRepository(
            viewModel.selectedRepository?.url,
            currentBranchName: currentName
        )
    }

    private func presentCreateBranch(viewModel: BranchesViewModel) {
        guard let window = NSApplication.shared.keyWindow else { return }

        let presenter = BranchDialogPresenter(
            viewModel: viewModel,
            windowProvider: { window }
        )

        presenter.presentCreateBranch()
    }

    private func scheduleBranchLoad() {
        branchLoadTask?.cancel()
        guard let branchesViewModel, branchesViewModel.repositoryURL != nil else {
            branchLoadTask = nil
            return
        }
        branchLoadTask = Task {
            await branchesViewModel.loadBranches()
        }
    }
}
