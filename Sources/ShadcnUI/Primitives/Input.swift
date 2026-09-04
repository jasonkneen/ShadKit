import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// `h-9 rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-xs`
/// with shadcn's focus ring.
///
/// SwiftUI can't tint a native placeholder, so it's drawn as an overlay — which
/// also gets us `placeholder:text-muted-foreground` for free.
public struct ShadcnTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let onSubmit: (() -> Void)?
    private let onMoveUp: (() -> Void)?
    private let onMoveDown: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    /// Take focus as soon as the field appears (search fields in panels).
    private let autofocus: Bool

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil,
        onSubmit: (() -> Void)? = nil,
        autofocus: Bool = false
    ) {
        self.autofocus = autofocus
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.onSubmit = onSubmit
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(palette.mutedForeground)
                    .allowsHitTesting(false)
            }
            field
        }
        .font(theme.typography.sans(theme.typography.sm))
        .foregroundStyle(palette.foreground)
        .padding(.horizontal, Space.x3)
        .frame(height: 36)
        .background(
            ShadcnTranslucentFill(
                color: palette.isDark ? palette.input : palette.background,
                cornerRadius: theme.radius.md)
        )
        .shadcnBorder(
            isFocused ? palette.ring : palette.input,
            cornerRadius: theme.radius.md
        )
        .shadcnFocusRing(isFocused, palette: palette, cornerRadius: theme.radius.md)
        .shadcnShadow(.xs)
        .opacity(isEnabled ? 1 : 0.5)
        .animation(.easeOut(duration: 0.12), value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear {
            guard autofocus else { return }
            // A field inside a floating panel appears before the panel is key,
            // and focus requested then is dropped; ask again once it is.
            for delay in [0.0, 0.15, 0.4] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { isFocused = true }
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        #if canImport(AppKit)
        ShadcnAppKitTextField(
            placeholder: "",
            text: $text,
            isSecure: isSecure,
            fontSize: theme.typography.sm.size,
            textColor: palette.foreground,
            wantsFocus: isFocused,
            onFocusChange: { isFocused = $0 },
            onSubmit: onSubmit,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown
        )
        #else
        Group {
            if isSecure {
                SecureField("", text: $text)
            } else {
                TextField("", text: $text)
            }
        }
        .textFieldStyle(.plain)
        .focused($isFocused)
        .onSubmit { onSubmit?() }
        .onKeyPress(.upArrow) {
            guard let onMoveUp else { return .ignored }
            onMoveUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard let onMoveDown else { return .ignored }
            onMoveDown()
            return .handled
        }
        #endif
    }
}

/// `min-h-16 rounded-md border border-input px-3 py-2 text-sm shadow-xs`.
///
/// Grows with its content the way `field-sizing-content` does, up to
/// `maxHeight`, then scrolls.
public struct ShadcnTextEditor: View {
    private let placeholder: String
    @Binding private var text: String
    private let minHeight: CGFloat
    private let maxHeight: CGFloat

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    public init(
        _ placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 64,
        maxHeight: CGFloat = 200
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    public var body: some View {
        ShadcnPlainTextEditor(
            text: $text,
            placeholder: placeholder,
            minHeight: minHeight,
            maxHeight: maxHeight,
            focus: $isFocused
        )
        .font(theme.typography.sans(theme.typography.sm))
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x2)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.isDark ? palette.input.opacity(0.3) : Color.clear)
        )
        .shadcnBorder(
            isFocused ? palette.ring : palette.input,
            cornerRadius: theme.radius.md
        )
        .shadcnFocusRing(isFocused, palette: palette, cornerRadius: theme.radius.md)
        .shadcnShadow(.xs)
        .opacity(isEnabled ? 1 : 0.5)
        .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}

