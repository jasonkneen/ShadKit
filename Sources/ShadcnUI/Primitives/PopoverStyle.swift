import SwiftUI

// MARK: - Popover design contract

/// One visual contract for every floating picker and popup menu (conversation
/// switcher, model picker, composer menus). Popups previously each picked
/// their own corners, fills and greys — pills next to squares, a black
/// selection tile next to a lavender one — so they read as different apps.
///
/// Rules:
/// - Panel: `panelRadius` corners, `panelPadding` inset, `scrimOpacity` of the
///   popover colour over native glass so content behind doesn't bleed through.
/// - Everything inside (search, rows, tabs, rail tiles, buttons) uses
///   `controlRadius`. No capsules except genuinely circular icon buttons.
/// - Fills are the theme foreground at `hoverFill` / `selectedFill` /
///   `pressedFill`. Never `accent`, black, or a tinted selection.
/// - Text has three levels: foreground, `secondaryText`, `tertiaryText`.
/// - One primary action per popup, trailing, inside `ShadcnPopoverFooter`.
public enum ShadcnPopoverStyle {
    public static let panelRadius: CGFloat = 14
    public static let controlRadius: CGFloat = 8
    public static let panelPadding: CGFloat = 8
    public static let sectionSpacing: CGFloat = 8

    /// Glass menus use a subtle foreground wash, never an opaque accent tile.
    /// Accessibility and non-glass menus retain their original theme fill.
    public static func rowHighlight(
        _ palette: ShadcnPalette, glass: Bool, reduceTransparency: Bool
    ) -> Color {
        glass && !reduceTransparency
            ? palette.popoverForeground.opacity(hoverFill)
            : palette.accent
    }

    public static let rowGap: CGFloat = 2
    /// Minimums, not fixed heights: long titles and larger text can grow.
    public static let rowMinHeight: CGFloat = 28
    public static let twoLineRowMinHeight: CGFloat = 40
    public static let rowHorizontalPadding: CGFloat = 8
    public static let rowVerticalPadding: CGFloat = 5

    public static let fieldHeight: CGFloat = 30
    public static let buttonHeight: CGFloat = 28

    public static let fieldFill: Double = 0.06
    public static let hoverFill: Double = 0.06
    public static let selectedFill: Double = 0.10
    public static let pressedFill: Double = 0.14
    public static let disabledFill: Double = 0.08

    public static let secondaryText: Double = 0.62
    public static let tertiaryText: Double = 0.45
    public static let disabledText: Double = 0.35

    /// Popover-colour layer painted over native glass. 0.6 still let the
    /// transcript read straight through the panel (model names over chat
    /// text were genuinely hard to parse), so the scrim is now strong
    /// enough that rows sit on a dependable surface; the glass survives
    /// as a soft halo at the edges rather than as bleed-through.
    public static let scrimOpacity: Double = 0.85
}

public extension ShadcnPalette {
    /// Secondary text: snippets, icons, menu labels.
    var popoverSecondary: Color { foreground.opacity(ShadcnPopoverStyle.secondaryText) }
    /// Tertiary text: placeholders, timestamps, chevrons.
    var popoverTertiary: Color { foreground.opacity(ShadcnPopoverStyle.tertiaryText) }

    /// Neutral fill for a row/tab/tile in the given interaction state.
    func popoverFill(selected: Bool = false, hovered: Bool = false, pressed: Bool = false) -> Color {
        if pressed { return foreground.opacity(ShadcnPopoverStyle.pressedFill) }
        if selected { return foreground.opacity(ShadcnPopoverStyle.selectedFill) }
        if hovered { return foreground.opacity(ShadcnPopoverStyle.hoverFill) }
        return .clear
    }
}

// MARK: - Surface

private struct ShadcnPopoverSurfaceModifier: ViewModifier {
    @Environment(\.shadcnOnNativeChrome) private var onNativeChrome
    @Environment(\.shadcnGlassEnabled) private var glassEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.shadcnPalette) private var palette

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: ShadcnPopoverStyle.panelRadius, style: .continuous)
        if onNativeChrome {
            // Native chrome already supplies the glass material. Do not bury
            // it under the legacy opaque scrim when Liquid Glass is enabled.
            // Keep the stronger surface for non-glass menus and accessibility.
            content
                .background(shape.fill(palette.popover.opacity(
                    reduceTransparency ? 1 : (glassEnabled ? ShadcnOverlayAppearance.tintOpacity : ShadcnPopoverStyle.scrimOpacity))))
                .foregroundStyle(palette.popoverForeground)
        } else {
            content.shadcnOverlayAppearance(cornerRadius: ShadcnPopoverStyle.panelRadius)
        }
    }
}

