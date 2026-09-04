import SwiftUI

/// Two panes with a drag handle, mirroring `resize-split.tsx`: the leading
/// pane resizes between `minWidth`/`maxWidth`, collapses to zero, and
/// remembers its width — the host owns persistence via `width`. Double-click
/// the handle to reset to `defaultWidth`. A window-level collapse shortcut
/// (⌘B in the source) is opt-in via `collapseShortcut`, since a host may
/// already bind that letter, or may not want a global shortcut at all.
public struct ShadcnResizeSplit<Sidebar: View, Content: View>: View {
    @Binding private var width: CGFloat
    private let defaultWidth: CGFloat
    private let minWidth: CGFloat
    private let maxWidth: CGFloat
    private let edge: HorizontalEdge
    private let collapseShortcut: KeyEquivalent?
    private let externalCollapsed: Binding<Bool>?
    private let sidebar: Sidebar
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    /// Backing store used when the host doesn't pass `collapsed:` — collapse
    /// state stays internal, same as before. When the host does pass it,
    /// `isCollapsed` reads/writes through to that binding instead, so the
    /// host can persist it (e.g. across launches) the same way it persists
    /// `width`.
    @State private var internalCollapsed = false
    @State private var isDragging = false
    @State private var isHoveringHandle = false
    @State private var dragStartWidth: CGFloat = 0

    private var isCollapsed: Binding<Bool> {
        externalCollapsed ?? $internalCollapsed
    }

    public init(
        width: Binding<CGFloat>,
        collapsed: Binding<Bool>? = nil,
        defaultWidth: CGFloat = 256,
        minWidth: CGFloat = 176,
        maxWidth: CGFloat = 440,
        edge: HorizontalEdge = .leading,
        collapseShortcut: KeyEquivalent? = nil,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content
    ) {
        self._width = width
        self.externalCollapsed = collapsed
        self.defaultWidth = defaultWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.edge = edge
        self.collapseShortcut = collapseShortcut
        self.sidebar = sidebar()
        self.content = content()
    }

    private var sidebarPane: some View {
        Group {
            if !isCollapsed.wrappedValue {
                sidebar
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .transition(.move(edge: edge == .leading ? .leading : .trailing))
            }
        }
    }

    private var contentPane: some View {
        content.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    public var body: some View {
        HStack(spacing: 0) {
            if edge == .leading {
                sidebarPane
                handle
                contentPane
            } else {
                contentPane
                handle
                sidebarPane
            }
        }
        .animation(isDragging ? nil : .easeOut(duration: 0.15), value: isCollapsed.wrappedValue)
        // The collapse shortcut is opt-in (`collapseShortcut`, `nil` by
        // default) — a global `.keyboardShortcut` claims the letter for the
        // whole window, including while a text field has focus, so a host
        // has to choose to hand it a key rather than getting one for free.
        .applyIf(collapseShortcut != nil) { view in
            view.background(
                Button("") { toggleCollapsed() }
                    .keyboardShortcut(collapseShortcut!, modifiers: .command)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
        }
    }

    private var handle: some View {
        Rectangle()
            .fill(isHoveringHandle || isDragging ? palette.accent : palette.border)
            .frame(width: 1)
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
                    .contentShape(Rectangle())
            )
            .onHover { isHoveringHandle = $0 }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartWidth = width
                            isCollapsed.wrappedValue = false
                        }
                        let delta = edge == .leading ? value.translation.width : -value.translation.width
                        let proposed = dragStartWidth + delta
                        width = min(max(proposed, minWidth), maxWidth)
                    }
                    .onEnded { _ in isDragging = false }
            )
            .onTapGesture(count: 2) {
                isCollapsed.wrappedValue = false
                withAnimation(.easeOut(duration: 0.15)) { width = defaultWidth }
            }
            .help(
                collapseShortcut != nil
                    ? "Drag to resize · double-click to reset · \u{2318}B to collapse"
                    : "Drag to resize · double-click to reset"
            )
            .accessibilityLabel("Resize sidebar")
    }

    private func toggleCollapsed() {
        withAnimation(.easeOut(duration: 0.15)) { isCollapsed.wrappedValue.toggle() }
    }
}