/// Bare auto-growing text view. Split out so `ShadcnTextEditor` and
/// `AIPromptInput` can share the growth behaviour without sharing chrome.
///
/// On AppKit, this is a real `NSTextView`. SwiftUI's `TextEditor` inside an
/// `NSHostingView` embedded in an AppKit panel silently drops keystrokes when
/// the hosting view isn't the focus path the system expects — which is exactly
/// how Infinitty (and any similar host) embeds the composer. The representable
/// owns first responder the way a native field does.
public struct ShadcnPlainTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    /// `nil` uses `text-sm`; templates that want `md:text-base` pass it in.
    let font: Font?
    /// AppKit cannot faithfully introspect a SwiftUI `Font`, so carry the
    /// resolved point size alongside it for the native NSTextView path.
    let fontSize: CGFloat?
    /// Focus binding for the editor itself.
    ///
    /// `.focused()` only binds when applied to the focusable view. Applying it
    /// to this container from outside silently does nothing — the editor never
    /// receives keystrokes — so the binding has to come in and be attached
    /// directly to the leaf below.
    var focus: FocusState<Bool>.Binding?
    /// Overrides the palette foreground. Nil keeps the theme colour.
    var textColor: Color?
    /// Return without Shift submits (composer). Shift+Return inserts a newline.
    var onSubmit: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var contentHeight: CGFloat = 0
    @State private var isNativeFocused = false

    public init(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat = 64,
        maxHeight: CGFloat = 200,
        font: Font? = nil,
        fontSize: CGFloat? = nil,
        textColor: Color? = nil,
        focus: FocusState<Bool>.Binding? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.font = font
        self.fontSize = fontSize
        self.textColor = textColor
        self.focus = focus
        self.onSubmit = onSubmit
    }

    private var resolvedFont: Font {
        font ?? theme.typography.sans(theme.typography.sm)
    }

    private var resolvedFontSize: CGFloat {
        fontSize ?? (font == nil ? theme.typography.sm.size : theme.typography.base.size)
    }

    private var resolvedHeight: CGFloat {
        min(max(contentHeight, minHeight), maxHeight)
    }

    private var isFocused: Bool {
        focus?.wrappedValue ?? isNativeFocused
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(resolvedFont)
                    .foregroundStyle(palette.mutedForeground)
                    // Match the NSTextView text inset so the placeholder
                    // doesn't jump when typing starts.
                    .padding(.leading, 5)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }

            editor
                .frame(height: resolvedHeight)
        }
        .frame(height: resolvedHeight)
        .background(heightProbe)
        // No container-level onTapGesture: it steals mouseDown from the
        // NSTextView and typing never lands. Click the editor directly.
    }

    @ViewBuilder
    private var editor: some View {
        #if canImport(AppKit)
        ShadcnAppKitTextView(
            text: $text,
            fontSize: resolvedFontSize,
            textColor: textColor ?? palette.foreground,
            wantsFocus: focus?.wrappedValue ?? isNativeFocused,
            onFocusChange: { focused in
                isNativeFocused = focused
                focus?.wrappedValue = focused
            },
            onSubmit: onSubmit
        )
        #else
        if let focus {
            TextEditor(text: $text)
                .focused(focus)
                .font(resolvedFont)
                .foregroundStyle(textColor ?? palette.foreground)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .scrollDisabled(contentHeight <= maxHeight)
                .onSubmit { onSubmit?() }
        } else {
            TextEditor(text: $text)
                .font(resolvedFont)
                .foregroundStyle(textColor ?? palette.foreground)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .scrollDisabled(contentHeight <= maxHeight)
                .onSubmit { onSubmit?() }
        }
        #endif
    }

    /// Lays the text out off-screen to learn how tall the editor wants to be.
    private var heightProbe: some View {
        Text(text.isEmpty ? " " : text)
            .font(resolvedFont)
            .padding(.horizontal, 5)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ShadcnContentHeightKey.self,
                        value: geometry.size.height
                    )
                }
            )
            .onPreferenceChange(ShadcnContentHeightKey.self) { contentHeight = $0 }
    }
}

