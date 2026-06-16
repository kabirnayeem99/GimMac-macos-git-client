import SwiftUI

struct BranchesViewControllerWrapper: NSViewControllerRepresentable {
    let viewModel: BranchesViewModel

    func makeNSViewController(context: Context) -> BranchesViewController {
        BranchesViewController(viewModel: viewModel)
    }

    func updateNSViewController(
        _ nsViewController: BranchesViewController,
        context: Context
    ) {}
}
