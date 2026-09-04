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
    /// Keys the block-parse cache alongside the source string. `nil` (the
    /// default) matches 0.3.x's source-only key exactly; pass a value when a
    /// caller's own layout genuinely depends on available width (e.g. a wide
    /// table that would otherwise degrade the same way regardless of the
    /// column it's rendering in).
    private let width: CGFloat?
    /// Overrides the mono family fenced code renders in — `nil` keeps
    /// `theme.typography.mono`'s family.
    private let codeFontFamily: String?
    /// Derives fenced-code token colours from the active `ShadcnPalette`
    /// instead of the fixed Shiki one-light/one-dark-pro hexes.
    private let usesPaletteCodeColours: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.aiMessageTextSize) private var messageTextSize

    public init(
        _ markdown: String,
        width: CGFloat? = nil,
        codeFontFamily: String? = nil,
        usesPaletteCodeColours: Bool = false
    ) {
        self.markdown = markdown
        self.width = width
        self.codeFontFamily = codeFontFamily
        self.usesPaletteCodeColours = usesPaletteCodeColours
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            ForEach(
                Array(AIMarkdownCache.blocks(for: markdown, width: width).enumerated()), id: \.offset
            ) { _, block in
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
                .font(theme.typography.sans(bodyStep))
                .lineSpacing(bodyStep.lineSpacing)

        case let .list(items):
            VStack(alignment: .leading, spacing: Space.x1_5) {
                ForEach(Array(Self.numbered(items).enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                        Text(entry.marker)
                            .font(theme.typography.sans(bodyStep))
                            .foregroundStyle(palette.mutedForeground)
                            .frame(minWidth: entry.item.isOrdered ? 20 : 12, alignment: .trailing)
                        inline(entry.item.text)
                            .font(theme.typography.sans(bodyStep))
                            .lineSpacing(bodyStep.lineSpacing)
                    }
                    .padding(.leading, CGFloat(entry.item.depth) * Space.x4)
                }
            }
            .padding(.leading, Space.x1)

        case let .code(code, language):
            AICodeBlock(
                code: code, language: language,
                fontFamily: codeFontFamily, usesPaletteColors: usesPaletteCodeColours)

        case let .table(headers, alignments, rows):
            tableView(headers: headers, alignments: alignments, rows: rows)

        case let .quote(text):
            HStack(alignment: .top, spacing: Space.x3) {
                Rectangle()
                    .fill(palette.border)
                    .frame(width: 2)
                inline(text)
                    .font(theme.typography.sans(bodyStep))
                    .foregroundStyle(palette.mutedForeground)
                    .lineSpacing(bodyStep.lineSpacing)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .rule:
            ShadcnSeparator()
        }
    }

    private var bodyStep: ShadcnTypography.Step {
        ShadcnTypography.Step(
            size: messageTextSize,
            lineHeight: max(messageTextSize * 1.45, messageTextSize + 6))
    }

    private func headingFont(_ level: Int) -> Font {
        let multiplier: CGFloat
        switch level {
        case 1: multiplier = 1.65
        case 2: multiplier = 1.4
        case 3: multiplier = 1.2
        default: multiplier = 1.08
        }
        return .system(size: messageTextSize * multiplier, weight: .semibold)
    }

    /// Renders inline markdown, falling back to the raw text if it doesn't
    /// parse — a half-streamed token should never blank the message.
    ///
    /// Cached: this runs once per block per body evaluation, and the transcript
    /// re-evaluates every message body on every streamed token.
    private func inline(_ text: String) -> Text {
        Text(AIMarkdownCache.inline(text))
    }

    /// Bullet glyphs cycle every three depths: `•` `‣` `◦`, matching the
    /// distinct-glyph-per-depth convention consumers expect.
    private static let bulletGlyphs = ["•", "‣", "◦"]

    struct NumberedListEntry {
        let item: AIMarkdownListItem
        let marker: String
    }

    /// Assigns a bullet glyph or a sequential ordinal to each item. Ordinal
    /// counters are keyed by depth and reset for a depth whenever a
    /// shallower item appears, so a later nested list restarts at 1 instead
    /// of continuing a previous one's count.
    private static func numbered(_ items: [AIMarkdownListItem]) -> [NumberedListEntry] {
        var counters: [Int: Int] = [:]
        return items.map { item in
            counters = counters.filter { $0.key <= item.depth }
            if item.isOrdered {
                let next = (counters[item.depth] ?? 0) + 1
                counters[item.depth] = next
                return NumberedListEntry(item: item, marker: "\(next).")
            }
            counters[item.depth] = 0
            return NumberedListEntry(
                item: item, marker: bulletGlyphs[item.depth % bulletGlyphs.count])
        }
    }

    @ViewBuilder
    private func tableView(
        headers: [String], alignments: [AIMarkdownTableAlignment], rows: [[String]]
    ) -> some View {
        Grid(alignment: .leading, horizontalSpacing: Space.x4, verticalSpacing: Space.x1_5) {
            GridRow {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    inline(header)
                        .font(theme.typography.sans(bodyStep, weight: .semibold))
                        .gridColumnAlignment(Self.columnAlignment(alignments, index))
                }
            }
            Divider().gridCellColumns(max(headers.count, 1))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                        inline(cell)
                            .font(theme.typography.sans(bodyStep))
                            .lineSpacing(bodyStep.lineSpacing)
                            .multilineTextAlignment(Self.textAlignment(alignments, index))
                            .gridColumnAlignment(Self.columnAlignment(alignments, index))
                    }
                }
            }
        }
    }

    private static func columnAlignment(
        _ alignments: [AIMarkdownTableAlignment], _ index: Int
    ) -> HorizontalAlignment {
        guard index < alignments.count else { return .leading }
        switch alignments[index] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private static func textAlignment(
        _ alignments: [AIMarkdownTableAlignment], _ index: Int
    ) -> TextAlignment {
        guard index < alignments.count else { return .leading }
        switch alignments[index] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

/// The block-level grammar `AIResponse` understands.
struct AIMarkdownListItem: Equatable {
    let text: String
    let depth: Int
    let isOrdered: Bool
}

enum AIMarkdownTableAlignment: Equatable {
    case leading
    case center
    case trailing
}

enum AIMarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list([AIMarkdownListItem])
    case code(String, language: String?)
    case quote(String)
    case table(headers: [String], alignments: [AIMarkdownTableAlignment], rows: [[String]])
    case rule

    /// Splits markdown into blocks.
    ///
    /// Written as a single forward pass so a partially streamed document
    /// degrades gracefully: an unterminated fence still yields a code block.
    static func parse(_ source: String) -> [AIMarkdownBlock] {
        var blocks: [AIMarkdownBlock] = []
        var paragraph: [String] = []
        var listItems: [AIMarkdownListItem] = []
        // Tracks the top-level (depth 0) list kind currently open, so two
        // adjacent top-level lists of different kinds ("- a" then "1. b")
        // stay two blocks, while a nested item of the other kind ("1. a" then
        // "   - b") stays inside the same block as its parent.
        var topLevelOrdered: Bool?
        var quoteLines: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }
        func flushList() {
            guard !listItems.isEmpty else { return }
            blocks.append(.list(listItems))
            listItems.removeAll()
            topLevelOrdered = nil
        }
        func appendListItem(_ item: AIMarkdownListItem) {
            if item.depth == 0, let topLevelOrdered, topLevelOrdered != item.isOrdered {
                flushList()
            }
            listItems.append(item)
            if item.depth == 0 { topLevelOrdered = item.isOrdered }
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

            // A pipe-led line with a following delimiter row is a table;
            // check before list/paragraph handling so "| a | b |" never
            // falls into either.
            if trimmed.hasPrefix("|"), let next = lines.first,
               let delimiter = tableDelimiterColumns(next.trimmingCharacters(in: .whitespaces)) {
                let headerCells = tableCells(trimmed)
                if headerCells.count == delimiter.count {
                    flushAll()
                    lines = lines.dropFirst()
                    var rows: [[String]] = []
                    while let candidate = lines.first,
                          candidate.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                        let cells = tableCells(candidate.trimmingCharacters(in: .whitespaces))
                        guard cells.count == headerCells.count else { break }
                        rows.append(cells)
                        lines = lines.dropFirst()
                    }
                    blocks.append(.table(headers: headerCells, alignments: delimiter, rows: rows))
                    continue
                }
            }

            let leadingSpaces = line.prefix { $0 == " " }.count

            if let item = unorderedItem(trimmed) {
                flushParagraph()
                flushQuote()
                appendListItem(AIMarkdownListItem(text: item, depth: leadingSpaces / 2, isOrdered: false))
                continue
            }

            if let item = orderedItem(trimmed) {
                flushParagraph()
                flushQuote()
                appendListItem(AIMarkdownListItem(text: item, depth: leadingSpaces / 2, isOrdered: true))
                continue
            }

            flushList()
            flushQuote()
            paragraph.append(trimmed)
        }

        flushAll()
        return blocks
    }

    /// A GFM delimiter row (`---`, `:---`, `:---:`, `---:` per cell,
    /// pipe-separated) parsed into per-column alignments, or `nil` if the
    /// line doesn't match that grammar at all.
    private static func tableDelimiterColumns(_ line: String) -> [AIMarkdownTableAlignment]? {
        guard line.hasPrefix("|") else { return nil }
        let cells = tableCells(line)
        guard !cells.isEmpty else { return nil }
        var alignments: [AIMarkdownTableAlignment] = []
        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  trimmed.allSatisfy({ $0 == "-" || $0 == ":" })
            else { return nil }
            let leftColon = trimmed.hasPrefix(":")
            let rightColon = trimmed.hasSuffix(":")
            switch (leftColon, rightColon) {
            case (true, true): alignments.append(.center)
            case (false, true): alignments.append(.trailing)
            default: alignments.append(.leading)
            }
        }
        return alignments
    }

    /// Splits a `| a | b |` row into trimmed cell strings.
    private static func tableCells(_ line: String) -> [String] {
        var body = line.trimmingCharacters(in: .whitespaces)
        if body.hasPrefix("|") { body.removeFirst() }
        if body.hasSuffix("|") { body.removeLast() }
        return body.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
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
