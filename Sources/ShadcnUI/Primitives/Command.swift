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
    /// Text a palette consumer should insert in place of `title` when the
    /// display label and the value to write back differ. `nil` falls back to
    /// `title`, so existing callers are unaffected.
    public var insertion: String?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        shortcut: String? = nil,
        insertion: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.insertion = insertion
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

    /// Called on Escape. `nil` (the standalone-embed default) means Escape
    /// does nothing; `shadcnCommandDialog` supplies one that dismisses.
    private var onEscape: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var query = ""
    @State private var highlighted: String?
    /// Only hover moves the highlight, and only when the pointer actually
    /// moved — set by `.onContinuousHover`'s location, not by `.onHover`'s
    /// boolean, so a stationary pointer left over a row doesn't re-steal the
    /// highlight the moment arrow keys re-lay-out the list under it.
    @State private var lastHoverLocation: CGPoint?
    @FocusState private var isFieldFocused: Bool

    public init(
        groups: [ShadcnCommandGroup],
        placeholder: String = "Type a command or search...",
        emptyText: String = "No results found.",
        onEscape: (() -> Void)? = nil,
        onSelect: @escaping (ShadcnCommandItem) -> Void
    ) {
        self.groups = groups
        self.placeholder = placeholder
        self.emptyText = emptyText
        self.onEscape = onEscape
        self.onSelect = onSelect
    }

    private var filtered: [ShadcnCommandGroup] {
        ShadcnCommandModel.filter(groups, query: query)
    }

    private var flatItems: [ShadcnCommandItem] {
        filtered.flatMap(\.items)
    }

    public var body: some View {
        ScrollViewReader { scrollProxy in
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
                ShadcnTranslucentFill(color: palette.popover, cornerRadius: theme.radius.xl)
            )
            .onAppear { syncHighlight() }
            .onChange(of: query) { _, _ in syncHighlight() }
            .onChange(of: highlighted) { _, id in
                guard let id else { return }
                withAnimation(nil) {
                    scrollProxy.scrollTo(id, anchor: nil)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Space.x2) {
            ShadcnIconView(ShadcnIcon.search, size: 14)
                .foregroundStyle(palette.mutedForeground)

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(theme.typography.sans(theme.typography.sm))
                .focused($isFieldFocused)
                .onSubmit { selectHighlighted() }
                .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
                .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
                .onKeyPress(.escape) {
                    guard let onEscape else { return .ignored }
                    onEscape()
                    return .handled
                }
        }
        .padding(.horizontal, Space.x3)
        .frame(height: 44)
        .task { isFieldFocused = true }
    }

    private func groupSection(_ group: ShadcnCommandGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.title.uppercased())
                .font(theme.typography.sans(theme.typography.xs, weight: .medium))
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
                    ShadcnIconView(icon, size: 16)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(theme.typography.sans(theme.typography.sm))
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(theme.typography.sans(theme.typography.xs))
                            .foregroundStyle(palette.mutedForeground)
                    }
                }
                Spacer(minLength: Space.x2)
                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(theme.typography.sans(theme.typography.xs))
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
        .id(item.id)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                // Only a real pointer move updates the highlight — comparing
                // the reported location filters out the phantom `.active`
                // AppKit re-delivers when the list relayouts under a
                // stationary cursor after an arrow-key move.
                if let lastHoverLocation, lastHoverLocation == location { return }
                lastHoverLocation = location
                highlighted = item.id
            case .ended:
                lastHoverLocation = nil
            }
        }
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
    /// Escape dismisses, same as the scrim tap.
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
                    onEscape: { isPresented = false },
                    onSelect: { item in
                        isPresented = false
                        onSelect(item)
                    }
                )
            }
    }
}
