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
            // Thick, so bright content behind a floating panel (a white
            // bubble) does not smear through it as a grey block.
            ShadcnTranslucentFill(
                color: palette.popover, cornerRadius: theme.radius.md,
                material: .thickMaterial)
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
    /// Stable while this control lives — never regenerated on layout.
    @State private var overlayID = UUID()

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
                id: overlayID,
                isPresented: isPresented,
                edge: edge,
                alignment: alignment,
                contentWidth: width,
                onDismiss: { isPresented = false }
            ) {
                ShadcnPanel(padding: Space.x4) { content }
                    .frame(width: width)
                    .fixedSize()
            }
    }
}

// MARK: - Dropdown menu

/// One row in a dropdown: `rounded-sm px-2 py-1.5 text-sm`, highlighting to
/// `bg-accent` on hover.
public struct ShadcnMenuItem: View {
    private let title: String
    private let systemImage: String?
    /// Brand logo (models.dev-style). Preferred over `systemImage` when set.
    private let image: Image?
    /// 0…1 fill for variable SF Symbols (`cellularbars`, etc.).
    private let symbolVariableValue: Double?
    private let isSelected: Bool
    private let isDestructive: Bool
    private let action: () -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false

    public init(
        _ title: String,
        systemImage: String? = nil,
        image: Image? = nil,
        symbolVariableValue: Double? = nil,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.image = image
        self.symbolVariableValue = symbolVariableValue
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
                leadingIcon
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

    @ViewBuilder
    private var leadingIcon: some View {
        if let image {
            image
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
        } else if let systemImage {
            ShadcnIconView(systemImage, size: 16, variableValue: symbolVariableValue)
        }
    }
}

/// One option in a `ShadcnSelect` — label plus optional brand/system icon.
///
/// Mirrors AI Elements' model selector rows (logo + name). Use `image` for
/// models.dev-style brand SVGs and `systemImage` as a fallback glyph.
/// Set `symbolVariableValue` (0…1) for multi-level symbols like `cellularbars`.
public struct ShadcnSelectOption<Value: Hashable>: Identifiable {
    public var id: Value { value }
    public var value: Value
    public var label: String
    public var systemImage: String?
    public var image: Image?
    public var symbolVariableValue: Double?

    public init(
        value: Value,
        label: String,
        systemImage: String? = nil,
        image: Image? = nil,
        symbolVariableValue: Double? = nil
    ) {
        self.value = value
        self.label = label
        self.systemImage = systemImage
        self.image = image
        self.symbolVariableValue = symbolVariableValue
    }

