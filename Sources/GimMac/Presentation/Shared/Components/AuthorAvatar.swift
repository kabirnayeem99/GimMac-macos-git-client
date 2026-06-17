import SwiftUI

extension String {
    var initials: String {
        let parts = split(separator: " ").map(String.init)
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }

        if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2)).uppercased()
        }

        return "--"
    }
}

struct AuthorAvatar: View {
    let name: String
    var size: CGFloat = 28
    var fontSize: CGFloat = 10

    var body: some View {
        Circle()
            .fill(.quaternary)
            .frame(width: size, height: size)
            .overlay {
                Text(name.initials)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    HStack {
        AuthorAvatar(name: "Ada Lovelace")
        AuthorAvatar(name: "Grace")
        AuthorAvatar(name: "")
    }
    .padding()
}
