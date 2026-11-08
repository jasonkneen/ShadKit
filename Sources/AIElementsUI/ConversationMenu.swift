#if canImport(AppKit)
import AppKit
import ShadcnUI
import SwiftUI

/// Conversation switcher. Opens a window-backed floating panel
/// (`ShadcnFloatingPanelController`) so tabs, search, and scrolling work
/// inside an AppKit-hosted Chat pane.
///
/// U23: this used to be an `NSPopover`. Its content — search field, tab
/// pills, thread list — reliably failed to paint (an empty dark rectangle
/// above the one child that did, `+ New chat`), reproduced with the popover
/// glass-wrapping disabled and content-controller `sizingOptions` at their
/// default, so it wasn't either of the causes those particular knobs
/// address. Whatever `NSPopover` + `NSHostingController` + this exact
/// content tree does wrong, `ShadcnFloatingPanelController` sidesteps it
/// entirely by construction (its content is already proven correct for the
/// dropdown menu and dialog), rather than chasing a third theory.
struct AIConversationMenu: NSViewRepresentable {
    var threads: [AIConversationEntry]
    var activeId: String?
    var scopes: [AIConversationScope] = []
    var preferredScopeID: String? = nil
    var compact: Bool
    var onSelect: (String) -> Void
    var onNew: () -> Void
    var onArchive: ((String) -> Void)?
    var onFork: ((String) -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.shadcnSurfaceOpacity) private var surfaceOpacity
    @Environment(\.shadcnGlassEnabled) private var glassEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AIConversationMenuButton {
        let button = AIConversationMenuButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.toggle(_:))
        button.font = .systemFont(
            ofSize: compact ? 11 : 13, weight: .medium)
        context.coordinator.parent = self
        context.coordinator.palette = palette
        context.coordinator.theme = theme
        context.coordinator.surfaceOpacity = surfaceOpacity
        context.coordinator.glassEnabled = glassEnabled && !reduceTransparency
        context.coordinator.updateTitle(on: button)
        return button
    }

    func updateNSView(_ button: AIConversationMenuButton, context: Context) {
        context.coordinator.parent = self
        context.coordinator.palette = palette
        context.coordinator.theme = theme
        context.coordinator.surfaceOpacity = surfaceOpacity
        context.coordinator.glassEnabled = glassEnabled && !reduceTransparency
        button.font = .systemFont(
            ofSize: compact ? 11 : 13, weight: .medium)
        context.coordinator.updateTitle(on: button)
        context.coordinator.refreshPanelIfOpen()
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: AIConversationMenu?
        var palette: ShadcnPalette = ShadcnTheme.default.palette(for: .dark)
        var theme: ShadcnTheme = .default
        var surfaceOpacity: Double = 1
        var glassEnabled: Bool = true
        let panelController = ShadcnFloatingPanelController()

        var activeTitle: String {
            let threads = parent?.threads ?? []
            let id = parent?.activeId
            return threads.first(where: { $0.id == id })?.title
                ?? threads.first(where: { !$0.isArchived })?.title
                ?? "Chat"
        }

        func updateTitle(on button: AIConversationMenuButton) {
            button.title = ""
            button.setAccessibilityLabel("Sessions")
            button.setAccessibilityValue(activeTitle)
            button.setAccessibilityHelp("Choose, search, archive, or fork a chat")
        }

        @objc func toggle(_ sender: AIConversationMenuButton) {
            if panelController.isShown {
                panelController.close()
                return
            }
            present(from: sender)
        }

        func refreshPanelIfOpen() {
            guard panelController.isShown else { return }
            panelController.updateContent(content: pickerContent)
        }

        private func present(from sender: NSView) {
            panelController.anchorView = sender
            panelController.show(
                edge: .bottom, alignment: .leading,
                contentWidth: 380, contentHeight: 440,
                makesKey: true,
                glass: glassEnabled,
                onDismiss: {},
                content: pickerContent)
        }

        @ViewBuilder
        private func pickerContent() -> some View {
            let parent = self.parent
            AIConversationPickerView(
                threads: parent?.threads ?? [],
                activeId: parent?.activeId,
                scopes: parent?.scopes ?? [],
                preferredScopeID: parent?.preferredScopeID,
                onSelect: { [weak self] id in
                    self?.parent?.onSelect(id)
                    self?.panelController.close()
                },
                onNew: { [weak self] in
                    self?.parent?.onNew()
                    self?.panelController.close()
                },
                onArchive: parent?.onArchive,
                onFork: { [weak self] id in
                    self?.parent?.onFork?(id)
                    self?.panelController.close()
                }
            )
            .environment(\.shadcnTheme, theme)
            .environment(\.shadcnPalette, palette)
            .environment(\.shadcnSurfaceOpacity, glassEnabled ? surfaceOpacity : 1)
            .environment(\.shadcnHostProvidesGlass, glassEnabled)
            .environment(\.shadcnGlassEnabled, glassEnabled)
            .environment(\.colorScheme, palette.isDark ? .dark : .light)
        }
    }
}

