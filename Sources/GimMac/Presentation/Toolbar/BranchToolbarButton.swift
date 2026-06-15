import SwiftUI

/// Branch picker control hosted by the unified window toolbar's `branch` item.
/// Extracted verbatim from the former `TopToolbar`; `BranchesPopoverButton`
/// self-disables when no branches view model is available, so the item is kept
/// always-shown-but-disabled rather than hidden (HIG: a stable toolbar layout is
/// preferable to items appearing/disappearing for an always-relevant action).
struct BranchToolbarButton: View {
    let viewModel: RepositoryStoreViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var branchDisplay: String {
        RepositoryBranchDisplayFormatter.displayText(for: viewModel.tip)
    }

    private var isSelectorAvailable: Bool {
        viewModel.makeBranchesViewModel() != nil
    }

    var body: some View {
        BranchesPopoverButton(
            viewModelFactory: { [viewModel] in viewModel.makeBranchesViewModel() },
            label: {
                if isSelectorAvailable {
                    ToolbarCard(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "Branch",
                        value: branchDisplay,
                        showsHighlight: false
                    )
                    .id(branchDisplay)
                    .transition(.opacity)
                } else {
                    ToolbarCard(
                        icon: "exclamationmark.triangle",
                        title: "Branch",
                        value: "Selector Unavailable",
                        showsHighlight: false
                    )
                }
            }
        )
        .disabled(!isSelectorAvailable)
        .fixedSize()
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: branchDisplay)
    }
}
