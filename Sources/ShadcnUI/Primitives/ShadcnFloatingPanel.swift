#if canImport(AppKit)
import AppKit
import SwiftUI

/// Invisible marker view that gives `ShadcnFloatingPanelController` a live
/// `NSView` — and therefore its `window`/screen frame — without changing
/// anything SwiftUI renders. Attach via `.background`.
struct ShadcnFloatingAnchor: NSViewRepresentable {
    let controller: ShadcnFloatingPanelController

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        controller.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        controller.anchorView = nsView
    }
}

/// A borderless `NSPanel` refuses key status by default, which silently
/// turned `makeKey()` into a no-op: a search field in a floating panel never
/// received typing and the caret stayed in the window behind. This one can.
private final class ShadcnKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A borderless, non-activating `NSPanel` shown relative to an anchor view,
/// positioned in real screen space so it can never be clipped by an
/// ancestor's AppKit frame — the failure mode a purely in-tree SwiftUI
/// overlay hits once its themed root is a pane smaller than the panel
/// (`ShadcnHostingView` embedded in a larger AppKit layout).
///
/// Generalizes the pattern already proven by `AIConversationMenu`
/// (`NSPopover`), but as a borderless `NSPanel`: shadcn's floating surfaces
/// are flat with their own shadow (`ShadcnPanel`/`shadcnShadow`), and
/// `NSPopover`'s pointing arrow has no public API to suppress.
@MainActor
public final class ShadcnFloatingPanelController: NSObject {
    /// Set by `ShadcnFloatingAnchor` on `makeNSView`/`updateNSView`. Weak: the
    /// anchor view's lifetime is owned by SwiftUI, not this controller.
    /// Public so a caller that already has a real `NSView` in hand (an
    /// `NSViewRepresentable`'s own trigger, e.g. `AIConversationMenu`) can
    /// set this directly, instead of going through `ShadcnFloatingAnchor`.
    public weak var anchorView: NSView?

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var eventMonitor: Any?
    private var previousKeyWindow: NSWindow?
    private var onDismiss: (() -> Void)?

    public var isShown: Bool { panel != nil }

    /// The anchor's bounds converted to screen space (AppKit, y-up), or nil
    /// before the anchor has joined a window.
    var anchorScreenRect: CGRect? {
        guard let anchorView, let window = anchorView.window else { return nil }
        let windowRect = anchorView.convert(anchorView.bounds, to: nil)
        return window.convertToScreen(windowRect)
    }

    /// Shows `content` positioned against the anchor, flipping/shifting to
    /// stay on screen via the same pure placement math the in-tree host uses
    /// (`ShadcnOverlayPlacement.resolved`, converted to AppKit's y-up screen
    /// space — see `ShadcnFloatingPanelController.screenOrigin`).
    ///
    /// - Parameters:
    ///   - contentWidth/contentHeight: Override the panel's measured size.
    ///     Most callers can omit these — `NSHostingView.fittingSize` measures
    ///     `.fixedSize()` shadcn panel content accurately, which is also why
    ///     this bridge needs no `contentHeight:` estimate from the caller the
    ///     way the in-tree host did.
    ///   - makesKey: Menus/selects need keyboard navigation, which requires
    ///     the panel to be key; hover cards/tooltips must not steal key focus
    ///     from the composer, so they pass `false`.
    public func show<Content: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment,
        gap: CGFloat = 4,
        contentWidth: CGFloat? = nil,
        contentHeight: CGFloat? = nil,
        makesKey: Bool = false,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        close()
        guard
            let anchorRect = anchorScreenRect,
            let screen = anchorView?.window?.screen ?? NSScreen.main
        else { return }

