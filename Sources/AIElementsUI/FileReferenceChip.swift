import ShadcnUI
import SwiftUI

/// Inline code that names a file — `Sources/App/Main.swift`, `README.md`,
/// `Foo.swift:120` — drawn as a small chip: a leading file glyph, a smaller
/// monospaced name and a quiet background, so a path in prose reads as a
/// reference rather than as more words.
enum AIFileReference {
    /// A conservative test, so version numbers, flags and code fragments in
    /// backticks are left as plain inline code: one token, no spaces, a
    /// leading letter, `.`, `_`, `~` or `/`, and an extension with a letter.
    static func isFileReference(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= 160,
              !text.contains(where: { $0.isWhitespace }),
              !text.contains("://") else { return false }
        let name = withoutLocation(text)
        guard let first = name.first,
              first.isLetter || "._~/@".contains(first) else { return false }
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return false }
        let ext = name[name.index(after: dot)...]
        guard (1...8).contains(ext.count),
              ext.allSatisfy({ $0.isLetter || $0.isNumber }),
              ext.contains(where: { $0.isLetter }) else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || "._-/~@+".contains($0) }
    }

    /// `Foo.swift:12:3` → `Foo.swift`.
    static func withoutLocation(_ text: String) -> String {
        var parts = text.split(separator: ":", omittingEmptySubsequences: false)
        while parts.count > 1, parts.last.map({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) == true {
            parts.removeLast()
        }
        return parts.joined(separator: ":")
    }

    static func symbol(for text: String) -> String {
        let name = withoutLocation(text)
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md", "txt", "markdown": return "doc.plaintext"
        case "json", "yml", "yaml", "toml", "plist", "conf": return "gearshape"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "heic": return "photo"
        case "sh", "zsh", "bash": return "terminal"
        default: return "doc.text"
        }
    }

    /// The paragraph with every file-reference code span swapped for a chip.
    /// Returns nil when there is none, so ordinary text keeps the cheap path.
    static func text(
        from attributed: AttributedString,
        palette: ShadcnPalette,
        theme: ShadcnTheme,
        size: CGFloat,
        glyphTint: Color? = nil
    ) -> Text? {
        var chips = 0
        var pieces: [Text] = []
        for run in attributed.runs {
            let slice = attributed[run.range]
            let plain = String(slice.characters)
            guard run.inlinePresentationIntent?.contains(.code) == true,
                  isFileReference(plain) else {
                pieces.append(Text(AttributedString(slice)))
                continue
            }
            chips += 1
            var label = AttributedString("\u{2009}\(plain)\u{2009}")
            label.font = theme.typography.mono(
                ShadcnTypography.Step(size: size * 0.86, lineHeight: size * 1.2))
            label.foregroundColor = palette.foreground.opacity(0.88)
            label.backgroundColor = palette.foreground.opacity(0.09)
            let glyph = Text(Image(systemName: symbol(for: plain)))
                .font(.system(size: size * 0.8, weight: .regular))
                .foregroundStyle(glyphTint ?? palette.mutedForeground)
            pieces.append(glyph + Text("\u{2009}") + Text(label))
        }
        guard chips > 0 else { return nil }
        return pieces.dropFirst().reduce(pieces[0]) { $0 + $1 }
    }
}
