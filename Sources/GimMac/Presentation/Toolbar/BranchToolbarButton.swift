import SwiftUI

/// Branch picker control hosted by the unified window toolbar's `branch` item.
/// Extracted verbatim from the former `TopToolbar`; `BranchesPopoverButton`
/// self-disables when no branches view model is available, so the item is kept
/// always-shown-but-disabled rather than hidden (HIG: a stable toolbar layout is
/// preferable to items appearing/disappearing for an always-relevant action).
struct BranchToolbarButton: View {
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        BranchesPopoverButton(
            viewModelFactory: { [viewModel] in viewModel.makeBranchesViewModel() }
        ) {
            if viewModel.makeBranchesViewModel() != nil {
                ToolbarCard(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: "Branch",
                    value: RepositoryBranchDisplayFormatter.displayText(for: viewModel.tip),
                    showsHighlight: false
                )
            } else {
                ToolbarCard(
                    icon: "exclamationmark.triangle",
                    title: "Branch",
                    value: "Selector Unavailable",
                    showsHighlight: false
                )
            }
        }
        .disabled(viewModel.makeBranchesViewModel() == nil)
        .fixedSize()
    }
}
