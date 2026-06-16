import SwiftUI

struct DiffLineRow: View {
    let line: DiffLine

    private var marker: String {
        switch line.kind {
        case .context: " "
        case .added: "+"
        case .removed: "-"
        case .hunk: ""
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
        case .hunk:
            Color.blue.opacity(0.08)
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
        case .hunk:
            Color.blue.opacity(0.12)
        }
    }

    private var textForeground: Color {
        switch line.kind {
        case .hunk:
            Color.secondary
        default:
            Color.primary
        }
    }

    private var highlightBackground: Color {
        switch line.kind {
        case .added:
            Color.green.opacity(0.28)
        case .removed:
            Color.red.opacity(0.28)
        default:
            Color.clear
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

            lineText
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 760, alignment: .leading)
                .padding(.leading, 10)
                .foregroundStyle(textForeground)

            Spacer(minLength: 0)
        }
        .frame(height: 24)
        .background(background)
    }

    @ViewBuilder
    private var lineText: some View {
        if let highlight = line.highlight {
            let parts = highlightedTextParts(highlight)
            HStack(spacing: 0) {
                Text(parts.prefix)
                Text(parts.changed)
                    .background(highlightBackground)
                Text(parts.suffix)
            }
        } else {
            Text(line.text)
        }
    }

    private func highlightedTextParts(_ highlight: DiffLineHighlight) -> (prefix: String, changed: String, suffix: String) {
        let characters = Array(line.text)
        let start = min(highlight.location, characters.count)
        let end = min(start + highlight.length, characters.count)

        return (
            prefix: String(characters[..<start]),
            changed: String(characters[start..<end]),
            suffix: String(characters[end...])
        )
    }
}