public extension View {
    /// The standard popup panel: 14pt corners plus the shared scrim/material.
    /// Apply after the panel's own padding and frame.
    func shadcnPopoverSurface() -> some View {
        modifier(ShadcnPopoverSurfaceModifier())
    }

    /// Standard row/tab/tile background for a popup list item.
    /// `cornerRadius` defaults to the shared control radius; pass a smaller
    /// value for an item nested inside another rounded control (a segment
    /// inside a track) so its corners follow the outer curve.
    func shadcnPopoverRowBackground(
        selected: Bool, hovered: Bool, cornerRadius: CGFloat? = nil
    ) -> some View {
        modifier(ShadcnPopoverRowBackground(
            selected: selected, hovered: hovered,
            cornerRadius: cornerRadius ?? ShadcnPopoverStyle.controlRadius))
    }
}

private struct ShadcnPopoverRowBackground: ViewModifier {
    let selected: Bool
    let hovered: Bool
    let cornerRadius: CGFloat
    @Environment(\.shadcnPalette) private var palette

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(palette.popoverFill(selected: selected, hovered: hovered)))
    }
}

// MARK: - Search field

/// The one search field every searchable popup starts with.
public struct ShadcnPopoverSearchField: View {
    @Binding private var text: String
    private let placeholder: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        HStack(spacing: Space.x2) {
            ShadcnIconView(ShadcnIcon.search, size: 13)
                .foregroundStyle(palette.popoverTertiary)
            TextField(
                placeholder, text: $text,
                prompt: Text(placeholder).foregroundStyle(palette.popoverTertiary))
                .textFieldStyle(.plain)
                .font(theme.typography.sans(theme.typography.sm))
                .foregroundStyle(palette.foreground)
        }
        .padding(.horizontal, ShadcnPopoverStyle.rowHorizontalPadding)
        .frame(height: ShadcnPopoverStyle.fieldHeight)
        .background(
            RoundedRectangle(cornerRadius: ShadcnPopoverStyle.controlRadius, style: .continuous)
                .fill(palette.foreground.opacity(ShadcnPopoverStyle.fieldFill)))
        .accessibilityLabel(placeholder)
    }
}

// MARK: - Tabs

/// A text tab (e.g. Recents / Archived). Selected uses the neutral selected
/// fill with the shared control radius — never a pill or a coloured slab.
///
/// Inside a segmented track (`ShadcnPopoverSegments`) a tab fills its share
/// of the width and uses an inner radius so its corners follow the track's.
public struct ShadcnPopoverTab: View {
    private let title: String
    private let isOn: Bool
    private let cornerRadius: CGFloat?
    private let expands: Bool
    private let action: () -> Void

    @State private var hovered = false
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        _ title: String, isOn: Bool,
        cornerRadius: CGFloat? = nil, expands: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isOn = isOn
        self.cornerRadius = cornerRadius
        self.expands = expands
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .fixedSize()
                .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                .foregroundStyle(isOn ? palette.foreground : palette.popoverSecondary)
                .padding(.horizontal, ShadcnPopoverStyle.rowHorizontalPadding)
                .frame(maxWidth: expands ? .infinity : nil)
                .frame(height: 24)
                .shadcnPopoverRowBackground(
                    selected: isOn, hovered: hovered, cornerRadius: cornerRadius)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Equal-width exclusive choices in one track (e.g. Ask / Allow / Block):
/// the field fill at the control radius outside, tabs with an inner radius
/// inside, so the selected segment's corners sit concentric with the track.
public struct ShadcnPopoverSegments<Option: Hashable>: View {
    public static var trackPadding: CGFloat { 2 }
    public static var innerRadius: CGFloat { ShadcnPopoverStyle.controlRadius - trackPadding }

    private let options: [Option]
    @Binding private var selection: Option
    private let title: (Option) -> String

    @Environment(\.shadcnPalette) private var palette

