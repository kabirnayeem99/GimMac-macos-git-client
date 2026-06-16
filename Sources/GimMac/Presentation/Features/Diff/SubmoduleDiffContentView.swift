import SwiftUI

/// Renders a submodule gitlink change as a status summary.
struct SubmoduleDiffContentView: View {
    let data: SubmoduleDiffData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .foregroundStyle(.tertiary)
                Text("Submodule \(data.path)")
                    .font(.system(size: 13, weight: .semibold))
            }
            if let old = data.oldSHA, let new = data.newSHA {
                Text("Commit \(String(old.prefix(7))) → \(String(new.prefix(7)))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                if data.commitChanged { Label("Commit changed", systemImage: "arrow.triangle.branch") }
                if data.modifiedChanges { Label("Modified content", systemImage: "pencil") }
                if data.untrackedChanges { Label("Untracked content", systemImage: "questionmark.circle") }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}