public struct AIConversationPickerView: View {
    var threads: [AIConversationEntry]
    var activeId: String?
    var scopes: [AIConversationScope]
    var preferredScopeID: String?
    var onSelect: (String) -> Void
    var onNew: () -> Void
    var onArchive: ((String) -> Void)?
    var onFork: ((String) -> Void)?

    public init(
        threads: [AIConversationEntry],
        activeId: String?,
        scopes: [AIConversationScope] = [],
        preferredScopeID: String? = nil,
        onSelect: @escaping (String) -> Void,
        onNew: @escaping () -> Void,
        onArchive: ((String) -> Void)? = nil,
        onFork: ((String) -> Void)? = nil
    ) {
        self.threads = threads
        self.activeId = activeId
        self.scopes = scopes
        self.preferredScopeID = preferredScopeID
        self.onSelect = onSelect
        _scope = State(initialValue: preferredScopeID)
        self.onNew = onNew
        self.onArchive = onArchive
        self.onFork = onFork
    }

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var tab: AIConversationTab = .recents
    @State private var range: AIConversationRange = .any
    @State private var scope: String?
    @State private var search = ""
    @State private var hoveredID: String?
    @State private var limit = AIConversationQuery.pageSize

    private var rows: [AIConversationEntry] {
        AIConversationQuery.filtered(
            threads, tab: tab, range: range, search: search,
            scopeID: scope, limit: limit)
    }