    public init(
        _ options: [Option], selection: Binding<Option>,
        title: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        HStack(spacing: ShadcnPopoverStyle.rowGap) {
            ForEach(options, id: \.self) { option in
                ShadcnPopoverTab(
                    title(option), isOn: selection == option,
                    cornerRadius: Self.innerRadius, expands: true
                ) {
                    selection = option
                }
            }
        }
        .padding(Self.trackPadding)
        .background(
            RoundedRectangle(cornerRadius: ShadcnPopoverStyle.controlRadius, style: .continuous)
                .fill(palette.foreground.opacity(ShadcnPopoverStyle.fieldFill)))
    }
}

// MARK: - Menu trigger

/// Dropdown trigger: optional leading icon, label, small trailing chevron.
///
/// Uses `.menuStyle(.button)` + a plain button style so macOS renders our
/// label as laid out. `.borderlessButton` collapses a custom label to
/// "image + title" and moves the chevron image to the *leading* side, which
/// is where the oversized `∨ All agents` chevron came from.
public struct ShadcnPopoverMenu<Items: View>: View {
    private let title: String
    private let systemImage: String?
    private let items: Items

    @State private var hovered = false
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ title: String, systemImage: String? = nil, @ViewBuilder items: () -> Items) {
        self.title = title
        self.systemImage = systemImage
        self.items = items()
    }

    public var body: some View {
        Menu {
            items
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    ShadcnIconView(systemImage, size: 13)
                }
                Text(title)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: ShadcnIcon.chevronDown)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(palette.popoverTertiary)
            }
            .font(theme.typography.sans(theme.typography.xs, weight: .medium))
            .foregroundStyle(palette.popoverSecondary)
            .padding(.horizontal, ShadcnPopoverStyle.rowHorizontalPadding)
            .frame(height: 24)
            .shadcnPopoverRowBackground(selected: false, hovered: hovered)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovered = $0 }
    }
}

// MARK: - Primary action

/// The single primary action of a popup. 28pt tall, shared control radius,
/// and a disabled state that is clearly inert rather than a faded slab.
public struct ShadcnPopoverPrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    ShadcnIconView(systemImage, size: 13)
                }
                Text(title).lineLimit(1).fixedSize()
            }
            .font(theme.typography.sans(theme.typography.xs, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: ShadcnPopoverStyle.buttonHeight)
        }
        .buttonStyle(PrimaryStyle(palette: palette, isEnabled: isEnabled))
    }

    private struct PrimaryStyle: ButtonStyle {
        let palette: ShadcnPalette
        let isEnabled: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled
                    ? palette.primaryForeground
                    : palette.foreground.opacity(ShadcnPopoverStyle.disabledText))
                .background(
                    RoundedRectangle(cornerRadius: ShadcnPopoverStyle.controlRadius, style: .continuous)
                        .fill(isEnabled
                            ? palette.primary.opacity(configuration.isPressed ? 0.85 : 1)
                            : palette.foreground.opacity(ShadcnPopoverStyle.disabledFill)))
                .contentShape(Rectangle())
        }
    }
}

/// A popup's secondary action (Cancel, Back): same 28pt height and radius as
/// `ShadcnPopoverPrimaryButton`, no fill at rest, neutral hover fill.
public struct ShadcnPopoverSecondaryButton: View {
    private let title: String
    private let role: ButtonRole?
    private let action: () -> Void

    @State private var hovered = false
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    /// `role: .destructive` keeps the same shape but colours the label with
    /// the theme's destructive colour (Delete, Remove).
    public init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .lineLimit(1)
                .fixedSize()
                .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                .foregroundStyle(role == .destructive ? palette.destructive : palette.popoverSecondary)
                .padding(.horizontal, 12)
                .frame(height: ShadcnPopoverStyle.buttonHeight)
                .shadcnPopoverRowBackground(selected: false, hovered: hovered)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Footer

/// Fixed footer below a popup's list, separated by a hairline so the list
/// scrolls cleanly above it. Secondary controls leading, primary trailing.
public struct ShadcnPopoverFooter<Content: View>: View {
    private let content: Content
    @Environment(\.shadcnPalette) private var palette

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 0.5)
                .padding(.horizontal, -ShadcnPopoverStyle.panelPadding)
            HStack(spacing: Space.x2) {
                content
            }
            .padding(.top, ShadcnPopoverStyle.panelPadding)
        }
    }
}
