import ShadcnUI
import SwiftUI

/// One line of a diff.
public struct AIDiffLine: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case context
        case added
        case removed
        /// A `@@ … @@` header.
        case hunk
    }

    public let id: Int
    public var kind: Kind
    public var text: String
    /// 1-based line numbers in the old and new files; nil where the line
    /// doesn't exist on that side.
    public var oldNumber: Int?
    public var newNumber: Int?

    public init(
        id: Int,
        kind: Kind,
        text: String,
        oldNumber: Int? = nil,
        newNumber: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.oldNumber = oldNumber
        self.newNumber = newNumber
    }
}

/// Parses unified diff text into lines, tracking both line numbers.
public enum AIDiffParser {
    public static func parse(unified: String) -> [AIDiffLine] {
        var lines: [AIDiffLine] = []
        var oldNumber = 0
        var newNumber = 0
        var id = 0

        for raw in unified.components(separatedBy: .newlines) {
            defer { id += 1 }

            if raw.hasPrefix("@@") {
                // `@@ -a,b +c,d @@` resets both counters.
                let numbers = raw.split(separator: " ")
                for token in numbers {
                    if token.hasPrefix("-"), let value = Int(token.dropFirst().split(separator: ",")[0]) {
                        oldNumber = value - 1
                    }
                    if token.hasPrefix("+"), let value = Int(token.dropFirst().split(separator: ",")[0]) {
                        newNumber = value - 1
                    }
                }
                lines.append(AIDiffLine(id: id, kind: .hunk, text: raw))
                continue
            }

            // File headers carry no line content.
            if raw.hasPrefix("+++") || raw.hasPrefix("---") || raw.hasPrefix("diff ")
                || raw.hasPrefix("index ") {
                continue
            }

            if raw.hasPrefix("+") {
                newNumber += 1
                lines.append(
                    AIDiffLine(
                        id: id, kind: .added, text: String(raw.dropFirst()),
                        newNumber: newNumber))
            } else if raw.hasPrefix("-") {
                oldNumber += 1
                lines.append(
                    AIDiffLine(
                        id: id, kind: .removed, text: String(raw.dropFirst()),
                        oldNumber: oldNumber))
            } else {
                oldNumber += 1
                newNumber += 1
                let text = raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw
                lines.append(
                    AIDiffLine(
                        id: id, kind: .context, text: text,
                        oldNumber: oldNumber, newNumber: newNumber))
            }
        }
        return lines
    }
}

/// Word-level diff, so a changed line shows *what* changed rather than just
/// that it did.
public enum AIWordDiff {
    /// Splits on word boundaries but keeps the separators, so reassembling the
    /// pieces reproduces the line exactly.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text {
            if character.isLetter || character.isNumber || character == "_" {
                current.append(character)
            } else {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(character))
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Returns, for each token of `new`, whether it is an addition relative to
    /// `old` — computed from the longest common subsequence.
    public static func changedRanges(old: String, new: String) -> [Bool] {
        let a = tokenize(old)
        let b = tokenize(new)
        guard !a.isEmpty, !b.isEmpty else { return Array(repeating: true, count: b.count) }

        // Classic LCS table. Lines are short, so the quadratic cost is fine.
        var table = Array(
            repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j]
                    ? table[i + 1][j + 1] + 1
                    : max(table[i + 1][j], table[i][j + 1])
            }
        }

        var changed = Array(repeating: true, count: b.count)
        var i = 0
        var j = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] {
                changed[j] = false
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return changed
    }
}

public enum AIDiffMode: String, CaseIterable, Sendable {
    case unified
    case split
}