        // A floating panel is nearly opaque whatever the pane behind it is
        // set to: bright content bleeding through as grey blocks was worse
        // than losing the glass.
        let hosting = NSHostingView(rootView: AnyView(
            content()
                // Fills inside paint solid (see ShadcnTranslucentFill): glass
                // would blur the transcript behind the panel into smears. The
                // key is read by the fill itself, so a caller re-injecting its
                // own glass/opacity environment inside cannot undo it.
                .environment(\.shadcnFloatingPanelHosted, true)))
        // Unlike `ShadcnHostingView` (which sets `sizingOptions = []` to
        // defer to the caller's Auto Layout constraints), this hosting view
        // has no constraints at all — it's positioned by explicit `setFrame`
        // calls below. Leaving `sizingOptions` at its default lets
        // `fittingSize` actually compute a real answer; with `[]` it stayed
        // stuck at (0, 0), which is what shrank every panel to the 1pt-tall
        // sliver this file exists to fix.
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        // `NSHostingView.fittingSize` is unreliable — often (0, 0) — until
        // the view has actually been through a real window display pass;
        // `layoutSubtreeIfNeeded()` on a detached view doesn't force SwiftUI
        // to compute geometry. So: create the panel and order it on screen
        // at a placeholder size/location first (this *does* force a real
        // pass), measure, then resize/reposition to the real answer. This
        // was the actual cause of "the panel renders as a barely-visible
        // sliver": a mis-measured (0-height) `fittingSize` silently clamped
        // to 1pt tall by the `max(..., 1)` floor below, not a placement or
        // z-order bug.
        let placeholder = CGSize(width: contentWidth ?? 320, height: contentHeight ?? 320)
        hosting.frame = NSRect(origin: .zero, size: placeholder)

        let panel = ShadcnKeyablePanel(
            contentRect: NSRect(origin: anchorRect.origin, size: placeholder),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        // Off-canvas so the placeholder-sized/positioned pass never flashes,
        // but still a real `orderFront` — required to force the layout pass
        // `fittingSize` depends on.
        panel.alphaValue = 0
        panel.orderFront(nil)
        hosting.layoutSubtreeIfNeeded()

        let fitting = hosting.fittingSize
        let width = max(contentWidth ?? fitting.width, 1)
        let height = max(contentHeight ?? fitting.height, 1)
        hosting.frame = NSRect(origin: .zero, size: CGSize(width: width, height: height))

        let origin = Self.screenOrigin(
            anchor: anchorRect, edge: edge, alignment: alignment, gap: gap,
            width: width, height: height, screen: screen.visibleFrame)
        panel.setFrame(NSRect(origin: origin, size: CGSize(width: width, height: height)), display: true)
        panel.alphaValue = 1

        if let parentWindow = anchorView?.window {
            parentWindow.addChildWindow(panel, ordered: .above)
        }
        // `addChildWindow` resets the child's level to the parent's (found
        // empirically while diagnosing this file's `fittingSize` bug: it
        // logged `level=0`, the parent's `.normal`, even though it had just
        // been set to `.popUpMenu`). Reassert after.
        panel.level = .popUpMenu
        panel.orderFront(nil)
        if makesKey {
            previousKeyWindow = NSApp.keyWindow
            // Keyboard events go to the active app. A trigger click already
            // activates it in practice; make it explicit so a panel opened any
            // other way can still take typing.
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
            panel.makeKey()
            // SwiftUI focus (`@FocusState`) only lands once the hosting view
            // is the panel's first responder; `makeKey` alone leaves it nil.
            panel.makeFirstResponder(hosting)
        }

        self.panel = panel
        self.hostingView = hosting
        self.onDismiss = onDismiss
        installEventMonitor()
    }

    /// Swaps the content of an already-open panel — a live model update
    /// (the thread list changing while the panel is open) shouldn't need a
    /// full close/reopen, which would flash and drop focus.
    public func updateContent<Content: View>(@ViewBuilder content: () -> Content) {
        hostingView?.rootView = AnyView(content())
    }

