import SwiftUI

struct BranchesPickerPopover: View {
    let viewModel: BranchesViewModel

    var body: some View {
        BranchesViewControllerWrapper(viewModel: viewModel)
            .frame(minWidth: 360, minHeight: 420)
    }
}
