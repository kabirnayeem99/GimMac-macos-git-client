import SwiftUI

struct RepositoryPickerDialog: View {
    let repositories: [StoredRepository]
    let selectedPath: String?
    let openRepositoryAction: () -> Void
    let selectRepositoryAction: (UUID) -> Void
    let abbreviatedPath: (String) -> String
    let rowTitle: (StoredRepository) -> String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Repositories")
                    .font(.title3.weight(.semibold))
                Text("Choose from all saved repositories.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding([.top, .horizontal], 20)
            .padding(.bottom, 12)

            Divider()

            if repositories.isEmpty {
                ContentUnavailableView(
                    "No Saved Repositories",
                    systemImage: "folder",
                    description: Text("Open a repository to add it to this list.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(repositories) { repository in
                    RepositoryPickerRow(
                        repository: repository,
                        isCurrent: repository.url.standardizedFileURL.path == selectedPath,
                        title: rowTitle(repository),
                        path: abbreviatedPath(repository.path),
                        action: {
                            selectRepositoryAction(repository.id)
                            dismiss()
                        }
                    )
                    .disabled(!repository.existsOnDisk)
                    .help(abbreviatedPath(repository.path))
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Button("Open Repository…") {
                    dismiss()
                    openRepositoryAction()
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 460, height: 420)
    }
}