    /// Shows `content` as a full-window panel covering the anchor's own
    /// window — for `shadcnDialog` (U19c), which centers over the host
    /// rather than anchoring to a small trigger. `content` is expected to
    /// draw its own scrim plus a centered box (`ZStack`'s default alignment
    /// does the centering); unlike `show(edge:alignment:...)` this needs no
    /// `fittingSize` measurement pass, since the panel's own size is the
    /// anchor window's frame, known upfront.
    ///
    /// `makesKey` defaults to `true`: a dialog's text field and Escape
    /// shortcut need real keyboard focus, unlike a menu/select/hover card.
    public func showCentered<Content: View>(
        makesKey: Bool = true,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        close()
        guard let anchorWindow = anchorView?.window else { return }

        // A floating panel is nearly opaque whatever the pane behind it is
        // set to: bright content bleeding through as grey blocks was worse
        // than losing the glass.
        let hosting = NSHostingView(rootView: AnyView(
            content()
                // Fills inside paint solid (see ShadcnTranslucentFill): glass
                // would blur the transcript behind the panel into smears. The
                // key is read by the fill itself, so a caller re-injecting its
                // own glass/opacity environment inside cannot undo it.
                .environment(\.shadcnFloatingPanelHosted, true)))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.frame = NSRect(origin: .zero, size: anchorWindow.frame.size)

        let panel = ShadcnKeyablePanel(
            contentRect: anchorWindow.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting

        anchorWindow.addChildWindow(panel, ordered: .above)
        panel.level = .popUpMenu
        panel.orderFront(nil)
        if makesKey {
            previousKeyWindow = NSApp.keyWindow
            // Keyboard events go to the active app. A trigger click already
            // activates it in practice; make it explicit so a panel opened any
            // other way can still take typing.
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
            panel.makeKey()
            // SwiftUI focus (`@FocusState`) only lands once the hosting view
            // is the panel's first responder; `makeKey` alone leaves it nil.
            panel.makeFirstResponder(hosting)
        }

        self.panel = panel
        self.hostingView = hosting
        self.onDismiss = onDismiss
        installEventMonitor()
    }

    /// Repositions an already-open panel — a selection changing the trigger's
    /// label (and therefore its width) shouldn't require a full close/reopen.
    public func reposition(edge: VerticalEdge, alignment: HorizontalAlignment, gap: CGFloat = 4) {
        guard let panel, let anchorRect = anchorScreenRect,
            let screen = anchorView?.window?.screen ?? NSScreen.main
        else { return }
        let size = panel.frame.size
        let origin = Self.screenOrigin(
            anchor: anchorRect, edge: edge, alignment: alignment, gap: gap,
            width: size.width, height: size.height, screen: screen.visibleFrame)
        panel.setFrameOrigin(origin)
    }

    public func close() {
        guard let panel else { return }
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if panel.isKeyWindow, let previousKeyWindow {
            previousKeyWindow.makeKey()
        }
        previousKeyWindow = nil
        anchorView?.window?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
        self.hostingView = nil
        let dismiss = onDismiss
        onDismiss = nil
        dismiss?()
    }

    private func installEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.panel != nil else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { // Escape
                    self.close()
                    return nil
                }
                return event
            }
            if event.window !== self.panel {
                self.close()
            }
            return event
        }
    }

    /// Pure placement math in AppKit's y-up screen space, expressed by
    /// converting to/from the y-down convention `ShadcnOverlayPlacement`
    /// already uses and tests — one conversion boundary rather than a
    /// parallel implementation. `nonisolated`: it touches no actor state, so
    /// tests can call it directly without hopping to the main actor.
    nonisolated static func screenOrigin(
        anchor: CGRect,
        edge: VerticalEdge,
        alignment: HorizontalAlignment,
        gap: CGFloat,
        width: CGFloat,
        height: CGFloat,
        screen: CGRect
    ) -> CGPoint {
        let localAnchor = anchor.offsetBy(dx: -screen.minX, dy: -screen.minY)
        let triggerYDown = CGRect(
            x: localAnchor.minX,
            y: screen.height - localAnchor.maxY,
            width: localAnchor.width,
            height: localAnchor.height)
        let hostYDown = CGSize(width: screen.width, height: screen.height)
        let originYDown = ShadcnOverlayPlacement.resolved(
            trigger: triggerYDown, edge: edge, alignment: alignment, gap: gap,
            contentWidth: width, contentHeight: height, in: hostYDown)
        let localX = originYDown.x
        let localY = screen.height - originYDown.y - height
        return CGPoint(x: localX + screen.minX, y: localY + screen.minY)
    }
}
#endif
