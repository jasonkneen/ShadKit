import ShadcnUI
import SwiftUI

/// AI Elements' `Response` / `MessageResponse` — the markdown renderer that
/// `Streamdown` provides on the web.
///
/// Handles the block grammar an assistant actually emits (headings, lists,
/// fenced code, quotes, rules, tables are left to `AICodeBlock`) and defers
/// inline spans to `AttributedString`'s markdown parser, so bold, italics,
/// inline code and links all work.
public struct AIResponse: View {
    private let markdown: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            ForEach(Array(AIMarkdownBlock.parse(markdown).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        // Deliberately not `maxWidth: .infinity` — that would make the view
        // greedy and stretch a user bubble, which is `w-fit`. Callers that want
        // it to fill (the assistant column) apply the frame themselves.
    }

    @ViewBuilder
    private func view(for block: AIMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inline(text)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? Space.x2 : 0)

        case let .paragraph(text):
            inline(text)
                .font(theme.typography.sans(theme.typography.sm))
                .lineSpacing(theme.typography.sm.lineSpacing)

        case let .list(items, isOrdered):
            VStack(alignment: .leading, spacing: Space.x1_5) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                        Text(isOrdered ? "\(index + 1)." : "•")
                            .font(theme.typography.sans(theme.typography.sm))
                            .foregroundStyle(palette.mutedForeground)
                            .frame(minWidth: isOrdered ? 18 : 10, alignment: .trailing)
                        inline(item)
                            .font(theme.typography.sans(theme.typography.sm))
                            .lineSpacing(theme.typography.sm.lineSpacing)
                    }
                }
            }
            .padding(.leading, Space.x1)

        case let .code(code, language):
            AICodeBlock(code: code, language: language)

        case let .quote(text):
            HStack(alignment: .top, spacing: Space.x3) {
                Rectangle()
                    .fill(palette.border)
                    .frame(width: 2)
                inline(text)
                    .font(theme.typography.sans(theme.typography.sm))
                    .foregroundStyle(palette.mutedForeground)
                    .lineSpacing(theme.typography.sm.lineSpacing)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .rule:
            ShadcnSeparator()
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: theme.typography.sans(theme.typography.xl2, weight: .semibold)
        case 2: theme.typography.sans(theme.typography.xl, weight: .semibold)
        case 3: theme.typography.sans(theme.typography.lg, weight: .semibold)
        default: theme.typography.sans(theme.typography.base, weight: .semibold)
        }
    }

    /// Renders inline markdown, falling back to the raw text if it doesn't
    /// parse — a half-streamed token should never blank the message.
    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        let source = AIMarkdownBlock.balancingEmphasis(text)
        if let attributed = try? AttributedString(markdown: source, options: options) {
            return Text(attributed)
        }
        return Text(source)
    }
}

/// The block-level grammar `AIResponse` understands.
enum AIMarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list(items: [String], isOrdered: Bool)
    case code(String, language: String?)
    case quote(String)
    case rule

    /// Splits markdown into blocks.
    ///
    /// Written as a single forward pass so a partially streamed document
    /// degrades gracefully: an unterminated fence still yields a code block.
    static func parse(_ source: String) -> [AIMarkdownBlock] {
        var blocks: [AIMarkdownBlock] = []
        var paragraph: [String] = []
        var listItems: [String] = []
        var listIsOrdered = false
        var quoteLines: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }
        func flushList() {
            guard !listItems.isEmpty else { return }
            blocks.append(.list(items: listItems, isOrdered: listIsOrdered))
            listItems.removeAll()
        }
        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            blocks.append(.quote(quoteLines.joined(separator: " ")))
            quoteLines.removeAll()
        }
        func flushAll() {
            flushParagraph()
            flushList()
            flushQuote()
        }

        var lines = source.components(separatedBy: .newlines)[...]

        while let line = lines.first {
            lines = lines.dropFirst()
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code — consume through the closing fence, or to the end.
            if trimmed.hasPrefix("```") {
                flushAll()
                let language = String(trimmed.dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                while let next = lines.first {
                    lines = lines.dropFirst()
                    if next.trimmingCharacters(in: .whitespaces).hasPrefix("```") { break }
                    body.append(next)
                }
                blocks.append(
                    .code(
                        body.joined(separator: "\n"),
                        language: language.isEmpty ? nil : language
                    )
                )
                continue
            }

            if trimmed.isEmpty {
                flushAll()
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushAll()
                blocks.append(.rule)
                continue
            }

            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                if hashes <= 6, trimmed.dropFirst(hashes).hasPrefix(" ") {
                    flushAll()
                    blocks.append(
                        .heading(
                            level: hashes,
                            text: String(trimmed.dropFirst(hashes + 1))
                        )
                    )
                    continue
                }
            }

            if trimmed.hasPrefix("> ") {
                flushParagraph()
                flushList()
                quoteLines.append(String(trimmed.dropFirst(2)))
                continue
            }

            if let item = unorderedItem(trimmed) {
                flushParagraph()
                flushQuote()
                if !listItems.isEmpty && listIsOrdered { flushList() }
                listIsOrdered = false
                listItems.append(item)
                continue
            }

            if let item = orderedItem(trimmed) {
                flushParagraph()
                flushQuote()
                if !listItems.isEmpty && !listIsOrdered { flushList() }
                listIsOrdered = true
                listItems.append(item)
                continue
            }

            flushList()
            flushQuote()
            paragraph.append(trimmed)
        }

        flushAll()
        return blocks
    }

    /// Neutralises unbalanced `**` so a single stray marker can't bold the
    /// rest of the message.
    ///
    /// This bites constantly while streaming — the closing marker simply hasn't
    /// arrived yet — and agents also emit runs like `****` between thoughts,
    /// which parse as an opening marker and swallow everything after them.
    static func balancingEmphasis(_ text: String) -> String {
        // Collapse runs of 3+ asterisks; they are never valid emphasis and are
        // usually two adjacent markers with nothing between them.
        var cleaned = ""
        var runLength = 0
        for character in text {
            if character == "*" {
                runLength += 1
            } else {
                if runLength > 0 {
                    cleaned += String(repeating: "*", count: runLength > 2 ? 2 : runLength)
                    runLength = 0
                }
                cleaned.append(character)
            }
        }
        if runLength > 0 {
            cleaned += String(repeating: "*", count: runLength > 2 ? 2 : runLength)
        }

        // An odd number of `**` markers leaves one open; drop the last.
        let markers = cleaned.components(separatedBy: "**").count - 1
        guard markers % 2 == 1, let last = cleaned.range(of: "**", options: .backwards)
        else { return cleaned }
        return cleaned.replacingCharacters(in: last, with: "")
    }

    private static func unorderedItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private static func orderedItem(_ line: String) -> String? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return String(rest.dropFirst(2))
    }
}