    private var canLoadMore: Bool {
        let full = AIConversationQuery.filtered(
            threads, tab: tab, range: range, search: search,
            scopeID: scope, limit: .max)
        return full.count > rows.count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ShadcnPopoverStyle.sectionSpacing) {
            ShadcnPopoverSearchField("Search conversations", text: $search)
                .onChange(of: search) { _, _ in limit = AIConversationQuery.pageSize }
            HStack(spacing: Space.x1) {
                ShadcnPopoverTab("Recents", isOn: tab == .recents) { tab = .recents }
                ShadcnPopoverTab("Archived", isOn: tab == .archived) { tab = .archived }
                Spacer(minLength: 0)
                if scopes.count > 1 { scopeMenu }
                rangeMenu
            }
            list
            ShadcnPopoverFooter {
                Spacer(minLength: 0)
                ShadcnPopoverPrimaryButton("New chat", systemImage: ShadcnIcon.plus) {
                    onNew()
                }
            }
        }
        .padding(ShadcnPopoverStyle.panelPadding)
        .frame(width: 380, height: 440, alignment: .top)
        .shadcnPopoverSurface()
    }

    private var rangeMenu: some View {
        ShadcnPopoverMenu(rangeLabel) {
            Button("Any time") { range = .any }
            Button("Today") { range = .today }
            Button("This week") { range = .week }
        }
        .accessibilityLabel("Filter by time")
    }

    private var rangeLabel: String {
        switch range {
        case .any: "Any time"
        case .today: "Today"
        case .week: "This week"
        }
    }

    /// Scope titles can repeat (several "Agent" spaces); number the repeats so
    /// the menu entries are tellable apart.
    private var scopeItems: [(id: String, title: String)] {
        let totals = Dictionary(scopes.map { ($0.title, 1) }, uniquingKeysWith: +)
        var seen: [String: Int] = [:]
        return scopes.map { item in
            guard totals[item.title, default: 1] > 1 else { return (item.id, item.title) }
            seen[item.title, default: 0] += 1
            return (item.id, "\(item.title) \(seen[item.title] ?? 1)")
        }
    }

    private var scopeLabel: String {
        guard let scope else { return "All agents" }
        return scopeItems.first { $0.id == scope }?.title ?? "All agents"
    }

    private var scopeMenu: some View {
        ShadcnPopoverMenu(scopeLabel) {
            Button("All agents") {
                scope = nil
                limit = AIConversationQuery.pageSize
            }
            Divider()
            ForEach(scopeItems, id: \.id) { item in
                Button(item.title) {
                    scope = item.id
                    limit = AIConversationQuery.pageSize
                }
            }
        }
        .accessibilityLabel("Filter by agent")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ShadcnPopoverStyle.rowGap) {
                if rows.isEmpty {
                    Text(emptyCopy)
                        .font(theme.typography.sans(theme.typography.sm))
                        .foregroundStyle(palette.popoverTertiary)
                        .padding(.vertical, Space.x4)
                        .frame(maxWidth: .infinity)
                }
                ForEach(rows) { item in
                    row(item)
                }
                if canLoadMore {
                    Button("Load more") {
                        limit += AIConversationQuery.pageSize
                    }
                    .buttonStyle(.plain)
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .foregroundStyle(palette.popoverSecondary)
                    .padding(.vertical, Space.x2)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Load more conversations")
                }
            }
        }
        .onChange(of: tab) { _, _ in limit = AIConversationQuery.pageSize }
        .onChange(of: range) { _, _ in limit = AIConversationQuery.pageSize }
    }

    private var emptyCopy: String {
        if !search.isEmpty { return "No conversations match" }
        return tab == .archived ? "Nothing archived" : "No conversations yet"
    }

    private func row(_ item: AIConversationEntry) -> some View {
        let active = item.id == activeId
        return Button {
            onSelect(item.id)
        } label: {
            HStack(alignment: .top, spacing: Space.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title.isEmpty ? "New chat" : item.title)
                            .font(theme.typography.sans(
                                theme.typography.sm, weight: .medium))
                            .foregroundStyle(palette.foreground)
                            .lineLimit(1)
                        Spacer(minLength: Space.x2)
                        // Time and actions share one trailing slot: the time
                        // stays flush right and swaps for the actions on
                        // hover/selection, so nothing shifts or sits inset.
                        let showActions = (onArchive != nil || onFork != nil)
                            && (active || hoveredID == item.id)
                        ZStack(alignment: .trailing) {
                            Text(AIConversationQuery.relativeTime(from: item.updatedAt))
                                .font(theme.typography.sans(theme.typography.xs))
                                .foregroundStyle(palette.popoverTertiary)
                                .fixedSize()
                                .opacity(showActions ? 0 : 1)
                            rowActions(item)
                                .opacity(showActions ? 1 : 0)
                                .allowsHitTesting(showActions)
                        }
                    }
                    if !item.snippet.isEmpty {
                        Text(item.snippet)
                            .font(theme.typography.sans(theme.typography.xs))
                            .foregroundStyle(palette.popoverSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, ShadcnPopoverStyle.rowHorizontalPadding)
            .padding(.vertical, ShadcnPopoverStyle.rowVerticalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: item.snippet.isEmpty
                    ? ShadcnPopoverStyle.rowMinHeight
                    : ShadcnPopoverStyle.twoLineRowMinHeight,
                alignment: .leading)
            .shadcnPopoverRowBackground(selected: active, hovered: hoveredID == item.id)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
        .contextMenu {
            if let onFork {
                Button("Fork conversation") { onFork(item.id) }
            }
            if let onArchive {
                Button(item.isArchived ? "Move to recents" : "Archive") {
                    onArchive(item.id)
                }
            }
        }
        .accessibilityLabel(item.title)
        .accessibilityValue(AIConversationQuery.relativeTime(from: item.updatedAt))
    }

    private func rowActions(_ item: AIConversationEntry) -> some View {
        HStack(spacing: 2) {
            if let onFork {
                iconButton("arrow.triangle.branch", "Fork conversation") {
                    onFork(item.id)
                }
            }
            if let onArchive {
                iconButton(
                    item.isArchived ? "tray.and.arrow.up" : "archivebox",
                    item.isArchived ? "Move to recents" : "Archive"
                ) {
                    onArchive(item.id)
                }
            }
        }
    }

    private func iconButton(
        _ symbol: String, _ label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.popoverSecondary)
                .frame(width: 20, height: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

final class AIConversationMenuButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        bezelStyle = .inline
        imagePosition = .imageOnly
        alignment = .center
        lineBreakMode = .byTruncatingTail
        image = NSImage(
            systemSymbolName: "clock.arrow.circlepath",
            accessibilityDescription: nil)
        symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 14, weight: .regular)
        contentTintColor = .secondaryLabelColor
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 28, height: 28)
    }
}
#endif
