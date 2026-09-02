#if canImport(AppKit)
import AppKit
import ShadcnUI
import SwiftUI

/// Conversation switcher. Opens a real `NSPopover` so tabs, search, and
/// scrolling work inside an AppKit-hosted Chat pane.
struct AIConversationMenu: NSViewRepresentable {
    var threads: [AIConversationEntry]
    var activeId: String?
    var compact: Bool
    var onSelect: (String) -> Void
    var onNew: () -> Void
    var onArchive: ((String) -> Void)?
    var onFork: ((String) -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.shadcnSurfaceOpacity) private var surfaceOpacity
    @Environment(\.shadcnGlassEnabled) private var glassEnabled

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
        context.coordinator.glassEnabled = glassEnabled
        context.coordinator.updateTitle(on: button)
        return button
    }

    func updateNSView(_ button: AIConversationMenuButton, context: Context) {
        context.coordinator.parent = self
        context.coordinator.palette = palette
        context.coordinator.theme = theme
        context.coordinator.surfaceOpacity = surfaceOpacity
        context.coordinator.glassEnabled = glassEnabled
        button.font = .systemFont(
            ofSize: compact ? 11 : 13, weight: .medium)
        context.coordinator.updateTitle(on: button)
        context.coordinator.refreshPopoverIfOpen()
    }

    final class Coordinator: NSObject, NSPopoverDelegate {
        var parent: AIConversationMenu?
        var palette: ShadcnPalette = ShadcnTheme.default.palette(for: .dark)
        var theme: ShadcnTheme = .default
        var surfaceOpacity: Double = 1
        var glassEnabled: Bool = true
        var popover: NSPopover?

        var activeTitle: String {
            let threads = parent?.threads ?? []
            let id = parent?.activeId
            return threads.first(where: { $0.id == id })?.title
                ?? threads.first(where: { !$0.isArchived })?.title
                ?? "Chat"
        }

        func updateTitle(on button: AIConversationMenuButton) {
            let title = activeTitle
            if button.title != title { button.title = title }
            button.setAccessibilityLabel("Chat: \(title)")
            button.setAccessibilityHelp("Choose, search, archive, or fork a chat")
        }

        @objc func toggle(_ sender: AIConversationMenuButton) {
            if let popover, popover.isShown {
                popover.close()
                return
            }
            present(from: sender)
        }

        func refreshPopoverIfOpen() {
            guard let popover, popover.isShown else { return }
            popover.contentViewController = hostingController()
        }

        private func present(from sender: NSView) {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = false
            popover.delegate = self
            popover.contentSize = NSSize(width: 360, height: 440)
            popover.appearance = NSAppearance(
                named: palette.isDark ? .vibrantDark : .vibrantLight)
            popover.contentViewController = hostingController()
            self.popover = popover
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            ShadcnWindowTransparency.apply(to: popover)
        }

        private func hostingController() -> NSViewController {
            let parent = self.parent
            let glass = glassEnabled
            let root = AIConversationPickerView(
                threads: parent?.threads ?? [],
                activeId: parent?.activeId,
                onSelect: { [weak self] id in
                    self?.parent?.onSelect(id)
                    self?.popover?.close()
                },
                onNew: { [weak self] in
                    self?.parent?.onNew()
                    self?.popover?.close()
                },
                onArchive: parent?.onArchive,
                onFork: { [weak self] id in
                    self?.parent?.onFork?(id)
                    self?.popover?.close()
                }
            )
            .shadcnTheme(theme, surfaceOpacity: surfaceOpacity, glass: glass)
            .environment(\.shadcnPalette, palette)
            .environment(\.shadcnHostProvidesGlass, glass)
            .preferredColorScheme(palette.isDark ? .dark : .light)
            let host = NSHostingController(rootView: AnyView(root))
            host.sizingOptions = []
            host.view.frame = NSRect(x: 0, y: 0, width: 360, height: 440)
            host.view.wantsLayer = true
            host.view.layer?.backgroundColor = NSColor.clear.cgColor
            guard glass else { return host }

            let wrapper = NSViewController()
            wrapper.view = ShadcnWindowTransparency.wrap(
                host.view,
                frame: host.view.frame,
                cornerRadius: 12,
                glass: true)
            wrapper.preferredContentSize = NSSize(width: 360, height: 440)
            return wrapper
        }

        func popoverWillShow(_ notification: Notification) {
            ShadcnWindowTransparency.apply(to: popover)
        }

        func popoverDidShow(_ notification: Notification) {
            ShadcnWindowTransparency.apply(to: popover)
        }

        func popoverDidClose(_ notification: Notification) {
            popover = nil
        }
    }
}