    /// Convenience for plain label-only options.
    public init(_ value: Value, label: String) {
        self.init(value: value, label: label, systemImage: nil, image: nil)
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
    /// Height of the menu panel, for placing it above the trigger. Optional
    /// on the AppKit path (U19-fix): the floating panel measures its own
    /// content, so this is only needed as an override, or by the iOS
    /// in-tree fallback below, which cannot measure ahead of layout.
    private let contentHeight: CGFloat?
    private let alignment: HorizontalAlignment
    private let trigger: Trigger
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    #if canImport(AppKit)
    @Environment(\.shadcnSurfaceOpacity) private var surfaceOpacity
    @Environment(\.shadcnGlassEnabled) private var glassEnabled
    @Environment(\.colorScheme) private var colorScheme
    /// A borderless `NSPanel`, positioned in real screen space — see
    /// `ShadcnFloatingPanelController`'s doc comment for why an in-tree
    /// SwiftUI overlay (the pre-U19-fix implementation, still used on iOS
    /// below) can't be trusted to escape an `NSHostingView` pane smaller
    /// than the menu.
    @State private var panelController = ShadcnFloatingPanelController()
    #else
    /// Stable while this control lives — never regenerated on layout.
    @State private var overlayID = UUID()
    #endif

    public init(
        isPresented: Binding<Bool>,
        minWidth: CGFloat = 180,
        edge: VerticalEdge = .bottom,
        alignment: HorizontalAlignment = .leading,
        contentHeight: CGFloat? = nil,
        @ViewBuilder trigger: () -> Trigger,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.minWidth = minWidth
        self.edge = edge
        self.alignment = alignment
        self.contentHeight = contentHeight
        self.trigger = trigger()
        self.content = content()
    }

    #if canImport(AppKit)
    public var body: some View {
        trigger
            .background(ShadcnFloatingAnchor(controller: panelController))
            .onChange(of: isPresented) { _, presented in
                if presented { showPanel() } else { panelController.close() }
            }
            // `.onChange` only fires on a *change* — a caller that starts
            // already presented (`startsOpen: true`, as `ShadcnSelect` wires
            // through) would never trigger it.
            .onAppear {
                if isPresented { showPanel() }
            }
            .onDisappear { panelController.close() }
    }

    private func showPanel() {
        panelController.show(
            edge: edge, alignment: alignment,
            contentWidth: minWidth, contentHeight: contentHeight,
            makesKey: true,
            onDismiss: { isPresented = false }
        ) {
            ShadcnPanel { content }
                .frame(width: minWidth)
                .fixedSize()
                .environment(\.shadcnTheme, theme)
                .environment(\.shadcnPalette, palette)
                .environment(\.shadcnSurfaceOpacity, surfaceOpacity)
                .environment(\.shadcnGlassEnabled, glassEnabled)
                .environment(\.colorScheme, colorScheme)
        }
    }
    #else
    public var body: some View {
        trigger
            .shadcnOverlay(
                id: overlayID,
                isPresented: isPresented,
                edge: edge,
                alignment: alignment,
                contentHeight: contentHeight,
                contentWidth: minWidth,
                onDismiss: { isPresented = false }
            ) {
                // Panel only — the dismiss layer lives on the host so it
                // cannot inflate this view's size and throw off placement.
                ShadcnPanel {
                    content
                }
                .frame(width: minWidth)
                .fixedSize()
            }
    }
    #endif
}

// MARK: - Select

/// What the closed select chip shows. Dropdown rows still use full labels.
public enum ShadcnSelectTriggerStyle: Sendable {
    /// Brand/system icon + label + chevron (default form control).
    case standard
    /// Icon + chevron only — compact provider or agent selector.
    case iconOnly
    /// One glyph with no redundant label or chevron — compact level indicators.
    case symbolOnly
    /// Label + chevron only — model name without a second brand mark.
    case labelOnly
}

/// Trigger glyph colour for `ShadcnSelect` (U22). Pure, so the "never
/// `primary` unless opted in" contract is pinned by a test rather than only
/// by reading the source.
func shadcnSelectTriggerIconTint(
    isSelected: Bool,
    tintsWithPrimary: Bool,
    palette: ShadcnPalette
) -> Color {
    if tintsWithPrimary { return palette.primary }
    return isSelected ? palette.foreground : palette.mutedForeground
}

/// Radix `Select` — a trigger showing the current value plus a dropdown of
/// options. Trigger chrome matches `Input`.
public struct ShadcnSelect<Value: Hashable>: View {
    private let placeholder: String
    @Binding private var selection: Value?
    private let options: [ShadcnSelectOption<Value>]
    private let width: CGFloat?
    /// Composer-sized: 28pt tall at `text-xs`, rather than the 36pt form control.
    private let isCompact: Bool
    /// What the closed chip shows (menu rows always show full label + icon).
    private let triggerStyle: ShadcnSelectTriggerStyle
    /// Open direction relative to the trigger. Composer pickers use `.top` so
    /// the menu stays inside a bottom-docked panel instead of clipping below it.
    private let edge: VerticalEdge
    /// Long lists scroll inside this many rows instead of growing the panel
    /// off-screen (upward placement uses this for `contentHeight`).
    private let maxVisibleRows: Int
    /// Opt-in (U22): `.iconOnly`/`.symbolOnly`/`.standard` trigger glyphs
    /// tint with `palette.primary` instead of the default foreground/
    /// mutedForeground-by-selection rule, for a consumer that wants the
    /// brand colour to read as an accent among neutral controls.
    private let tintsTriggerWithPrimary: Bool

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
        triggerStyle: ShadcnSelectTriggerStyle = .standard,
        edge: VerticalEdge = .bottom,
        maxVisibleRows: Int = 8,
        tintsTriggerWithPrimary: Bool = false,
        options: [ShadcnSelectOption<Value>]
    ) {
        self.placeholder = placeholder
        self._selection = selection
        self.options = options
        self.width = width
        self.isCompact = isCompact
        self.triggerStyle = triggerStyle
        self.edge = edge
        self.maxVisibleRows = max(1, maxVisibleRows)
        self.tintsTriggerWithPrimary = tintsTriggerWithPrimary
        self._isOpen = State(initialValue: startsOpen)
    }