/// A diff viewer built from the design system.
///
/// shadcn ships no diff primitive, so this is new: unified and split views,
/// line numbers, word-level highlighting within changed lines, and collapsible
/// runs of unchanged context.
public struct AIDiffView: View {
    private let lines: [AIDiffLine]
    private let mode: AIDiffMode
    private let language: String?
    /// Runs of context longer than this collapse behind a "N lines hidden" row.
    private let collapseThreshold: Int
    /// Overrides the mono type-scale step used for gutters/markers/content.
    /// `nil` keeps the existing `.xs`/`.sm` steps.
    private let fontSize: CGFloat?
    /// Renders rows inside a `LazyVStack` instead of `VStack` so a caller can
    /// embed this in a `ScrollView` without materializing every row of a
    /// large diff up front. Off by default to keep existing layout identical.
    private let usesLazyRows: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var expanded: Set<Int> = []

    public init(
        lines: [AIDiffLine],
        mode: AIDiffMode = .unified,
        language: String? = nil,
        collapseThreshold: Int = 6,
        fontSize: CGFloat? = nil,
        usesLazyRows: Bool = false
    ) {
        self.lines = lines
        self.mode = mode
        self.language = language
        self.collapseThreshold = collapseThreshold
        self.fontSize = fontSize
        self.usesLazyRows = usesLazyRows
    }

    public init(
        unified: String,
        mode: AIDiffMode = .unified,
        language: String? = nil,
        collapseThreshold: Int = 6,
        fontSize: CGFloat? = nil,
        usesLazyRows: Bool = false
    ) {
        self.init(
            lines: AIDiffParser.parse(unified: unified),
            mode: mode, language: language, collapseThreshold: collapseThreshold,
            fontSize: fontSize, usesLazyRows: usesLazyRows)
    }

