import SwiftUI

/// Two panes with a drag handle, mirroring `resize-split.tsx`: the leading
/// pane resizes between `minWidth`/`maxWidth`, collapses to zero, and
/// remembers its width — the host owns persistence via `width`. Double-click
/// the handle to reset to `defaultWidth`; ⌘B toggles collapsed/expanded.
public struct ShadcnResizeSplit<Sidebar: View, Content: View>: View {
    @Binding private var width: CGFloat
    private let defaultWidth: CGFloat
    private let minWidth: CGFloat
    private let maxWidth: CGFloat
    private let edge: HorizontalEdge
    private let sidebar: Sidebar
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @State private var isCollapsed = false
    @State private var isDragging = false
    @State private var isHoveringHandle = false
    @State private var dragStartWidth: CGFloat = 0

    public init(
        width: Binding<CGFloat>,
        defaultWidth: CGFloat = 256,
        minWidth: CGFloat = 176,
        maxWidth: CGFloat = 440,
        edge: HorizontalEdge = .leading,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content
    ) {
        self._width = width
        self.defaultWidth = defaultWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.edge = edge
        self.sidebar = sidebar()
        self.content = content()
    }

    private var sidebarPane: some View {
        Group {
            if !isCollapsed {
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
        .animation(isDragging ? nil : .easeOut(duration: 0.15), value: isCollapsed)
        // `⌘B` / `Ctrl+B` collapses or expands, matching the source's
        // window-level shortcut — skipped while a text field owns focus so
        // it doesn't steal the letter from typed input.
        .background(
            Button("") { toggleCollapsed() }
                .keyboardShortcut("b", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        )
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
                            isCollapsed = false
                        }
                        let delta = edge == .leading ? value.translation.width : -value.translation.width
                        let proposed = dragStartWidth + delta
                        width = min(max(proposed, minWidth), maxWidth)
                    }
                    .onEnded { _ in isDragging = false }
            )
            .onTapGesture(count: 2) {
                isCollapsed = false
                withAnimation(.easeOut(duration: 0.15)) { width = defaultWidth }
            }
            .help("Drag to resize · double-click to reset · \u{2318}B to collapse")
            .accessibilityLabel("Resize sidebar")
    }

    private func toggleCollapsed() {
        withAnimation(.easeOut(duration: 0.15)) { isCollapsed.toggle() }
    }
}
