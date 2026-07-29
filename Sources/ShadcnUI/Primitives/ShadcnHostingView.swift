#if canImport(AppKit)
import AppKit
import SwiftUI

/// Hosts a themed SwiftUI view inside an AppKit layout.
///
/// Embedding SwiftUI in AppKit is where this package is most likely to be
/// adopted — an existing app replacing one panel at a time — and it is also
/// where it is easiest to get wrong. This handles the three traps:
///
/// 1. **Sizing.** A bare `NSHostingView` reports an intrinsic content size and
///    will fight surrounding constraints, collapsing to a narrow column or
///    refusing to fill. `sizingOptions = []` makes it defer to Auto Layout.
/// 2. **Theming.** The view has to sit *below* the theme injection or the
///    palette resolves to its default. `ShadcnHostingView` applies the theme
///    for you.
/// 3. **Appearance.** AppKit panels are often a fixed light or dark surface
///    regardless of the system setting; `colorScheme:` pins it so the palette
///    matches the chrome around it.
///
/// ```swift
/// let host = ShadcnHostingView(colorScheme: .dark) { MyPanel() }
/// host.translatesAutoresizingMaskIntoConstraints = false
/// container.addSubview(host)
/// // pin all four edges as usual
/// ```
public final class ShadcnHostingView<Content: View>: NSView {
    private let hosting: NSHostingView<AnyView>

    public init(
        theme: ShadcnTheme = .default,
        colorScheme: ColorScheme? = nil,
        paintsBackground: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        var root = AnyView(content())
        if let colorScheme {
            root = AnyView(root.environment(\.colorScheme, colorScheme))
        }
        root = paintsBackground
            ? AnyView(root.shadcnSurface(theme))
            : AnyView(root.shadcnTheme(theme))

        hosting = NSHostingView(rootView: root)
        super.init(frame: .zero)

        // The fix for (1): without this the hosting view's intrinsic size
        // competes with the constraints the caller sets.
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if let colorScheme {
            // Keep AppKit's own appearance in step, so system-drawn pieces
            // (scrollers, selection, focus rings) match the palette.
            appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    /// Swaps the hosted content, keeping the theme and sizing setup.
    public func update(@ViewBuilder content: () -> Content) {
        hosting.rootView = AnyView(content())
    }

    /// A hosting view never draws its own background; the SwiftUI content owns
    /// the surface, so the AppKit layer stays transparent.
    public override var isOpaque: Bool { false }
}
#endif
