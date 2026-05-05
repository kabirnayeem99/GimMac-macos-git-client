import SwiftUI

struct CommitHistorySidebar: View {
    @Binding var selectedTab: Int
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Changes").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .padding(10)

            Button {
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 12))

                    Text(viewModel.primaryAction.label)
                        .font(.system(size: 12))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            List(viewModel.commits.indices, id: \.self) { index in
                let commit = viewModel.commits[index]
                CommitRow(
                    title: commit.summary,
                    subtitle: "\(commit.authorDisplayName) • \(relativeString(for: commit.date))",
                    selected: index == viewModel.selectedHistoryCommitIndex
                )
                .onTapGesture {
                    viewModel.selectHistoryCommit(at: index)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(.thinMaterial)
    }

    private func relativeString(for date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