    public var body: some View {
        Group {
            if usesLazyRows {
                LazyVStack(alignment: .leading, spacing: 0) { rowViews }
            } else {
                VStack(alignment: .leading, spacing: 0) { rowViews }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.background))
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous))
    }

    @ViewBuilder
    private var rowViews: some View {
        ForEach(rows) { row in
            switch row {
            case let .line(line):
                AIDiffLineRow(
                    line: line,
                    counterpart: counterpart(for: line),
                    showsBothNumbers: mode == .split,
                    language: language,
                    fontSize: fontSize)
            case let .collapsed(id, count):
                collapsedRow(id: id, count: count)
            }
        }
    }

    // MARK: Rows

    enum Row: Identifiable {
        case line(AIDiffLine)
        case collapsed(id: Int, count: Int)

        var id: Int {
            switch self {
            case let .line(line): line.id
            case let .collapsed(id, _): -id - 1
            }
        }
    }

    /// Folds long runs of unchanged context into a single expandable row.
    private var rows: [Row] {
        var result: [Row] = []
        var run: [AIDiffLine] = []

        func flushRun() {
            guard !run.isEmpty else { return }
            let anchor = run[0].id
            if run.count > collapseThreshold, !expanded.contains(anchor) {
                // Keep a little context either side of the fold.
                result.append(.line(run[0]))
                result.append(.collapsed(id: anchor, count: run.count - 2))
                result.append(.line(run[run.count - 1]))
            } else {
                result.append(contentsOf: run.map { Row.line($0) })
            }
            run.removeAll()
        }

        for line in lines {
            if line.kind == .context {
                run.append(line)
            } else {
                flushRun()
                result.append(.line(line))
            }
        }
        flushRun()
        return result
    }

    /// The removed line a given added line replaced, for word-level highlights.
    private func counterpart(for line: AIDiffLine) -> String? {
        guard line.kind == .added,
              let index = lines.firstIndex(where: { $0.id == line.id })
        else { return nil }

        // Walk back over the added block to the removals that preceded it and
        // pair them off in order.
        var addedBefore = 0
        var cursor = index - 1
        while cursor >= 0, lines[cursor].kind == .added {
            addedBefore += 1
            cursor -= 1
        }
        var removals: [String] = []
        while cursor >= 0, lines[cursor].kind == .removed {
            removals.insert(lines[cursor].text, at: 0)
            cursor -= 1
        }
        guard addedBefore < removals.count else { return nil }
        return removals[addedBefore]
    }

    private func collapsedRow(id: Int, count: Int) -> some View {
        Button {
            expanded.insert(id)
        } label: {
            HStack(spacing: Space.x2) {
                ShadcnIconView(ShadcnIcon.chevronDown, size: 12)
                Text("\(count) unchanged lines")
                    .font(theme.typography.sans(theme.typography.xs))
                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.mutedForeground)
            .padding(.horizontal, Space.x3)
            .padding(.vertical, Space.x1_5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.muted.opacity(0.4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.shadcnBare)
    }
}

/// One rendered diff line.
struct AIDiffLineRow: View {
    let line: AIDiffLine
    /// The line this one replaced, when known — enables word highlighting.
    let counterpart: String?
    let showsBothNumbers: Bool
    let language: String?
    /// Overrides the mono type-scale step; nil keeps the `.xs`/`.sm` steps.
    var fontSize: CGFloat? = nil

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    private func monoStep(_ fallback: ShadcnTypography.Step) -> ShadcnTypography.Step {
        guard let fontSize else { return fallback }
        return ShadcnTypography.Step(size: fontSize, lineHeight: fallback.lineHeight * (fontSize / fallback.size))
    }

    /// Additions and removals get a tinted row; context stays on the surface.
    private var rowBackground: Color {
        switch line.kind {
        case .added: AIDiffPalette.added(palette).opacity(0.12)
        case .removed: palette.destructive.opacity(0.10)
        case .hunk: palette.muted.opacity(0.5)
        case .context: .clear
        }
    }

    private var marker: String {
        switch line.kind {
        case .added: "+"
        case .removed: "-"
        default: " "
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if line.kind != .hunk {
                gutter(line.oldNumber)
                if showsBothNumbers { gutter(line.newNumber) }

                Text(marker)
                    .font(theme.typography.mono(monoStep(theme.typography.xs)))
                    .foregroundStyle(markerColour)
                    .frame(width: 14)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, Space.x3)
        }
        .padding(.vertical, 1)
        .background(rowBackground)
    }

    private var markerColour: Color {
        switch line.kind {
        case .added: AIDiffPalette.added(palette)
        case .removed: palette.destructive
        default: palette.mutedForeground
        }
    }

    @ViewBuilder
    private var content: some View {
        if line.kind == .hunk {
            Text(line.text)
                .font(theme.typography.mono(monoStep(theme.typography.xs)))
                .foregroundStyle(palette.mutedForeground)
                .padding(.horizontal, Space.x3)
                .padding(.vertical, 2)
        } else if let counterpart, line.kind == .added {
            wordHighlighted(against: counterpart)
        } else {
            Text(line.text)
                .font(theme.typography.mono(monoStep(theme.typography.sm)))
                .foregroundStyle(palette.foreground)
                .textSelection(.enabled)
        }
    }

    /// Tints only the tokens that actually changed.
    private func wordHighlighted(against old: String) -> some View {
        let tokens = AIWordDiff.tokenize(line.text)
        let changed = AIWordDiff.changedRanges(old: old, new: line.text)
        let accent = AIDiffPalette.added(palette)

        return tokens.indices.reduce(Text("")) { partial, index in
            let piece = Text(tokens[index])
                .foregroundColor(palette.foreground)
            return partial
                + (index < changed.count && changed[index]
                    ? piece.bold().foregroundColor(accent)
                    : piece)
        }
        .font(theme.typography.mono(monoStep(theme.typography.sm)))
        .textSelection(.enabled)
    }

    private func gutter(_ number: Int?) -> some View {
        Text(number.map(String.init) ?? "")
            .font(theme.typography.mono(monoStep(theme.typography.xs)))
            .foregroundStyle(palette.mutedForeground.opacity(0.7))
            .frame(width: 40, alignment: .trailing)
            .padding(.trailing, Space.x2)
    }
}

/// Additions need a green that reads in both appearances; the token set has no
/// "success" colour, so this is the one deliberate addition.
enum AIDiffPalette {
    static func added(_ palette: ShadcnPalette) -> Color {
        palette.isDark
            ? Color(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255)
            : Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
    }
}
