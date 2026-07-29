import SwiftUI

// MARK: - Panel chrome

/// The shared surface behind popovers, dropdowns, selects and hover cards:
/// `rounded-md border bg-popover text-popover-foreground shadow-md`.
public struct ShadcnPanel<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(padding: CGFloat = Space.x1, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.popover)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
        .foregroundStyle(palette.popoverForeground)
        .shadcnShadow(.md)
    }
}

/// Invisible full-bleed layer that closes an open overlay on an outside click.
///
/// Deliberately oversized: it has to reach past the trigger's own bounds, and
/// SwiftUI gives overlays no window-level hit testing.
private struct ShadcnDismissCatcher: View {
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 6000, height: 6000)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }
}

// MARK: - Tooltip

/// shadcn's tooltip: `bg-foreground text-background rounded-md px-3 py-1.5
/// text-xs`, with the rotated-square arrow.
struct ShadcnTooltipModifier: ViewModifier {
    let text: String
    let edge: Edge
    let delay: Double

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false
    @State private var isVisible = false

    private var alignment: Alignment {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        // Guard against the pointer having left during the delay.
                        if isHovering { withAnimation(.easeOut(duration: 0.12)) { isVisible = true } }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.1)) { isVisible = false }
                }
            }
            .overlay(alignment: alignment) {
                if isVisible {
                    bubble
                        .fixedSize()
                        .offset(offset)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .allowsHitTesting(false)
                }
            }
            .zIndex(isVisible ? 1000 : 0)
    }

    private var offset: CGSize {
        switch edge {
        case .top: CGSize(width: 0, height: -34)
        case .bottom: CGSize(width: 0, height: 34)
        case .leading: CGSize(width: -12, height: 0)
        case .trailing: CGSize(width: 12, height: 0)
        }
    }

    private var bubble: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.xs))
            .foregroundStyle(palette.background)
            .padding(.horizontal, Space.x3)
            .padding(.vertical, Space.x1_5)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                    .fill(palette.foreground)
            )
            .overlay(alignment: arrowAlignment) {
                // `size-2.5 rotate-45 rounded-[2px]` — a square corner-on.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.foreground)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(45))
                    .offset(arrowOffset)
            }
    }

    private var arrowAlignment: Alignment {
        switch edge {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
    }

    private var arrowOffset: CGSize {
        switch edge {
        case .top: CGSize(width: 0, height: 4)
        case .bottom: CGSize(width: 0, height: -4)
        case .leading: CGSize(width: 4, height: 0)
        case .trailing: CGSize(width: -4, height: 0)
        }
    }
}

extension View {
    /// Attaches a shadcn-styled tooltip.
    public func shadcnTooltip(
        _ text: String,
        edge: Edge = .top,
        delay: Double = 0.35
    ) -> some View {
        modifier(ShadcnTooltipModifier(text: text, edge: edge, delay: delay))
    }
}

// MARK: - Popover

/// `w-72 rounded-md border bg-popover p-4 shadow-md` anchored to its trigger.
public struct ShadcnPopover<Trigger: View, Content: View>: View {
    @Binding private var isPresented: Bool
    private let width: CGFloat
    private let edge: VerticalEdge
    private let alignment: HorizontalAlignment
    private let trigger: Trigger
    private let content: Content

    public init(
        isPresented: Binding<Bool>,
        width: CGFloat = 288,
        edge: VerticalEdge = .bottom,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder trigger: () -> Trigger,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.width = width
        self.edge = edge
        self.alignment = alignment
        self.trigger = trigger()
        self.content = content()
    }

    public var body: some View {
        trigger
            .shadcnOverlay(
                isPresented: isPresented,
                edge: edge,
                alignment: alignment
            ) {
                ZStack(alignment: .topLeading) {
                    ShadcnDismissCatcher {
                        withAnimation(.easeOut(duration: 0.12)) { isPresented = false }
                    }
                    ShadcnPanel(padding: Space.x4) { content }
                        .frame(width: width)
                        .fixedSize()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
    }
}

// MARK: - Dropdown menu

/// One row in a dropdown: `rounded-sm px-2 py-1.5 text-sm`, highlighting to
/// `bg-accent` on hover.
public struct ShadcnMenuItem: View {
    private let title: String
    private let systemImage: String?
    private let isSelected: Bool
    private let isDestructive: Bool
    private let action: () -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false

    public init(
        _ title: String,
        systemImage: String? = nil,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.isDestructive = isDestructive
        self.action = action
    }

    private var foreground: Color {
        if isDestructive { return palette.destructive }
        return isHovering ? palette.accentForeground : palette.popoverForeground
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Space.x2) {
                if let systemImage {
                    ShadcnIconView(systemImage, size: 16)
                }
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: Space.x4)
                if isSelected {
                    ShadcnIconView(ShadcnIcon.check, size: 16)
                }
            }
            .font(theme.typography.sans(theme.typography.sm))
            .foregroundStyle(foreground)
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x1_5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.sm, style: .continuous)
                    .fill(isHovering ? palette.accent : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.shadcnBare)
        .onHover { isHovering = $0 }
    }
}

/// `px-2 py-1.5 text-xs text-muted-foreground` section heading.
public struct ShadcnMenuLabel: View {
    private let text: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.xs, weight: .medium))
            .foregroundStyle(palette.mutedForeground)
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x1_5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `-mx-1 my-1 h-px bg-border` divider between menu groups.
public struct ShadcnMenuSeparator: View {
    @Environment(\.shadcnPalette) private var palette

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(palette.border)
            .frame(height: 1)
            .padding(.vertical, Space.x1)
    }
}

