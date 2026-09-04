import ShadcnUI
import SwiftUI

/// Groups a run's `UIToolPart` calls by tool kind, for `AIToolCallDeck`.
///
/// This is the "projection type the consumer can fill" `AIToolCallDeck`
/// needs: it only decides how calls are grouped and labelled, never drops a
/// call or its payload. Groups keep first-appearance order; calls keep their
/// original order inside each group.
public struct AIToolCallGroupProjection {
    public struct Group: Identifiable {
        public let key: String
        public let name: String
        public let tools: [UIToolPart]

        public var id: String { key }

        public var label: String { "\(tools.count) × \(name)" }
    }

    public let tools: [UIToolPart]
    public let groups: [Group]

    /// Three calls are enough for a compact summary to pay for itself.
    public var shouldSummarize: Bool { tools.count >= 3 }

    public var summaryLabel: String {
        "\(tools.count) \(tools.count == 1 ? "tool" : "tools")"
    }

    public var summaryState: AIToolState {
        Self.state(for: tools.map(\.state))
    }

    public init(tools: [UIToolPart]) {
        self.tools = tools

        var grouped: [(key: String, name: String, tools: [UIToolPart])] = []
        var indexes: [String: Int] = [:]
        for tool in tools {
            let name = Self.groupName(for: tool.name)
            let key = Self.groupKey(for: name)
            if let index = indexes[key] {
                grouped[index].tools.append(tool)
            } else {
                indexes[key] = grouped.count
                grouped.append((key: key, name: name, tools: [tool]))
            }
        }
        groups = grouped.map { Group(key: $0.key, name: $0.name, tools: $0.tools) }
    }

    public static func groupName(for rawName: String) -> String {
        friendlyName(baseName(from: rawName))
    }

    public static func groupKey(for name: String) -> String {
        name
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    /// A short, human-facing tool label. Provider wire names can be long
    /// namespaces such as `mcp__foo__do_thing`; those should not become the
    /// visible chip title.
    public static func displayName(for rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Tool" }
        if let separator = trimmed.firstIndex(of: ":") {
            let prefix = String(trimmed[..<separator])
            let detail = trimmed[trimmed.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let label = groupName(for: prefix)
            return detail.isEmpty ? label : "\(label) · \(detail)"
        }
        return groupName(for: trimmed)
    }

    /// The top-level `description` of a JSON tool input, if any. Single
    /// line, bounded length.
    public static func inputDescription(_ input: String?) -> String? {
        guard let input, let data = input.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["description"] as? String
        else { return nil }
        let line = raw.split(whereSeparator: \.isNewline).first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !line.isEmpty else { return nil }
        return line.count > 120 ? String(line.prefix(119)) + "…" : line
    }

    /// Pick a tool-kind icon while keeping the lifecycle icon available as a
    /// trailing status marker on the chip.
    public static func icon(for rawName: String) -> String {
        let name = rawName.lowercased()
        if name.contains("terminal") || name.contains("shell")
            || name.contains("bash") || name.contains("command")
            || name.contains("exec") {
            return ShadcnIcon.terminal
        }
        if name.contains("browser") || name.contains("web")
            || name.contains("http") || name.contains("url") {
            return ShadcnIcon.globe
        }
        if name.contains("search") || name.contains("grep") {
            return ShadcnIcon.search
        }
        if name.contains("read") || name.contains("cat")
            || name.contains("file") || name.contains("open") {
            return ShadcnIcon.book
        }
        if name.contains("write") || name.contains("edit")
            || name.contains("patch") || name.contains("apply") {
            return ShadcnIcon.pencil
        }
        if name.contains("delete") || name.contains("remove") {
            return ShadcnIcon.trash
        }
        if name.contains("git") || name.contains("diff")
            || name.contains("commit") {
            return ShadcnIcon.gitBranch
        }
        if name.contains("todo") || name.contains("task") {
            return ShadcnIcon.listTodo
        }
        return ShadcnIcon.wrench
    }

    private static func baseName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "tool" }

        var candidate = trimmed.split(separator: ":", maxSplits: 1)
            .first.map(String.init) ?? trimmed
        let namespaceParts = candidate.split(separator: "__")
        if let last = namespaceParts.last, namespaceParts.count > 1 {
            candidate = String(last)
        }
        for prefix in ["tool-", "mcp_"] where candidate.lowercased().hasPrefix(prefix) {
            candidate.removeFirst(prefix.count)
        }
        return candidate
    }

