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

    private var branchDisplay: String {
        RepositoryBranchDisplayFormatter.displayText(for: viewModel.tip)
    }

    private var isSelectorAvailable: Bool {
        branchesViewModel != nil
    }

    private var iconName: String {
        isSelectorAvailable
            ? "point.3.connected.trianglepath.dotted"
            : "exclamationmark.triangle"
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
            }
        } label: {
            branchLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .frame(minWidth: 76, maxWidth: 168, minHeight: 24)
        .disabled(!isSelectorAvailable)
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: branchDisplay)
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
            if let branchesViewModel {
                Task { await branchesViewModel.loadBranches() }
            }
        }
        .onChange(of: viewModel.tip) {
            refreshBranchesViewModel()
        }
        .onChange(of: viewModel.selectedRepository?.url) {
            refreshBranchesViewModel()
            if let branchesViewModel {
                Task { await branchesViewModel.loadBranches() }
            }
        }
    }

    private var branchLabel: some View {
        Label {
            Text(branchDisplay)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 7)
        .frame(height: 24)
        .frame(maxWidth: 168)
        .contentShape(Capsule())
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
}