public struct AIConversationPickerView: View {
    var threads: [AIConversationEntry]
    var activeId: String?
    var onSelect: (String) -> Void
    var onNew: () -> Void
    var onArchive: ((String) -> Void)?
    var onFork: ((String) -> Void)?

    public init(
        threads: [AIConversationEntry],
        activeId: String?,
        onSelect: @escaping (String) -> Void,
        onNew: @escaping () -> Void,
        onArchive: ((String) -> Void)? = nil,
        onFork: ((String) -> Void)? = nil
    ) {
        self.threads = threads
        self.activeId = activeId
        self.onSelect = onSelect
        self.onNew = onNew
        self.onArchive = onArchive
        self.onFork = onFork
    }

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var tab: AIConversationTab = .recents
    @State private var range: AIConversationRange = .any
    @State private var search = ""
    @State private var limit = AIConversationQuery.pageSize

    private var rows: [AIConversationEntry] {
        AIConversationQuery.filtered(
            threads, tab: tab, range: range, search: search, limit: limit)
    }

    private var canLoadMore: Bool {
        let full = AIConversationQuery.filtered(
            threads, tab: tab, range: range, search: search, limit: .max)
        return full.count > rows.count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            searchField
            HStack(spacing: Space.x2) {
                ShadcnTabs(
                    selection: $tab,
                    variant: .solid,
                    items: [
                        (.recents, "Recents"),
                        (.archived, "Archived"),
                    ])
                Spacer(minLength: 0)
                rangeMenu
            }
            list
            ShadcnButton("New chat", systemImage: ShadcnIcon.plus, size: .small) {
                onNew()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.x3)
        .frame(width: 360, height: 440, alignment: .top)
        .background(
            ShadcnTranslucentFill(color: palette.popover, cornerRadius: theme.radius.lg)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.lg)
    }

    private var searchField: some View {
        HStack(spacing: Space.x2) {
            ShadcnIconView(ShadcnIcon.search, size: 12)
                .foregroundStyle(palette.mutedForeground)
            TextField("Search conversations", text: $search)
                .textFieldStyle(.plain)
                .font(theme.typography.sans(theme.typography.sm))
                .onChange(of: search) { _, _ in limit = AIConversationQuery.pageSize }
        }
        .padding(.horizontal, Space.x2)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.muted.opacity(0.55))
        )
        .accessibilityLabel("Search conversations")
    }

    private var rangeMenu: some View {
        Menu {
            Button("Any time") { range = .any }
            Button("Today") { range = .today }
            Button("This week") { range = .week }
        } label: {
            HStack(spacing: 4) {
                Text(rangeLabel)
                Image(systemName: ShadcnIcon.chevronDown)
                    .font(.system(size: 8, weight: .semibold))
            }
            .font(theme.typography.sans(theme.typography.xs, weight: .medium))
            .foregroundStyle(palette.mutedForeground)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Filter by time")
    }

    private var rangeLabel: String {
        switch range {
        case .any: "Any time"
        case .today: "Today"
        case .week: "This week"
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if rows.isEmpty {
                    Text(emptyCopy)
                        .font(theme.typography.sans(theme.typography.sm))
                        .foregroundStyle(palette.mutedForeground)
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
                    .foregroundStyle(palette.mutedForeground)
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
                        Text(AIConversationQuery.relativeTime(from: item.updatedAt))
                            .font(theme.typography.sans(theme.typography.xs))
                            .foregroundStyle(palette.mutedForeground)
                            .fixedSize()
                    }
                    if !item.snippet.isEmpty {
                        Text(item.snippet)
                            .font(theme.typography.sans(theme.typography.xs))
                            .foregroundStyle(palette.mutedForeground)
                            .lineLimit(1)
                    }
                }
                if onArchive != nil || onFork != nil {
                    rowActions(item)
                }
            }
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x2)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                    .fill(active ? palette.accent.opacity(0.18) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(palette.mutedForeground)
                .frame(width: 20, height: 20)
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
        imagePosition = .imageTrailing
        alignment = .left
        lineBreakMode = .byTruncatingTail
        image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: nil)
        symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 9, weight: .semibold)
        contentTintColor = .secondaryLabelColor
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: max(size.width, 72), height: max(size.height, 22))
    }
}
#endif