    /// `commandExecution` -> `command Execution`; `HTTPRequest` -> `HTTP Request`.
    public static func splitCamelCase(_ value: String) -> String {
        let characters = Array(value)
        var result = ""
        for (index, character) in characters.enumerated() {
            if character.isUppercase, index > 0 {
                let previous = characters[index - 1]
                let startsWord = previous.isLowercase || previous.isNumber
                let endsAcronym = previous.isUppercase
                    && index + 1 < characters.count
                    && characters[index + 1].isLowercase
                if startsWord || endsAcronym { result.append(" ") }
            }
            result.append(character)
        }
        return result
    }

    /// Words that read wrong in title case.
    private static let acronyms: Set<String> = ["mcp", "api", "url", "http", "cli", "ai", "id"]

    private static func friendlyName(_ rawName: String) -> String {
        let normalized = splitCamelCase(
            rawName
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: ".", with: " "))
        let lowercased = normalized.lowercased()
        switch lowercased {
        case "bash", "shell", "terminal", "exec", "command", "command execution",
             "bash output", "run command", "local shell":
            return "Terminal"
        case "browser", "web browser", "web":
            return "Browser"
        case "read", "file read", "view":
            return "Read"
        case "write", "file write", "create file":
            return "Write"
        case "edit", "file edit", "multi edit", "file change", "patch apply",
             "apply patch":
            return "Edit"
        case "web search", "websearch":
            return "Web Search"
        case "mcp tool call", "mcp tool":
            return "MCP Tool"
        case "todo write", "todo list", "todo read":
            return "Plan"
        default:
            return normalized.split(whereSeparator: { $0.isWhitespace })
                .map { word in
                    guard let first = word.first else { return "" }
                    if acronyms.contains(word.lowercased()) {
                        return word.uppercased()
                    }
                    return String(first).uppercased() + word.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    private static func state(for states: [AIToolState]) -> AIToolState {
        if states.contains(where: { $0 == .outputError }) { return .outputError }
        if states.contains(where: { $0 == .outputDenied }) { return .outputDenied }
        if states.contains(where: { $0 == .approvalRequested }) { return .approvalRequested }
        if states.contains(where: {
            $0 == .inputStreaming || $0 == .inputAvailable || $0 == .approvalResponded
        }) {
            return .inputAvailable
        }
        return .outputAvailable
    }
}

/// Compact, horizontal, nested tool-call deck: an optional summary chip,
/// per-group chips, and per-call detail — all driven by
/// `AIToolCallGroupProjection`.
///
/// The outer summary, group, and individual-call expansion states are each
/// tracked independently and keyed by stable IDs, so a live result update
/// never collapses a row the caller already opened.
public struct AIToolCallDeck: View {
    private let tools: [UIToolPart]
    private let showsSummary: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var summaryIsExpanded = false
    @State private var expandedGroups: Set<String> = []
    @State private var expandedTools: Set<String> = []

    public init(tools: [UIToolPart], showsSummary: Bool = true) {
        self.tools = tools
        self.showsSummary = showsSummary
    }

    private var projection: AIToolCallGroupProjection {
        AIToolCallGroupProjection(tools: tools)
    }

    public var body: some View {
        if tools.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Space.x1) {
                if projection.shouldSummarize, showsSummary {
                    summary
                }
                if projection.shouldSummarize {
                    if !showsSummary || summaryIsExpanded {
                        groupChips
                        expandedGroupRows
                    }
                } else {
                    individualRow(projection.tools, groupKey: nil)
                }
            }
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x1)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tool calls")
        }
    }

    private var summary: some View {
        toolChip(
            title: projection.summaryLabel,
            state: projection.summaryState,
            systemImage: ShadcnIcon.wrench,
            isSelected: summaryIsExpanded,
            hint: summaryIsExpanded ? "Hide tool groups" : "Show tool groups"
        ) {
            withAnimation(.easeOut(duration: 0.16)) {
                summaryIsExpanded.toggle()
            }
        }
        .accessibilityLabel(projection.summaryLabel)
    }

    private var groupChips: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(spacing: Space.x1) {
                ForEach(projection.groups) { group in
                    toolChip(
                        title: group.label,
                        state: AIToolCallGroupProjection(tools: group.tools).summaryState,
                        systemImage: AIToolCallGroupProjection.icon(for: group.name),
                        isSelected: expandedGroups.contains(group.key),
                        hint: expandedGroups.contains(group.key)
                            ? "Hide \(group.name) calls"
                            : "Show \(group.name) calls"
                    ) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            if expandedGroups.contains(group.key) {
                                expandedGroups.remove(group.key)
                            } else {
                                expandedGroups.insert(group.key)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private var expandedGroupRows: some View {
        ForEach(projection.groups.filter { expandedGroups.contains($0.key) }) { group in
            individualRow(group.tools, groupKey: group.key)
        }
    }

    @ViewBuilder
    private func individualRow(_ tools: [UIToolPart], groupKey: String?) -> some View {
        if !tools.isEmpty {
            VStack(alignment: .leading, spacing: Space.x1) {
                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                    VStack(alignment: .leading, spacing: Space.x1) {
                        toolChip(
                            title: Self.chipTitle(for: tool, index: index),
                            state: tool.state,
                            systemImage: AIToolCallGroupProjection.icon(for: tool.name),
                            isSelected: expandedTools.contains(tool.id),
                            hint: expandedTools.contains(tool.id)
                                ? "Hide call details"
                                : "Show call details"
                        ) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                if expandedTools.contains(tool.id) {
                                    expandedTools.remove(tool.id)
                                } else {
                                    expandedTools.insert(tool.id)
                                }
                            }
                        }

                        if expandedTools.contains(tool.id) {
                            AIToolCallDetail(tool: tool, ordinal: index + 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(groupKey.map { "\($0) tool calls" } ?? "Individual tool calls")
        }
    }

    private func toolChip(
        title: String,
        state: AIToolState,
        systemImage: String,
        isSelected: Bool,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Space.x1) {
                ShadcnIconView(systemImage, size: 11)
                    .foregroundStyle(palette.mutedForeground)
                Text(title)
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 420, alignment: .leading)
                ShadcnIconView(state.systemImage, size: 10)
                    .foregroundStyle(state.iconTint ?? palette.mutedForeground)
                ShadcnDisclosureChevron(isOpen: isSelected, size: 10)
                    .foregroundStyle(palette.mutedForeground)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Space.x2)
            .frame(height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? palette.primary.opacity(palette.isDark ? 0.22 : 0.12)
                            : palette.muted.opacity(0.58)
                    )
            )
            .shadcnBorder(
                isSelected ? palette.ring : palette.input,
                cornerRadius: theme.radius.md
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.shadcnBare)
        .accessibilityValue(state.label)
        .accessibilityHint(hint)
        .help(hint)
    }

    private static func chipTitle(for tool: UIToolPart, index: Int) -> String {
        let name = tool.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName = name.isEmpty ? "Tool" : name
        let displayName = AIToolCallGroupProjection.displayName(for: rawName)
        if let description = AIToolCallGroupProjection.inputDescription(tool.input) {
            return "\(displayName) · \(description)"
        }
        let visibleName = displayName.count > 28
            ? String(displayName.prefix(27)) + "…"
            : displayName
        return "\(visibleName) #\(index + 1)"
    }
}

/// Expanded detail for one call inside an `AIToolCallDeck` row.
struct AIToolCallDetail: View {
    let tool: UIToolPart
    let ordinal: Int

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(spacing: Space.x1) {
                Text("Call \(ordinal)")
                    .font(theme.typography.sans(theme.typography.xs, weight: .semibold))
                    .foregroundStyle(palette.foreground)
                Text(AIToolCallGroupProjection.displayName(for: tool.name))
                    .font(theme.typography.mono(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(tool.name)
            }

            if let input = tool.input, !input.isEmpty {
                AIToolInput(json: input)
            }
            if tool.output != nil || tool.errorText != nil {
                AIToolOutput(output: tool.output, errorText: tool.errorText)
            }
            if tool.input == nil, tool.output == nil, tool.errorText == nil {
                Text("No payload reported yet")
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)
                    .padding(.vertical, Space.x1)
            }
        }
        .padding(.horizontal, Space.x2)
        .padding(.vertical, Space.x1)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.muted.opacity(0.22))
        )
        .shadcnBorder(palette.input, cornerRadius: theme.radius.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Details for \(tool.name)")
    }
}
