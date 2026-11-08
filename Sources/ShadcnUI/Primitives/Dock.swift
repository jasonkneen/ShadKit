import SwiftUI

// MARK: - Model

/// One entry in a ``ShadcnDock``: an icon button or a separator.
public struct ShadcnDockItem: Identifiable {
    public enum Kind: Equatable, Sendable { case item, separator }

    /// How `image` is drawn inside the tile.
    public enum ImageStyle: Equatable, Sendable {
        /// A small monochrome glyph centred on the tile (default).
        case glyph
        /// A finished, full-colour icon that fills the slot, like an app
        /// icon in the macOS Dock. The tile fill is omitted.
        case icon
        /// A picture of the content (screenshot, photo) cropped to fill the
        /// tile, aligned to its top edge, with a hairline border.
        case preview
    }

    public let id: String
    public var kind: Kind
    public var title: String
    public var image: Image?
    public var imageStyle: ImageStyle
    public var systemImage: String?
    /// Glyph tint. `nil` uses the theme's primary colour.
    public var color: Color?
    /// Shows the small dot under the icon.
    public var isRunning: Bool
    /// Count shown in the corner badge; `nil` or 0 hides it.
    public var badge: Int?
    public var action: () -> Void

    public init(
        id: String,
        title: String,
        image: Image? = nil,
        imageStyle: ImageStyle = .glyph,
        systemImage: String? = nil,
        color: Color? = nil,
        isRunning: Bool = false,
        badge: Int? = nil,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.kind = .item
        self.title = title
        self.image = image
        self.imageStyle = imageStyle
        self.systemImage = systemImage
        self.color = color
        self.isRunning = isRunning
        self.badge = badge
        self.action = action
    }

    public static func separator(id: String) -> ShadcnDockItem {
        var item = ShadcnDockItem(id: id, title: "", action: {})
        item.kind = .separator
        return item
    }
}

// MARK: - Geometry

/// Size and magnification maths for ``ShadcnDock``, kept free of SwiftUI so
/// it can be unit-tested and used by AppKit hosts to size their frame.
public struct ShadcnDockMetrics: Equatable, Sendable {
    public var iconSize: CGFloat = 36
    /// Scale of the item directly under the pointer.
    public var maxScale: CGFloat = 1.6
    public var spacing: CGFloat = 6
    public var padding: CGFloat = 6
    /// Width a separator occupies (its 1pt rule sits in the middle).
    public var separatorWidth: CGFloat = 9
    /// How far the swell reaches, in item pitches either side of the pointer.
    public var falloff: CGFloat = 2.5
    /// Room above the icons for the hover label.
    public var labelHeadroom: CGFloat = 30

    public init() {}

    public var pitch: CGFloat { iconSize + spacing }
    public var range: CGFloat { pitch * falloff }
    /// Height of the bar itself at rest.
    public var barHeight: CGFloat { iconSize + padding * 2 }
    /// Height the icons and bar can reach while magnified.
    public var magnifiedHeight: CGFloat { iconSize * maxScale + padding * 2 }
    /// Full frame height a host must reserve: magnified icons plus the label.
    public var containerHeight: CGFloat { magnifiedHeight + labelHeadroom }

    /// Cosine falloff: `maxScale` at distance 0, easing to 1 at `range`.
    public static func scale(distance: CGFloat, maxScale: CGFloat, range: CGFloat) -> CGFloat {
        guard range > 0, maxScale > 1 else { return 1 }
        let d = abs(distance)
        guard d < range else { return 1 }
        return 1 + (maxScale - 1) * (cos(.pi * d / range) + 1) / 2
    }

    private func restingWidth(of kind: ShadcnDockItem.Kind) -> CGFloat {
        kind == .separator ? separatorWidth : iconSize
    }

    /// Centre of each entry at rest, measured from the bar's leading edge.
    public func restingCenters(_ kinds: [ShadcnDockItem.Kind]) -> [CGFloat] {
        var x = padding
        return kinds.map { kind in
            let w = restingWidth(of: kind)
            defer { x += w + spacing }
            return x + w / 2
        }
    }

