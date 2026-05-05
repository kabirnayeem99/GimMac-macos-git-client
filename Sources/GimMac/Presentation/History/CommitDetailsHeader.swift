import SwiftUI

struct CommitDetailsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Text("Update MainSplitViewController.swift")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                Spacer()

                Button {
                } label: {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text("NK")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }

                Text("Naimul Kabir")
                    .font(.system(size: 11, weight: .medium))

                Text("18ac194")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(height: 78)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
