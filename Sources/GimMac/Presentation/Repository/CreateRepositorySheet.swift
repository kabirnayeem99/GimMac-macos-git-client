import AppKit
import SwiftUI

/// Options sheet for creating a new local repository. Native equivalent of
/// GitHub Desktop's `create-repository` dialog. The view holds no services:
/// picker data is loaded via the injected `loadTemplates` closure and the
/// final selection is handed back through `onCreate`, mirroring the existing
/// `CreateTagSheet` / `CreateBranchFromCommitSheet` pattern.
struct CreateRepositorySheet: View {
    /// Loads `( gitignore template names, licenses )` from the catalog.
    let loadTemplates: () async -> ([String], [LicenseTemplate])
    /// Final selection: scaffolding options plus the destination directory.
    let onCreate: (RepositoryCreationOptions, URL) -> Void
    let onCancel: () -> Void

    /// Sentinel shown in the pickers for "no template / no license".
    private static let noneTag = "__none__"

    @State private var name = ""
    @State private var description = ""
    @State private var parentDirectory: URL?
    @State private var includeReadme = true
    @State private var gitIgnoreSelection = CreateRepositorySheet.noneTag
    @State private var licenseSelection = CreateRepositorySheet.noneTag

    @State private var gitIgnoreNames: [String] = []
    @State private var licenses: [LicenseTemplate] = []
    @State private var isWorking = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Destination = parent folder + repository name. `nil` until both are set.
    private var destinationURL: URL? {
        guard let parentDirectory, !trimmedName.isEmpty else { return nil }
        return parentDirectory.appendingPathComponent(trimmedName, isDirectory: true)
    }

    private var canCreate: Bool {
        destinationURL != nil && !isWorking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create a New Repository")
                    .font(.headline)
                Text("GimMac will run `git init` and scaffold the files you choose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Name")
                        .gridColumnAlignment(.trailing)
                    TextField("repository-name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Description")
                    TextField("Optional", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Local Path")
                    HStack(spacing: 8) {
                        Text(destinationPathLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(parentDirectory == nil ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Choose…", action: chooseParentDirectory)
                    }
                }
            }

            Toggle("Initialize this repository with a README", isOn: $includeReadme)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Git Ignore")
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $gitIgnoreSelection) {
                        Text("None").tag(Self.noneTag)
                        ForEach(gitIgnoreNames, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("License")
                    Picker("", selection: $licenseSelection) {
                        Text("None").tag(Self.noneTag)
                        ForEach(licenses) { Text($0.name).tag($0.name) }
                    }
                    .labelsHidden()
                }
            }

            HStack(spacing: 8) {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Create Repository", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 460)
        .task {
            let (names, loadedLicenses) = await loadTemplates()
            gitIgnoreNames = names
            licenses = loadedLicenses
        }
    }

    private var destinationPathLabel: String {
        destinationURL?.path ?? "Choose a parent folder…"
    }

    private func chooseParentDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Parent Folder"
        panel.message = "The repository will be created in a subfolder named after the repository."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK {
            parentDirectory = panel.url
        }
    }

    private func create() {
        guard let destinationURL else { return }
        isWorking = true
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = RepositoryCreationOptions(
            name: trimmedName,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            includeReadme: includeReadme,
            gitIgnoreTemplateName: gitIgnoreSelection == Self.noneTag ? nil : gitIgnoreSelection,
            licenseName: licenseSelection == Self.noneTag ? nil : licenseSelection,
            makeInitialCommit: true
        )
        onCreate(options, destinationURL)
    }
}