    /// Label-only convenience — same as the original API.
    public init(
        _ placeholder: String,
        selection: Binding<Value?>,
        width: CGFloat? = nil,
        startsOpen: Bool = false,
        isCompact: Bool = false,
        triggerStyle: ShadcnSelectTriggerStyle = .standard,
        edge: VerticalEdge = .bottom,
        maxVisibleRows: Int = 8,
        tintsTriggerWithPrimary: Bool = false,
        options: [(value: Value, label: String)]
    ) {
        self.init(
            placeholder,
            selection: selection,
            width: width,
            startsOpen: startsOpen,
            isCompact: isCompact,
            triggerStyle: triggerStyle,
            edge: edge,
            maxVisibleRows: maxVisibleRows,
            tintsTriggerWithPrimary: tintsTriggerWithPrimary,
            options: options.map { ShadcnSelectOption(value: $0.value, label: $0.label) }
        )
    }

    /// One menu row: `py-1.5` around a `text-sm` line.
    public static var rowHeight: CGFloat { Space.x1_5 * 2 + 18 }

    /// Panel chrome: `p-1` plus 1pt border on each side.
    public static var panelChrome: CGFloat { Space.x1 * 2 + 2 }

    /// Height used for placement. Caps at `maxVisibleRows` so a 30-item list
    /// opening upward doesn't push its top edge off the host and leave only
    /// the last few rows visible near the trigger.
    public static func panelHeight(rows: Int, maxVisibleRows: Int = 8) -> CGFloat {
        let visible = min(max(rows, 0), max(1, maxVisibleRows))
        return CGFloat(visible) * rowHeight + panelChrome
    }

    /// Back-compat: uncapped height for a given row count.
    public static func panelHeight(rows: Int) -> CGFloat {
        panelHeight(rows: rows, maxVisibleRows: max(rows, 1))
    }

    private var current: ShadcnSelectOption<Value>? {
        options.first { $0.value == selection }
    }

    private var currentLabel: String? { current?.label }

    private var needsScroll: Bool {
        options.count > maxVisibleRows
    }

    private var menuHeight: CGFloat {
        Self.panelHeight(rows: options.count, maxVisibleRows: maxVisibleRows)
    }

