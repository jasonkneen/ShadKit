import SwiftUI

// MARK: - Model

/// A single row in a `ShadcnCommand` list — a command palette entry, not a
/// generic list item, so it always carries something to run.
public struct ShadcnCommandItem: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var icon: String?
    public var shortcut: String?

    public init(id: String, title: String, subtitle: String? = nil, icon: String? = nil, shortcut: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
    }
}

/// A labeled cluster of items, matching `CommandGroup`'s heading.
public struct ShadcnCommandGroup: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var items: [ShadcnCommandItem]

    public init(id: String, title: String, items: [ShadcnCommandItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

/// The filtering rule behind `ShadcnCommand`'s search field, pulled out as a
/// pure function so it's testable without a view.
public enum ShadcnCommandModel {
    /// Case-insensitive substring match against `title` and `subtitle`.
    /// Groups left with no matching items are dropped entirely; an empty
    /// query returns every group unchanged.
    public static func filter(_ groups: [ShadcnCommandGroup], query: String) -> [ShadcnCommandGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return groups }
        return groups.compactMap { group in
            let matched = group.items.filter { item in
                item.title.lowercased().contains(needle)
                    || (item.subtitle?.lowercased().contains(needle) ?? false)
            }
            guard !matched.isEmpty else { return nil }
            return ShadcnCommandGroup(id: group.id, title: group.title, items: matched)
        }
    }
}

// MARK: - View

/// shadcn's `Command` (built on `cmdk`): a search field over grouped,
/// keyboard-navigable items with shortcut hints and an empty state — hosted
/// in a `shadcnDialog` via `shadcnCommandDialog`, or embeddable standalone.
public struct ShadcnCommand: View {
    private let groups: [ShadcnCommandGroup]
    private let placeholder: String
    private let emptyText: String
    private let onSelect: (ShadcnCommandItem) -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var query = ""
    @State private var highlighted: String?
    @FocusState private var isFieldFocused: Bool

    public init(
        groups: [ShadcnCommandGroup],
        placeholder: String = "Type a command or search...",
        emptyText: String = "No results found.",
        onSelect: @escaping (ShadcnCommandItem) -> Void
    ) {
        self.groups = groups
        self.placeholder = placeholder
        self.emptyText = emptyText
        self.onSelect = onSelect
    }

    private var filtered: [ShadcnCommandGroup] {
        ShadcnCommandModel.filter(groups, query: query)
    }

    private var flatItems: [ShadcnCommandItem] {
        filtered.flatMap(\.items)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            Divider().overlay(palette.border)

            if flatItems.isEmpty {
                Text(emptyText)
                    .font(theme.typography.sans(theme.typography.sm))
                    .foregroundStyle(palette.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.x6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.x1) {
                        ForEach(filtered) { group in
                            groupSection(group)
                        }
                    }
                    .padding(Space.x1)
                }
                .frame(maxHeight: 288)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(palette.popover)
        )
        .onAppear { syncHighlight() }
        .onChange(of: query) { _, _ in syncHighlight() }
    }

    private var searchField: some View {
        HStack(spacing: Space.x2) {
            Image(systemName: ShadcnIcon.search)
                .foregroundStyle(palette.mutedForeground)
                .font(.system(size: 14))

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(theme.typography.sans(theme.typography.sm))
                .focused($isFieldFocused)
                .onSubmit { selectHighlighted() }
                .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
                .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
        }
        .padding(.horizontal, Space.x3)
        .frame(height: 44)
        .onAppear { isFieldFocused = true }
    }

    private func groupSection(_ group: ShadcnCommandGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.mutedForeground)
                .padding(.horizontal, Space.x2)
                .padding(.top, Space.x1_5)
                .padding(.bottom, 2)

            ForEach(group.items) { item in
                row(item)
            }
        }
    }

    private func row(_ item: ShadcnCommandItem) -> some View {
        let isHighlighted = highlighted == item.id
        return Button {
            onSelect(item)
        } label: {
            HStack(spacing: Space.x2) {
                if let icon = item.icon {
                    Image(systemName: icon)
                        .frame(width: 16, height: 16)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(theme.typography.sans(theme.typography.sm))
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.mutedForeground)
                    }
                }
                Spacer(minLength: Space.x2)
                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.mutedForeground)
                }
            }
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x1_5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                    .fill(isHighlighted ? palette.accent : Color.clear)
            )
            .foregroundStyle(palette.foreground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in if hovering { highlighted = item.id } }
    }

    private func moveHighlight(by delta: Int) {
        let items = flatItems
        guard !items.isEmpty else { return }
        let currentIndex = items.firstIndex { $0.id == highlighted } ?? -1
        let next = min(max(currentIndex + delta, 0), items.count - 1)
        highlighted = items[next].id
    }

    private func selectHighlighted() {
        guard let id = highlighted, let item = flatItems.first(where: { $0.id == id }) else { return }
        onSelect(item)
    }

    private func syncHighlight() {
        let items = flatItems
        if let highlighted, items.contains(where: { $0.id == highlighted }) { return }
        highlighted = items.first?.id
    }
}

extension View {
    /// Presents a `ShadcnCommand` palette in a `shadcnDialog`, matching
    /// `CommandDialog`'s upper-third placement and hidden-close affordance.
    public func shadcnCommandDialog(
        isPresented: Binding<Bool>,
        groups: [ShadcnCommandGroup],
        placeholder: String = "Type a command or search...",
        emptyText: String = "No results found.",
        onSelect: @escaping (ShadcnCommandItem) -> Void
    ) -> some View {
        modifier(ShadcnCommandDialogModifier(
            isPresented: isPresented,
            groups: groups,
            placeholder: placeholder,
            emptyText: emptyText,
            onSelect: onSelect
        ))
    }
}

private struct ShadcnCommandDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let groups: [ShadcnCommandGroup]
    let placeholder: String
    let emptyText: String
    let onSelect: (ShadcnCommandItem) -> Void

    func body(content: Content) -> some View {
        content
            .shadcnDialog(isPresented: $isPresented, width: 480) {
                ShadcnCommand(
                    groups: groups,
                    placeholder: placeholder,
                    emptyText: emptyText,
                    onSelect: { item in
                        isPresented = false
                        onSelect(item)
                    }
                )
            }
    }
}
