import ShadcnUI
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// AI Elements' `CodeBlock` — `rounded-md border bg-background` around a
/// `p-4 text-sm font-mono` listing, with the hover-revealed copy button.
///
/// Shiki isn't available natively, so highlighting is done by a small
/// tokeniser using Shiki's own `one-light` / `one-dark-pro` palettes. It covers
/// comments, strings, numbers, keywords and call sites — which is everything
/// that reads as "highlighted" at a glance.
public struct AICodeBlock: View {
    private let code: String
    private let language: String?
    private let showLineNumbers: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false
    @State private var didCopy = false

    public init(code: String, language: String? = nil, showLineNumbers: Bool = false) {
        self.code = code
        self.language = language
        self.showLineNumbers = showLineNumbers
    }

    private var lines: [String] {
        code.components(separatedBy: .newlines)
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 0) {
                            if showLineNumbers {
                                Text("\(index + 1)")
                                    .font(theme.typography.mono(theme.typography.sm))
                                    .foregroundStyle(palette.mutedForeground)
                                    .frame(minWidth: 40, alignment: .trailing)
                                    .padding(.trailing, Space.x4)
                                    .textSelection(.disabled)
                            }
                            AISyntaxLine(line: line, language: language)
                        }
                    }
                }
                .padding(Space.x4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .textSelection(.enabled)

            if isHovering {
                copyButton
                    .padding(Space.x2)
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.background)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var copyButton: some View {
        ShadcnButton(
            icon: didCopy ? ShadcnIcon.check : ShadcnIcon.copy,
            variant: .ghost,
            size: .iconSM
        ) {
            copy()
        }
        .accessibilityLabel(didCopy ? "Copied" : "Copy code")
    }

    private func copy() {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        withAnimation(.easeOut(duration: 0.12)) { didCopy = true }
        // The original resets the tick after 2s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.12)) { didCopy = false }
        }
    }
}

