import SwiftUI

struct DiffLineRow: View {
    let line: DiffLine

    private var marker: String {
        switch line.kind {
        case .context: " "
        case .added: "+"
        case .removed: "-"
        }
    }

    private var background: Color {
        switch line.kind {
        case .context:
            Color.clear
        case .added:
            Color.green.opacity(0.12)
        case .removed:
            Color.red.opacity(0.12)
        }
    }

    private var gutterBackground: Color {
        switch line.kind {
        case .context:
            Color.black.opacity(0.04)
        case .added:
            Color.green.opacity(0.18)
        case .removed:
            Color.red.opacity(0.18)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(line.oldNumber.map(String.init) ?? "")
                    .frame(width: 38, alignment: .trailing)

                Text(line.newNumber.map(String.init) ?? "")
                    .frame(width: 38, alignment: .trailing)

                Text(marker)
                    .frame(width: 24)
            }
            .foregroundStyle(.secondary)
            .padding(.trailing, 8)
            .background(gutterBackground)

            Text(line.text)
                .frame(minWidth: 760, alignment: .leading)
                .padding(.leading, 10)

            Spacer(minLength: 0)
        }
        .frame(height: 24)
        .background(background)
    }
}
