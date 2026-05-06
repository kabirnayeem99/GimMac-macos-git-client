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
                },
                selectSavedRepositoryAction: { [weak self] id in
                    Task {
                        await self?.viewModel.selectPersistedRepository(id: id)
                    }
                }
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view = hostingView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { [weak self] in
            await self?.viewModel.bootstrapRepositorySelectionOnLaunch()
            await self?.applyUITestRepositoryIfPresent()
        }
    }

    private func applyUITestRepositoryIfPresent() async {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["GIMMAC_UI_TEST_REPO_PATH"], !path.isEmpty else {
            return
        }

        await viewModel.selectRepository(at: URL(fileURLWithPath: path, isDirectory: true))
    }

    private func openRepositoryTapped() {
        let panel = makeRepositoryOpenPanel()
        presentRepositoryPanel(panel)
    }

    private func makeRepositoryOpenPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "Choose Repository"
        panel.message = "Select a local Git repository."
        panel.prompt = "Open Repository"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = false
        panel.showsTagField = false
        panel.directoryURL = defaultRepositoryDirectoryURL()
        return panel
    }

    private func defaultRepositoryDirectoryURL() -> URL {
        if let selectedRepository = viewModel.selectedRepository {
            return selectedRepository.url.deletingLastPathComponent()
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func presentRepositoryPanel(_ panel: NSOpenPanel) {
        let handleSelection: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            Task { [weak self] in
                await self?.viewModel.selectRepository(at: url)
            }
        }

        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handleSelection)
            return
        }

        handleSelection(panel.runModal())
    }
}
