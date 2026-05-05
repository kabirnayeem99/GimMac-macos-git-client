import SwiftUI

struct CommitBox: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text("NK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }

                TextField("Summary (required)", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            TextField("Description", text: .constant(""), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .lineLimit(4...8)
                .frame(maxWidth: .infinity)

            Button {
            } label: {
                Text("Commit to master")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Committed just now")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Undo") {}
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }

                Text("Update MainMenuFactory.swift")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .font(.system(size: 11))
        }
        .padding(12)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