/// One highlighted line.
private struct AISyntaxLine: View {
    let line: String
    let language: String?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    var body: some View {
        let scheme = AISyntaxTheme.scheme(isDark: palette.isDark)
        let tokens = AISyntaxHighlighter.tokenize(line, language: language)

        tokens.reduce(Text("")) { partial, token in
            partial + Text(token.text)
                .foregroundColor(scheme.color(for: token.kind))
                .italic(token.kind == .comment)
        }
        .font(theme.typography.mono(theme.typography.sm))
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Highlighting

/// The token classes the highlighter distinguishes.
enum AISyntaxTokenKind: Sendable {
    case plain
    case keyword
    case string
    case number
    case comment
    case function
    case type
}

struct AISyntaxToken {
    let text: String
    let kind: AISyntaxTokenKind
}

/// Shiki's `one-light` and `one-dark-pro` token colours.
struct AISyntaxTheme {
    let plain: Color
    let keyword: Color
    let string: Color
    let number: Color
    let comment: Color
    let function: Color
    let type: Color

    func color(for kind: AISyntaxTokenKind) -> Color {
        switch kind {
        case .plain: plain
        case .keyword: keyword
        case .string: string
        case .number: number
        case .comment: comment
        case .function: function
        case .type: type
        }
    }

    static let oneLight = AISyntaxTheme(
        plain: Color(red: 0x38 / 255, green: 0x3A / 255, blue: 0x42 / 255),
        keyword: Color(red: 0xA6 / 255, green: 0x26 / 255, blue: 0xA4 / 255),
        string: Color(red: 0x50 / 255, green: 0xA1 / 255, blue: 0x4F / 255),
        number: Color(red: 0x98 / 255, green: 0x68 / 255, blue: 0x01 / 255),
        comment: Color(red: 0xA0 / 255, green: 0xA1 / 255, blue: 0xA7 / 255),
        function: Color(red: 0x40 / 255, green: 0x78 / 255, blue: 0xF2 / 255),
        type: Color(red: 0xC1 / 255, green: 0x84 / 255, blue: 0x01 / 255)
    )

    static let oneDarkPro = AISyntaxTheme(
        plain: Color(red: 0xAB / 255, green: 0xB2 / 255, blue: 0xBF / 255),
        keyword: Color(red: 0xC6 / 255, green: 0x78 / 255, blue: 0xDD / 255),
        string: Color(red: 0x98 / 255, green: 0xC3 / 255, blue: 0x79 / 255),
        number: Color(red: 0xD1 / 255, green: 0x9A / 255, blue: 0x66 / 255),
        comment: Color(red: 0x7F / 255, green: 0x84 / 255, blue: 0x8E / 255),
        function: Color(red: 0x61 / 255, green: 0xAF / 255, blue: 0xEF / 255),
        type: Color(red: 0xE5 / 255, green: 0xC0 / 255, blue: 0x7B / 255)
    )

    static func scheme(isDark: Bool) -> AISyntaxTheme {
        isDark ? .oneDarkPro : .oneLight
    }
}

/// A single-pass lexer. Deliberately language-loose: it recognises the shapes
/// common to C-family, Swift, Python, JSON and shell rather than modelling any
/// one grammar.
enum AISyntaxHighlighter {
    private static let sharedKeywords: Set<String> = [
        "if", "else", "for", "while", "return", "break", "continue", "switch",
        "case", "default", "do", "try", "catch", "throw", "throws", "finally",
        "import", "export", "from", "as", "in", "is", "new", "delete", "typeof",
        "instanceof", "void", "null", "nil", "true", "false", "undefined",
        "class", "struct", "enum", "protocol", "interface", "extension", "func",
        "function", "def", "var", "let", "const", "static", "public", "private",
        "internal", "protected", "final", "override", "async", "await", "yield",
        "guard", "defer", "where", "self", "this", "super", "init", "deinit",
        "type", "namespace", "package", "module", "with", "lambda", "pass",
        "raise", "except", "elif", "not", "and", "or", "mut", "fn", "impl",
        "trait", "use", "pub", "match", "loop", "go", "chan", "select", "defer",
    ]

    private static let typeNames: Set<String> = [
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
        "Any", "AnyObject", "Optional", "Result", "Error", "Data", "Date", "URL",
        "View", "Color", "Text", "number", "string", "boolean", "object",
    ]

    static func tokenize(_ line: String, language: String?) -> [AISyntaxToken] {
        // JSON has no keywords worth colouring but plenty of strings/numbers,
        // and `#` is not a comment there.
        let hashStartsComment = !(language.map { ["json", "jsonc", "js", "ts", "swift", "c", "cpp", "java", "go", "rust"].contains($0.lowercased()) } ?? false)

        var tokens: [AISyntaxToken] = []
        var current = ""
        var index = line.startIndex

        func flushPlain() {
            guard !current.isEmpty else { return }
            tokens.append(AISyntaxToken(text: current, kind: .plain))
            current = ""
        }

        while index < line.endIndex {
            let character = line[index]
            let rest = line[index...]

            // Line comments run to end of line — emit and stop.
            if rest.hasPrefix("//") || (hashStartsComment && character == "#") {
                flushPlain()
                tokens.append(AISyntaxToken(text: String(rest), kind: .comment))
                return tokens
            }

            // Strings.
            if character == "\"" || character == "'" || character == "`" {
                flushPlain()
                var literal = String(character)
                var cursor = line.index(after: index)
                while cursor < line.endIndex {
                    let next = line[cursor]
                    literal.append(next)
                    cursor = line.index(after: cursor)
                    // Skip the character after a backslash so `\"` doesn't end it.
                    if next == "\\", cursor < line.endIndex {
                        literal.append(line[cursor])
                        cursor = line.index(after: cursor)
                        continue
                    }
                    if next == character { break }
                }
                tokens.append(AISyntaxToken(text: literal, kind: .string))
                index = cursor
                continue
            }

            // Identifiers and keywords.
            if character.isLetter || character == "_" {
                flushPlain()
                var word = ""
                var cursor = index
                while cursor < line.endIndex,
                      line[cursor].isLetter || line[cursor].isNumber || line[cursor] == "_" {
                    word.append(line[cursor])
                    cursor = line.index(after: cursor)
                }

                let kind: AISyntaxTokenKind
                if sharedKeywords.contains(word) {
                    kind = .keyword
                } else if typeNames.contains(word) || word.first?.isUppercase == true {
                    kind = .type
                } else if cursor < line.endIndex, line[cursor] == "(" {
                    kind = .function
                } else {
                    kind = .plain
                }
                tokens.append(AISyntaxToken(text: word, kind: kind))
                index = cursor
                continue
            }

            // Numbers.
            if character.isNumber {
                flushPlain()
                var number = ""
                var cursor = index
                while cursor < line.endIndex,
                      line[cursor].isNumber || line[cursor] == "." || line[cursor] == "_"
                        || line[cursor].isHexDigit || line[cursor] == "x" {
                    number.append(line[cursor])
                    cursor = line.index(after: cursor)
                }
                tokens.append(AISyntaxToken(text: number, kind: .number))
                index = cursor
                continue
            }

            current.append(character)
            index = line.index(after: index)
        }

        flushPlain()
        return tokens
    }
}
