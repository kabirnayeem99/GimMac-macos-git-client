import AppKit
import SwiftUI
import Observation

@MainActor
final class MainSplitViewController: NSViewController {
    private let viewModel: RepositoryStoreViewModel

    init(viewModel: RepositoryStoreViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let hostingView = NSHostingView(
            rootView: RepositoryScreen(
                viewModel: viewModel,
                openRepositoryAction: { [weak self] in
                    self?.openRepositoryTapped()
                }
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view = hostingView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyUITestRepositoryIfPresent()
    }

    private func applyUITestRepositoryIfPresent() {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["GIMMAC_UI_TEST_REPO_PATH"], !path.isEmpty else {
            return
        }

        Task { [weak self] in
            await self?.viewModel.selectRepository(at: URL(fileURLWithPath: path, isDirectory: true))
        }
    }

    private func openRepositoryTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Select a local Git repository."

        guard let window = view.window else {
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            Task { [weak self] in
                await self?.viewModel.selectRepository(at: url)
            }
        }
    }
}