/// Radix `DropdownMenu` anchored under its trigger.
public struct ShadcnDropdownMenu<Trigger: View, Content: View>: View {
    @Binding private var isPresented: Bool
    private let minWidth: CGFloat
    private let edge: VerticalEdge
    private let alignment: HorizontalAlignment
    private let trigger: Trigger
    private let content: Content

    public init(
        isPresented: Binding<Bool>,
        minWidth: CGFloat = 180,
        edge: VerticalEdge = .bottom,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder trigger: () -> Trigger,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.minWidth = minWidth
        self.edge = edge
        self.alignment = alignment
        self.trigger = trigger()
        self.content = content()
    }

    public var body: some View {
        trigger
            .shadcnOverlay(isPresented: isPresented, edge: edge, alignment: alignment) {
                ZStack(alignment: .topLeading) {
                    ShadcnDismissCatcher {
                        withAnimation(.easeOut(duration: 0.12)) { isPresented = false }
                    }
                    ShadcnPanel {
                        content
                    }
                    .frame(minWidth: minWidth)
                    .fixedSize()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
    }
}

// MARK: - Select

/// Radix `Select` — a trigger showing the current value plus a dropdown of
/// options. Trigger chrome matches `Input`.
public struct ShadcnSelect<Value: Hashable>: View {
    private let placeholder: String
    @Binding private var selection: Value?
    private let options: [(value: Value, label: String)]
    private let width: CGFloat?
    /// Composer-sized: 28pt tall at `text-xs`, rather than the 36pt form control.
    private let isCompact: Bool
    /// Accepted but not honoured — every menu opens downward. See
    /// `ShadcnOverlayHost` for the five approaches already ruled out.
    private let edge: VerticalEdge

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isOpen = false
    @State private var isHovering = false

    public init(
        _ placeholder: String,
        selection: Binding<Value?>,
        width: CGFloat? = nil,
        startsOpen: Bool = false,
        isCompact: Bool = false,
        edge: VerticalEdge = .bottom,
        options: [(value: Value, label: String)]
    ) {
        self.placeholder = placeholder
        self._selection = selection
        self.options = options
        self.width = width
        self.isCompact = isCompact
        self.edge = edge
        self._isOpen = State(initialValue: startsOpen)
    }

    private var currentLabel: String? {
        options.first { $0.value == selection }?.label
    }

    public var body: some View {
        ShadcnDropdownMenu(
            isPresented: $isOpen,
            minWidth: width ?? 180,
            edge: edge
        ) {
            Button {
                withAnimation(.easeOut(duration: 0.12)) { isOpen.toggle() }
            } label: {
                HStack(spacing: Space.x2) {
                    Text(currentLabel ?? placeholder)
                        .foregroundStyle(
                            currentLabel == nil ? palette.mutedForeground : palette.foreground
                        )
                        .lineLimit(1)
                    Spacer(minLength: Space.x2)
                    ShadcnIconView(ShadcnIcon.chevronDown, size: 16)
                        .foregroundStyle(palette.mutedForeground.opacity(0.8))
                }
                .font(
                    theme.typography.sans(
                        isCompact ? theme.typography.xs : theme.typography.sm))
                .padding(.horizontal, isCompact ? Space.x2 : Space.x3)
                .frame(height: isCompact ? 28 : 36)
                .frame(width: width)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                        .fill(palette.isDark ? palette.input.opacity(0.3) : palette.background)
                )
                .shadcnBorder(
                    isOpen ? palette.ring : palette.input,
                    cornerRadius: theme.radius.md
                )
                .shadcnShadow(.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.shadcnBare)
            .opacity(isEnabled ? 1 : 0.5)
        } content: {
            ForEach(options, id: \.value) { option in
                ShadcnMenuItem(
                    option.label,
                    isSelected: option.value == selection
                ) {
                    selection = option.value
                    withAnimation(.easeOut(duration: 0.12)) { isOpen = false }
                }
            }
        }
    }
}

// MARK: - Hover card

/// `w-64 rounded-md border bg-popover p-4 shadow-md`, revealed on hover.
public struct ShadcnHoverCard<Trigger: View, Content: View>: View {
    private let width: CGFloat
    private let trigger: Trigger
    private let content: Content

    @State private var isHovering = false
    @State private var isVisible = false

    public init(
        width: CGFloat = 256,
        @ViewBuilder trigger: () -> Trigger,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.trigger = trigger()
        self.content = content()
    }

    public var body: some View {
        trigger
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if isHovering { withAnimation(.easeOut(duration: 0.15)) { isVisible = true } }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.12)) { isVisible = false }
                }
            }
            .overlay(alignment: .top) {
                if isVisible {
                    ShadcnPanel(padding: Space.x4) { content }
                        .frame(width: width)
                        .fixedSize()
                        .offset(y: -8)
                        .alignmentGuide(.top) { $0[.bottom] }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .zIndex(isVisible ? 900 : 0)
    }
}

// MARK: - Dialog

/// Radix `Dialog` — a `bg-black/50` scrim over a
/// `rounded-lg border bg-background p-6 shadow-lg` panel.
struct ShadcnDialogModifier<DialogContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let width: CGFloat
    let dialogContent: DialogContent

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
                            }

                        VStack(alignment: .leading, spacing: Space.x4) {
                            dialogContent
                        }
                        .padding(Space.x6)
                        .frame(width: width)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous)
                                .fill(palette.background)
                        )
                        .shadcnBorder(palette.border, cornerRadius: theme.radius.lg)
                        .shadcnShadow(.lg)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    .zIndex(1000)
                }
            }
    }
}

extension View {
    /// Presents a shadcn dialog over this view.
    public func shadcnDialog<Content: View>(
        isPresented: Binding<Bool>,
        width: CGFloat = 512,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(
            ShadcnDialogModifier(
                isPresented: isPresented,
                width: width,
                dialogContent: content()
            )
        )
    }
}