private struct ShadcnContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#if canImport(AppKit)
/// Real `NSTextField` so single-line inputs work reliably inside AppKit-hosted
/// SwiftUI settings panels. SwiftUI `TextField` can invalidate AppKit layout
/// while first responder is changing in those hosts.
struct ShadcnAppKitTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let fontSize: CGFloat
    let textColor: Color
    let wantsFocus: Bool
    let onFocusChange: (Bool) -> Void
    let onSubmit: (() -> Void)?
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field: NSTextField = isSecure
            ? ShadcnFocusSecureTextField(string: text)
            : ShadcnFocusTextField(string: text)
        field.placeholderString = placeholder
        field.controlSize = .regular
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.commit(_:))
        field.cell?.sendsActionOnEndEditing = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if let field = field as? ShadcnFocusTextField {
            field.onFocusChange = { [weak coordinator = context.coordinator] focused in
                coordinator?.parent.onFocusChange(focused)
            }
        } else if let field = field as? ShadcnFocusSecureTextField {
            field.onFocusChange = { [weak coordinator = context.coordinator] focused in
                coordinator?.parent.onFocusChange(focused)
            }
        }
        applyChrome(to: field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        applyChrome(to: field)
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        if let field = field as? ShadcnFocusTextField {
            field.onFocusChange = { [weak coordinator = context.coordinator] focused in
                coordinator?.parent.onFocusChange(focused)
            }
        } else if let field = field as? ShadcnFocusSecureTextField {
            field.onFocusChange = { [weak coordinator = context.coordinator] focused in
                coordinator?.parent.onFocusChange(focused)
            }
        }
        guard field.currentEditor() == nil else { return }
        if field.stringValue != text {
            field.stringValue = text
        }
        if wantsFocus, !context.coordinator.focusClaimed {
            context.coordinator.focusClaimed = true
            if field.window != nil, field.window?.firstResponder !== field.currentEditor() {
                DispatchQueue.main.async {
                    field.window?.makeFirstResponder(field)
                }
            }
        } else if !wantsFocus {
            context.coordinator.focusClaimed = false
        }
    }

    private func applyChrome(to field: NSTextField) {
        field.font = NSFont.preferredFont(forTextStyle: .body).withSize(fontSize)
        field.textColor = NSColor(textColor)
        field.backgroundColor = .clear
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ShadcnAppKitTextField
        var focusClaimed = false

        init(_ parent: ShadcnAppKitTextField) { self.parent = parent }

        @objc func commit(_ sender: NSTextField) {
            if parent.text != sender.stringValue {
                parent.text = sender.stringValue
            }
            parent.onSubmit?()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if parent.text != field.stringValue {
                parent.text = field.stringValue
            }
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            // The input method owns navigation while it is composing text.
            guard !textView.hasMarkedText() else { return false }
            let action: (() -> Void)?
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                action = parent.onMoveUp
            case #selector(NSResponder.moveDown(_:)):
                action = parent.onMoveDown
            default:
                return false
            }
            guard let action else { return false }
            action()
            return true
        }
    }
}

final class ShadcnFocusTextField: NSTextField {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }
}

final class ShadcnFocusSecureTextField: NSSecureTextField {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }
}

/// Real `NSTextView` so keystrokes work when this package is hosted inside an
/// AppKit panel via `NSHostingView` — SwiftUI `TextEditor` does not.
struct ShadcnAppKitTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var textColor: Color
    var wantsFocus: Bool
    var onFocusChange: (Bool) -> Void
    /// Return without Shift. Nil keeps default newline behaviour.
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let textView = ShadcnFocusTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 5
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.focusRingType = .none
        textView.string = text
        textView.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.parent.onFocusChange(focused)
        }
        textView.onSubmit = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onSubmit?()
        }

        scroll.documentView = textView
        context.coordinator.textView = textView
        applyChrome(to: textView)
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? ShadcnFocusTextView else { return }
        applyChrome(to: textView)
        textView.onSubmit = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onSubmit?()
        }
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
        // Only claim first responder on the rising edge of wantsFocus. Re-applying
        // every update steals focus back from open selects and other controls.
        if wantsFocus, !context.coordinator.focusClaimed {
            context.coordinator.focusClaimed = true
            if textView.window != nil, textView.window?.firstResponder !== textView {
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }
        } else if !wantsFocus {
            context.coordinator.focusClaimed = false
        }
    }

    private func applyChrome(to textView: NSTextView) {
        textView.font = NSFont.preferredFont(forTextStyle: .body).withSize(fontSize)
        // Resolve the SwiftUI Color against the current appearance so dark
        // panels get a light label colour without relying on environment.
        textView.textColor = NSColor(textColor)
        textView.insertionPointColor = NSColor(textColor)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ShadcnAppKitTextView
        weak var textView: ShadcnFocusTextView?
        /// True after we've claimed first responder for the current wantsFocus
        /// pulse, so updateNSView doesn't fight open menus for focus.
        var focusClaimed = false

        init(_ parent: ShadcnAppKitTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }

        /// Swallow bare Return when submit is wired (composer). Shift+Return
        /// and any Return without a submit handler stay as newlines.
        func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let flags = NSApp.currentEvent?.modifierFlags ?? []
                if flags.contains(.shift) || parent.onSubmit == nil {
                    return false // default: insert newline
                }
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}

/// NSTextView that reports first-responder transitions so SwiftUI focus chrome
/// stays in sync when the user clicks elsewhere.
final class ShadcnFocusTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?
    var onSubmit: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }
}
#endif