    public func restingWidth(_ kinds: [ShadcnDockItem.Kind]) -> CGFloat {
        guard !kinds.isEmpty else { return padding * 2 }
        let content = kinds.reduce(0) { $0 + restingWidth(of: $1) }
        return padding * 2 + content + spacing * CGFloat(kinds.count - 1)
    }

    /// Width of each entry for a pointer at `pointer` (resting coordinates).
    /// Separators never scale.
    public func widths(_ kinds: [ShadcnDockItem.Kind], pointer: CGFloat?) -> [CGFloat] {
        let centers = restingCenters(kinds)
        return zip(kinds, centers).map { kind, center in
            guard kind == .item else { return separatorWidth }
            guard let pointer else { return iconSize }
            return iconSize * Self.scale(distance: center - pointer, maxScale: maxScale, range: range)
        }
    }

    public func width(_ kinds: [ShadcnDockItem.Kind], pointer: CGFloat?) -> CGFloat {
        guard !kinds.isEmpty else { return padding * 2 }
        return padding * 2 + widths(kinds, pointer: pointer).reduce(0, +)
            + spacing * CGFloat(kinds.count - 1)
    }

    /// Widest the bar gets for any pointer position: the frame a host should
    /// reserve so the bar can swell without the host resizing on every move.
    public func maxWidth(_ kinds: [ShadcnDockItem.Kind]) -> CGFloat {
        let rest = restingWidth(kinds)
        let samples = stride(from: 0, through: rest, by: max(1, pitch / 8))
        return samples.reduce(rest) { max($0, width(kinds, pointer: $1)) }
    }
}

extension ShadcnDockMetrics {
    /// Where a resting-coordinate `pointer` lands on the swollen bar.
    public func mappedPosition(_ kinds: [ShadcnDockItem.Kind], pointer p: CGFloat) -> CGFloat {
        let ws = widths(kinds, pointer: p)
        var restX = padding, actX = padding
        if p <= restX { return p }
        for (index, kind) in kinds.enumerated() {
            let rw = kind == .separator ? separatorWidth : iconSize
            let aw = ws[index]
            if p <= restX + rw { return actX + (p - restX) * aw / rw }
            restX += rw
            actX += aw
            if index < kinds.count - 1 {
                if p <= restX + spacing { return actX + (p - restX) }
                restX += spacing
                actX += spacing
            }
        }
        return actX + (p - restX)
    }

    /// Leading offset of the bar inside a `maxWidth` container. Centred at
    /// rest; while swelling, placed so the point under the pointer stays
    /// under it (the bar grows around the cursor, as the macOS Dock does),
    /// clamped so it never leaves the container.
    /// Frame width a host should reserve. The bar rests centred and swells
    /// around the cursor, so each side needs room for the larger of the two
    /// one-sided swells (they differ next to a separator or the bar's ends).
    public func reservedWidth(_ kinds: [ShadcnDockItem.Kind]) -> CGFloat {
        let rest = restingWidth(kinds)
        let samples = stride(from: 0, through: rest, by: max(1, pitch / 8))
        let side = samples.reduce(CGFloat(0)) { worst, p in
            let left = mappedPosition(kinds, pointer: p) - p
            let right = width(kinds, pointer: p) - rest - left
            return max(worst, left, right)
        }
        return rest + side * 2
    }

    public func barOffset(_ kinds: [ShadcnDockItem.Kind], pointer: CGFloat?) -> CGFloat {
        let container = reservedWidth(kinds)
        let restLeft = (container - restingWidth(kinds)) / 2
        guard let pointer else { return restLeft }
        let ideal = restLeft + pointer - mappedPosition(kinds, pointer: pointer)
        return min(max(ideal, 0), max(0, container - width(kinds, pointer: pointer)))
    }
}