    public var body: some View {
        ShadcnDropdownMenu(
            isPresented: $isOpen,
            minWidth: width ?? 180,
            edge: edge,
            // Placement height is the *visible* panel, not the unscoped list.
            contentHeight: edge == .top ? menuHeight : nil
        ) {
            Button {
                // No withAnimation — animating isOpen re-introduces the fly-in
                // as the host repositions the panel.
                isOpen.toggle()
            } label: {
                triggerLabel
                    .font(
                        theme.typography.sans(
                            isCompact ? theme.typography.xs : theme.typography.sm))
                    .padding(.horizontal, triggerHorizontalPadding)
                    .frame(height: isCompact ? 28 : 36)
                    .frame(width: width)
                    .frame(minWidth: triggerMinWidth)
                    .background(
                        ShadcnTranslucentFill(
                            color: palette.isDark ? palette.input : palette.background,
                            cornerRadius: theme.radius.md)
                    )
                    .shadcnBorder(
                        isOpen ? palette.ring : palette.input,
                        cornerRadius: theme.radius.md
                    )
                    .shadcnShadow(.xs)
                    .contentShape(Rectangle())
                    .accessibilityLabel(currentLabel ?? placeholder)
            }
            .buttonStyle(.shadcnBare)
            .opacity(isEnabled ? 1 : 0.5)
            .help(currentLabel ?? placeholder)
        } content: {
            // Cap tall lists: without this, upward placement offsets by the
            // full content height and only the tail of the list sits near the
            // trigger (looks like a broken, truncated popup).
            if needsScroll {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        menuRows
                    }
                }
                .frame(height: CGFloat(maxVisibleRows) * Self.rowHeight)
            } else {
                VStack(spacing: 0) {
                    menuRows
                }
            }
        }
    }

    private var triggerHorizontalPadding: CGFloat {
        switch triggerStyle {
        case .iconOnly, .symbolOnly: Space.x1_5
        case .labelOnly, .standard: isCompact ? Space.x2 : Space.x3
        }
    }

    private var triggerMinWidth: CGFloat? {
        // Icon chips hug content; fixed width still wins when set.
        guard width == nil else { return nil }
        switch triggerStyle {
        case .iconOnly, .symbolOnly: return isCompact ? 28 : 34
        case .labelOnly: return nil // hug model name
        case .standard: return nil
        }
    }

    private var chevron: some View {
        ShadcnIconView(ShadcnIcon.chevronDown, size: triggerStyle == .iconOnly ? 9 : 11)
            .foregroundStyle(palette.mutedForeground.opacity(0.75))
    }

    @ViewBuilder
    private var triggerLabel: some View {
        switch triggerStyle {
        case .iconOnly:
            // Brand glyph plus a tiny chevron affordance.
            HStack(spacing: 2) {
                triggerIcon(size: isCompact ? 14 : 16)
                chevron
            }
        case .symbolOnly:
            triggerIcon(size: isCompact ? 16 : 18)
        case .labelOnly:
            // Model name only — no second brand mark.
            HStack(spacing: Space.x1) {
                Text(currentLabel ?? placeholder)
                    .foregroundStyle(
                        currentLabel == nil ? palette.mutedForeground : palette.foreground
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                chevron
            }
        case .standard:
            HStack(spacing: Space.x2) {
                triggerIcon(size: isCompact ? 12 : 14)
                Text(currentLabel ?? placeholder)
                    .foregroundStyle(
                        currentLabel == nil ? palette.mutedForeground : palette.foreground
                    )
                    .lineLimit(1)
                Spacer(minLength: Space.x2)
                chevron
            }
        }
    }

    @ViewBuilder
    private func triggerIcon(size: CGFloat) -> some View {
        let tint = shadcnSelectTriggerIconTint(
            isSelected: current != nil, tintsWithPrimary: tintsTriggerWithPrimary, palette: palette)
        if let image = current?.image {
            image
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let systemImage = current?.systemImage {
            ShadcnIconView(
                systemImage, size: size,
                variableValue: current?.symbolVariableValue)
                .foregroundStyle(tint)
        } else {
            // Keep icon-only chips from collapsing when nothing is selected.
            ShadcnIconView(ShadcnIcon.sparkles, size: size)
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var menuRows: some View {
        ForEach(options) { option in
            ShadcnMenuItem(
                option.label,
                systemImage: option.systemImage,
                image: option.image,
                symbolVariableValue: option.symbolVariableValue,
                isSelected: option.value == selection
            ) {
                selection = option.value
                isOpen = false
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

    public init(
        width: CGFloat = 256,
        @ViewBuilder trigger: () -> Trigger,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.trigger = trigger()
        self.content = content()
    }

    /// Routed through `shadcnHoverOverlay` (root-hosted, flip/shift-aware) so
    /// a hover card near a clipped ancestor's edge — a rounded panel host, a
    /// scrollable pane — no longer gets silently cut off, matching every
    /// other floating primitive here. Centered above the trigger by default,
    /// same as the previous plain-`.overlay(alignment: .top)` placement.
    public var body: some View {
        trigger
            .shadcnHoverOverlay(width: width, edge: .top, alignment: .center) {
                content
            }
    }
}

/// A hover-triggered panel drawn unclipped at the root of the themed subtree
/// (see `shadcnOverlay`), unlike `ShadcnHoverCard`'s plain `.overlay`, which
/// an ancestor `.clipShape`/`.clipped()` — a rounded panel host, a scrollable
/// pane — silently cuts off. The panel also stays open while the pointer is
/// over *it*, not just the trigger, so its own content (buttons, links)
/// stays reachable instead of vanishing the moment the pointer leaves the
/// trigger on the way there.
struct ShadcnHoverOverlayModifier<Panel: View>: ViewModifier {
    let width: CGFloat
    let edge: VerticalEdge
    let alignment: HorizontalAlignment
    let showDelay: Double
    let hideDelay: Double
    let panel: Panel

    @State private var overlayID = UUID()
    @State private var isHoveringTrigger = false
    @State private var isHoveringPanel = false
    @State private var isVisible = false

    private var wantsVisible: Bool { isHoveringTrigger || isHoveringPanel }

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHoveringTrigger = hovering
                scheduleVisibilityUpdate()
            }
            .shadcnOverlay(
                id: overlayID,
                isPresented: isVisible,
                edge: edge,
                alignment: alignment,
                contentWidth: width,
                // Hover panels dismiss by the pointer leaving, never by an
                // outside click — see the flag's doc comment on
                // `ShadcnOverlayItem` for why an active catcher would break
                // the trigger's own hover-exit detection.
                dismissOnOutsideClick: false,
                onDismiss: { isVisible = false }
            ) {
                ShadcnPanel(padding: Space.x4) { panel }
                    .frame(width: width)
                    .fixedSize()
                    .onHover { hovering in
                        isHoveringPanel = hovering
                        scheduleVisibilityUpdate()
                    }
            }
    }

    /// Every scheduled check re-reads live state instead of a captured
    /// snapshot, so a trigger→panel handoff that lands inside `hideDelay`
    /// cancels itself out: the pending hide fires, sees `wantsVisible` is
    /// true again (the pointer landed on the panel), and no-ops.
    private func scheduleVisibilityUpdate() {
        if wantsVisible {
            guard !isVisible else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + showDelay) {
                if wantsVisible {
                    withAnimation(.easeOut(duration: 0.12)) { isVisible = true }
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) {
                if !wantsVisible {
                    withAnimation(.easeOut(duration: 0.1)) { isVisible = false }
                }
            }
        }
    }
}

extension View {
    /// Attaches a `ShadcnHoverOverlayModifier` panel to this view.
    public func shadcnHoverOverlay<Panel: View>(
        width: CGFloat = 256,
        edge: VerticalEdge = .bottom,
        alignment: HorizontalAlignment = .leading,
        showDelay: Double = 0.35,
        hideDelay: Double = 0.15,
        @ViewBuilder panel: () -> Panel
    ) -> some View {
        modifier(ShadcnHoverOverlayModifier(
            width: width, edge: edge, alignment: alignment,
            showDelay: showDelay, hideDelay: hideDelay, panel: panel()))
    }
}

// MARK: - Dialog

/// Radix `Dialog` — a `bg-black/50` scrim over a
/// `rounded-lg border bg-background p-6 shadow-lg` panel.
///
/// Drawn via `shadcnDialogOverlay` at the root of the themed subtree, like
/// every other floating primitive here — a plain `.overlay` is clipped by
/// whatever rounded/clipped ancestor frame the trigger happens to sit inside
/// (a composer footer, a scrollable pane), which cut the panel off before
/// this routed through the host.
struct ShadcnDialogModifier<DialogContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let width: CGFloat
    let dialogContent: DialogContent

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    #if canImport(AppKit)
    @Environment(\.shadcnSurfaceOpacity) private var surfaceOpacity
    @Environment(\.shadcnGlassEnabled) private var glassEnabled
    @Environment(\.colorScheme) private var colorScheme
    /// Window-backed (U19c): the in-tree host's dialog layer measured a
    /// fresh `NSHostingView`'s `fittingSize` as (0, 0) — the same bug
    /// `ShadcnFloatingPanelController` exists to fix for menus/selects —
    /// which made `AIWorkspacePicker`'s dialog invisible rather than merely
    /// clipped.
    @State private var panelController = ShadcnFloatingPanelController()
    #else
    /// Stable while this control lives — never regenerated on layout.
    @State private var overlayID = UUID()
    #endif

    #if canImport(AppKit)
    func body(content: Content) -> some View {
        content
            .background(ShadcnFloatingAnchor(controller: panelController))
            .onChange(of: isPresented) { _, presented in
                if presented { showDialog() } else { panelController.close() }
            }
            .onAppear {
                if isPresented { showDialog() }
            }
            .onDisappear { panelController.close() }
    }

    private func showDialog() {
        panelController.showCentered(
            onDismiss: { isPresented = false }
        ) {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }

                ShadcnDialogPanel(isPresented: $isPresented) {
                    dialogContent
                }
                .frame(width: width)
            }
            .environment(\.shadcnTheme, theme)
            .environment(\.shadcnPalette, palette)
            .environment(\.shadcnSurfaceOpacity, surfaceOpacity)
            .environment(\.shadcnGlassEnabled, glassEnabled)
            .environment(\.colorScheme, colorScheme)
        }
    }
    #else
    func body(content: Content) -> some View {
        content
            .shadcnDialogOverlay(
                id: overlayID,
                isPresented: isPresented,
                width: width,
                onDismiss: { withAnimation(.easeOut(duration: 0.15)) { isPresented = false } }
            ) {
                ShadcnDialogPanel(isPresented: $isPresented) {
                    dialogContent
                }
            }
    }
    #endif
}

/// The panel's own chrome plus the escape-to-dismiss shortcut. Reads
/// `palette`/`theme` from the environment injected by the host (not the
/// caller's local subtree), matching every other panel drawn there.
private struct ShadcnDialogPanel<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: Space.x4) {
                content
            }
            .padding(Space.x6)
            .background(
                ShadcnTranslucentFill(
                    color: palette.background,
                    cornerRadius: theme.radius.lg,
                    material: .regularMaterial)
            )
            .shadcnBorder(palette.border, cornerRadius: theme.radius.lg)
            .shadcnShadow(.lg)

            // Escape dismisses. A hidden button carrying the window-level
            // shortcut, not `.onKeyPress`, since the scrim never holds
            // keyboard focus itself.
            Button("") {
                withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