// MARK: - View

/// A magnifying dock: icons swell as the pointer passes, the one under it
/// largest and its neighbours following on a cosine falloff. Items show their
/// title as a label on hover, a dot when running and a count badge. Tab moves
/// between items and Return or Space activates the focused one.
///
/// The view sizes itself to ``ShadcnDockMetrics/reservedWidth(_:)`` ×
/// ``ShadcnDockMetrics/containerHeight`` so a host frame never has to change
/// while the pointer moves; the bar sits against `edge` and icons grow away
/// from it. Everything outside the bar and icons is transparent.
public struct ShadcnDock: View {
    public enum Edge: Sendable { case bottom, top }

    private let items: [ShadcnDockItem]
    private let edge: Edge
    private let metrics: ShadcnDockMetrics

    /// Pointer x in resting-bar coordinates, `nil` when not hovering.
    @State private var pointer: CGFloat?
    @FocusState private var focusedID: String?
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ items: [ShadcnDockItem], edge: Edge = .bottom, metrics: ShadcnDockMetrics = .init()) {
        self.items = items
        self.edge = edge
        self.metrics = metrics
    }

    private var kinds: [ShadcnDockItem.Kind] { items.map(\.kind) }
    private var verticalAlignment: VerticalAlignment { edge == .bottom ? .bottom : .top }
    private var frameAlignment: Alignment { edge == .bottom ? .bottom : .top }

    /// Where the swell is centred: the pointer, else the keyboard-focused item.
    private var swellCenter: CGFloat? {
        if reduceMotion { return nil }
        if let pointer { return pointer }
        guard let focusedID, let index = items.firstIndex(where: { $0.id == focusedID }) else { return nil }
        return metrics.restingCenters(kinds)[index]
    }

    private var highlightedID: String? {
        if let pointer {
            let centers = metrics.restingCenters(kinds)
            let nearest = zip(items, centers)
                .filter { $0.0.kind == .item }
                .min { abs($0.1 - pointer) < abs($1.1 - pointer) }
            guard let nearest, abs(nearest.1 - pointer) <= metrics.pitch / 2 else { return nil }
            return nearest.0.id
        }
        return focusedID
    }

    public var body: some View {
        let restWidth = metrics.restingWidth(kinds)
        let containerWidth = metrics.reservedWidth(kinds)
        let widths = metrics.widths(kinds, pointer: swellCenter)
        let highlighted = highlightedID

        HStack(alignment: verticalAlignment, spacing: metrics.spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if item.kind == .separator {
                    separator
                } else {
                    tile(item, size: widths[index], showsLabel: item.id == highlighted)
                }
            }
        }
        .padding(metrics.padding)
        .background(alignment: frameAlignment) { bar }
        .onContinuousHover(coordinateSpace: .named(Self.space)) { phase in
            switch phase {
            case .active(let location):
                let x = location.x - (containerWidth - restWidth) / 2
                if pointer == nil {
                    withAnimation(.easeOut(duration: 0.12)) { pointer = x }
                } else {
                    pointer = x
                }
            case .ended:
                withAnimation(.easeOut(duration: 0.18)) { pointer = nil }
            }
        }
        .padding(.leading, metrics.barOffset(kinds, pointer: swellCenter))
        .frame(
            width: containerWidth, height: metrics.containerHeight,
            alignment: edge == .bottom ? .bottomLeading : .topLeading)
        .coordinateSpace(name: Self.space)
        .animation(.easeOut(duration: 0.15), value: focusedID)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dock")
    }

    private static let space = "shadcn-dock"

    private var bar: some View {
        RoundedRectangle(cornerRadius: ShadcnPopoverStyle.panelRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: ShadcnPopoverStyle.panelRadius, style: .continuous)
                    .fill(palette.popover.opacity(ShadcnPopoverStyle.scrimOpacity)))
            .overlay(
                RoundedRectangle(cornerRadius: ShadcnPopoverStyle.panelRadius, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 0.5))
            .frame(height: metrics.barHeight)
            .shadow(color: .black.opacity(palette.isDark ? 0.35 : 0.15), radius: 14, y: 6)
    }

    private var separator: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1, height: metrics.iconSize * 0.7)
            .frame(width: metrics.separatorWidth, height: metrics.iconSize)
            .accessibilityHidden(true)
    }

    private func tile(_ item: ShadcnDockItem, size: CGFloat, showsLabel: Bool) -> some View {
        let radius = size * 0.24
        let focused = focusedID == item.id
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let style: ShadcnDockItem.ImageStyle = item.image == nil ? .glyph : item.imageStyle
        return ZStack {
            switch style {
            case .glyph:
                // No tile behind a glyph: the accent-tinted symbol alone is
                // the icon, so highlights come from colour, not boxes.
                glyph(item)
                    .frame(width: size * 0.62, height: size * 0.62)
                    .foregroundStyle(item.color ?? palette.primary)
            case .icon:
                if let image = item.image {
                    image.resizable().interpolation(.high).scaledToFit()
                        .frame(width: size, height: size)
                }
            case .preview:
                shape.fill(Color.black.opacity(0.55))
                if let image = item.image {
                    image.resizable().interpolation(.high).scaledToFill()
                        .frame(width: size, height: size, alignment: .top)
                        .clipShape(shape)
                }
                shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(palette.ring, lineWidth: 2)
            }
        }
        .overlay(alignment: .topTrailing) { badge(item.badge) }
        // Running dot sits in the bar's padding, on the side nearest the edge.
        .overlay(alignment: edge == .bottom ? .bottom : .top) {
            if item.isRunning {
                Circle()
                    .fill((item.color ?? palette.foreground).opacity(ShadcnPopoverStyle.secondaryText))
                    .frame(width: 4, height: 4)
                    .offset(y: edge == .bottom ? metrics.padding - 1 : 1 - metrics.padding)
            }
        }
        .overlay(alignment: edge == .bottom ? .top : .bottom) {
            if showsLabel { label(item.title) }
        }
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .onTapGesture { item.action() }
        .focusable()
        .focusEffectDisabled()
        .focused($focusedID, equals: item.id)
        .onKeyPress(.return) { item.action(); return .handled }
        .onKeyPress(.space) { item.action(); return .handled }
        .accessibilityElement()
        .accessibilityLabel(item.title)
        .accessibilityValue(accessibilityValue(item))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { item.action() }
    }

    @ViewBuilder
    private func glyph(_ item: ShadcnDockItem) -> some View {
        if let image = item.image {
            image.resizable().scaledToFit()
        } else if let symbol = item.systemImage {
            Image(systemName: symbol).resizable().scaledToFit()
        } else {
            Text(item.title.prefix(1).uppercased())
                .font(theme.typography.sans(theme.typography.sm, weight: .semibold))
        }
    }

    @ViewBuilder
    private func badge(_ count: Int?) -> some View {
        if let count, count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(minWidth: 16, minHeight: 16)
                .background(Capsule().fill(Color.red))
                .offset(x: 5, y: -5)
                .accessibilityHidden(true)
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(theme.typography.sans(theme.typography.xs, weight: .medium))
            .foregroundStyle(palette.popoverForeground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, ShadcnPopoverStyle.rowHorizontalPadding)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: ShadcnPopoverStyle.controlRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: ShadcnPopoverStyle.controlRadius, style: .continuous)
                            .fill(palette.popover.opacity(ShadcnPopoverStyle.scrimOpacity))))
            .offset(y: edge == .bottom ? -28 : 28)
            .allowsHitTesting(false)
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    private func accessibilityValue(_ item: ShadcnDockItem) -> String {
        var parts: [String] = []
        if item.isRunning { parts.append("Running") }
        if let badge = item.badge, badge > 0 { parts.append("\(badge) new") }
        return parts.joined(separator: ", ")
    }
}
