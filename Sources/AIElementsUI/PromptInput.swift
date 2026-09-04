import ShadcnUI
import SwiftUI

/// Streaming state of the surrounding chat, driving the submit button's glyph.
/// Mirrors `ChatStatus` from the AI SDK.
public enum AIPromptStatus: String, Sendable, CaseIterable {
    case ready
    case submitted
    case streaming
    case error
}

/// Chrome overrides for the composer.
///
/// The provider templates (ChatGPT, Claude, Grok) differ almost entirely in
/// these values, so they're factored out rather than forked into three copies
/// of the layout.
public struct AIPromptInputStyle: Sendable {
    /// `nil` uses the theme's `rounded-md`.
    public var cornerRadius: CGFloat?
    /// `nil` uses the default transparent / `dark:bg-input/30` fill.
    public var background: Color?
    /// Horizontal inset on the textarea. ChatGPT and Grok use `px-5`.
    public var textFieldHorizontalPadding: CGFloat
    /// Extra trailing room reserved for controls overlaid in the prompt's top-right.
    public var textFieldTrailingAccessoryWidth: CGFloat
    /// When set, replaces the default input/ring border. Used for composer
    /// modes that need a distinct shell (bash `!` is pink).
    public var borderColor: Color?
    /// When set, replaces the textarea foreground colour.
    public var textColor: Color?
    /// `true` renders the textarea at `text-base` rather than `text-sm`.
    public var usesLargeText: Bool
    /// Padding around the footer row. ChatGPT and Grok use `p-2.5`.
    public var footerPadding: CGFloat
    /// Submit button shape.
    public var submitIsCircular: Bool
    /// Resting height of the textarea. `min-h-16` (64) is right for a
    /// full-width page composer but far too tall in a sidebar, where it reads
    /// as a big empty box that then shrinks once content arrives.
    public var minTextHeight: CGFloat
    public var maxTextHeight: CGFloat

    public init(
        cornerRadius: CGFloat? = nil,
        background: Color? = nil,
        textFieldHorizontalPadding: CGFloat = Space.x2,
        textFieldTrailingAccessoryWidth: CGFloat = 0,
        borderColor: Color? = nil,
        textColor: Color? = nil,
        usesLargeText: Bool = false,
        footerPadding: CGFloat = Space.x3,
        submitIsCircular: Bool = false,
        minTextHeight: CGFloat = 64,
        maxTextHeight: CGFloat = 192
    ) {
        self.cornerRadius = cornerRadius
        self.background = background
        self.textFieldHorizontalPadding = textFieldHorizontalPadding
        self.textFieldTrailingAccessoryWidth = textFieldTrailingAccessoryWidth
        self.borderColor = borderColor
        self.textColor = textColor
        self.usesLargeText = usesLargeText
        self.footerPadding = footerPadding
        self.submitIsCircular = submitIsCircular
        self.minTextHeight = minTextHeight
        self.maxTextHeight = maxTextHeight
    }

    /// Sidebar-sized: a single-line resting height and tighter chrome.
    public static let compact = AIPromptInputStyle(
        textFieldHorizontalPadding: Space.x2,
        footerPadding: Space.x2,
        minTextHeight: 34,
        maxTextHeight: 140
    )

    /// The stock AI Elements composer.
    public static let `default` = AIPromptInputStyle()

    /// `rounded-[28px]`, `px-5` textarea, `p-2.5` footer, circular submit.
    public static let pill = AIPromptInputStyle(
        cornerRadius: 28,
        textFieldHorizontalPadding: Space.x5,
        usesLargeText: true,
        footerPadding: Space.x2_5,
        submitIsCircular: true
    )
}

/// A header-slot row of attachment chips for the composer — pass to
/// `AIPromptInput`'s `header:` builder. Renders each item as an
/// ``AIAttachmentChip``: a ~224pt horizontal chip with filename, byte size
/// and upload state, as opposed to ``AIMessageAttachment``'s 96x96 tile
/// (which is for attachments already inline in a *sent* message).
public struct AIPromptInputAttachments: View {
    /// One pending attachment. `id` is the caller's own identifier — the row
    /// only echoes it back on removal.
    ///
    /// Not `Sendable`: `image` is an `Image` and `actions` carries plain
    /// closures, both main-actor UI values. Documented rather than omitted
    /// — see the package's Sendable review.
    public struct Item: Identifiable {
        public let id: String
        public let filename: String
        public let image: Image?
        public let errorText: String?
        public let actions: [AIMessageAttachmentAction]
        /// File size in bytes, shown as the chip's description once
        /// formatted. `nil` renders no description (unless `errorText` is set).
        public let byteSize: Int?
        /// Upload/processing state driving the chip's icon and border.
        /// Defaults to `.done` — existing callers that never set this keep
        /// rendering a finished chip.
        public let state: AIAttachmentChipState

        public init(
            id: String = UUID().uuidString,
            filename: String,
            image: Image? = nil,
            errorText: String? = nil,
            actions: [AIMessageAttachmentAction] = [],
            byteSize: Int? = nil,
            state: AIAttachmentChipState = .done
        ) {
            self.id = id
            self.filename = filename
            self.image = image
            self.errorText = errorText
            self.actions = actions
            self.byteSize = byteSize
            self.state = errorText != nil ? .error : state
        }
    }

    private let items: [Item]
    private let onRemove: (String) -> Void

    public init(items: [Item], onRemove: @escaping (String) -> Void) {
        self.items = items
        self.onRemove = onRemove
    }

    public var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.x2) {
                    ForEach(items) { item in
                        AIAttachmentChip(
                            filename: item.filename,
                            byteSize: item.byteSize,
                            image: item.image,
                            state: item.state,
                            errorText: item.errorText,
                            onRemove: { onRemove(item.id) }
                        )
                    }
                }
                .padding(.bottom, Space.x1)
            }
        }
    }
}

/// A `@mention` or `/slash` trigger wired into the composer. Typing the
/// trigger character opens a `ShadcnCommand` list (wave 1's palette shell —
/// there is no second one here); picking an item replaces the trigger with
/// the item's title.
public struct AIPromptPalette: Sendable {
    public var trigger: Character
    public var groups: [ShadcnCommandGroup]
    public var placeholder: String
    public var emptyText: String

    public init(
        trigger: Character,
        groups: [ShadcnCommandGroup],
        placeholder: String = "Type a command or search...",
        emptyText: String = "No results found."
    ) {
        self.trigger = trigger
        self.groups = groups
        self.placeholder = placeholder
        self.emptyText = emptyText
    }
}

/// How `AIPromptInput` presents an opened `AIPromptPalette`.
public enum AIPromptPalettePresentation: Sendable {
    /// A modal `shadcnCommandDialog`, upper-third placement. Matches 0.3.x.
    case dialog
    /// A list anchored directly above the composer, clamped to
    /// `availableHeight`. Up/down/tab/enter/esc are captured by the list's
    /// own search field the same way they are in `.dialog`; the caller only
    /// needs to leave room above the composer for it to grow into.
    case anchored(availableHeight: CGFloat)
}

/// AI Elements' `PromptInput` — the composer.
///
/// Built on shadcn's `InputGroup`: one `rounded-md border shadow-xs` shell that
/// stacks an optional header, the growing textarea, and a footer holding tools
/// on the left and submit on the right. The whole shell shows the focus ring
/// when the textarea has focus, which is `InputGroup`'s `has-[…:focus-visible]`
/// rule.
public struct AIPromptInput<Header: View, Tools: View, Trailing: View>: View {
    @Binding private var text: String
    private let placeholder: String
    private let status: AIPromptStatus
    private let style: AIPromptInputStyle
    private let onSubmit: () -> Void
    private let onStop: (() -> Void)?
    private let header: Header
    private let tools: Tools
    private let trailing: Trailing
    /// `@mention` / `/slash` triggers. Empty by default — no palette, no
    /// behavior change for existing callers.
    private let palettes: [AIPromptPalette]
    private let onPaletteSelect: ((Character, ShadcnCommandItem) -> Void)?
    private let palettePresentation: AIPromptPalettePresentation

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @FocusState private var isFocused: Bool
    @State private var activePalette: AIPromptPalette?
    /// Character offset of the trigger that opened `activePalette`, tracked
    /// so a later edit can tell "the trigger is still the token under
    /// point" from "the user kept typing past it" without caret access.
    @State private var paletteAnchor: Int?

    public init(
        text: Binding<String>,
        placeholder: String = "What would you like to know?",
        status: AIPromptStatus = .ready,
        style: AIPromptInputStyle = .default,
        palettes: [AIPromptPalette] = [],
        palettePresentation: AIPromptPalettePresentation = .dialog,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        onPaletteSelect: ((Character, ShadcnCommandItem) -> Void)? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder tools: () -> Tools,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self._text = text
        self.placeholder = placeholder
        self.status = status
        self.style = style
        self.palettes = palettes
        self.palettePresentation = palettePresentation
        self.onSubmit = onSubmit
        self.onStop = onStop
        self.onPaletteSelect = onPaletteSelect
        self.header = header()
        self.tools = tools()
        self.trailing = trailing()
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var cornerRadius: CGFloat { style.cornerRadius ?? theme.radius.md }

    private var fill: Color {
        style.background ?? (palette.isDark ? palette.input.opacity(0.3) : .clear)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `align="block-start"`-style header, used for attachment chips.
            // Skip padding when empty so a compact composer doesn't waste a
            // full top inset on `EmptyView` (that was eating popover height).
            if Header.self != EmptyView.self {
                header
                    .padding(.horizontal, style.textFieldHorizontalPadding)
                    .padding(.top, Space.x3)
            }

            ShadcnPlainTextEditor(
                text: $text,
                placeholder: placeholder,
                minHeight: style.minTextHeight,
                maxHeight: style.maxTextHeight,
                font: style.usesLargeText
                    ? theme.typography.sans(theme.typography.base)
                    : nil,
                fontSize: style.usesLargeText
                    ? theme.typography.base.size
                    : theme.typography.sm.size,
                textColor: style.textColor,
                focus: $isFocused,
                // Enter submits; Shift+Enter inserts a newline (composer UX).
                onSubmit: {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else { return }
                    onSubmit()
                }
            )
            .padding(.leading, style.textFieldHorizontalPadding)
            .padding(
                .trailing,
                style.textFieldHorizontalPadding + style.textFieldTrailingAccessoryWidth
            )
            .padding(.top, Space.x2)

            // `align="block-end"`: tools left, submit right.
            HStack(spacing: Space.x1) {
                HStack(spacing: Space.x2) {
                    tools
                }
                Spacer(minLength: Space.x2)
                HStack(spacing: Space.x2) {
                    trailing
                    submitButton
                }
            }
            .padding(style.footerPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
        )
        .shadcnBorder(
            style.borderColor ?? (isFocused ? palette.ring : palette.input),
            width: style.borderColor == nil ? 1 : 2,
            cornerRadius: cornerRadius
        )
        .applyIf(style.borderColor == nil) { view in
            view.shadcnFocusRing(
                isFocused, palette: palette, cornerRadius: cornerRadius)
        }
        .shadcnShadow(.xs)
        .animation(.easeOut(duration: 0.12), value: isFocused)
        // Do NOT put `.onTapGesture` on this container: on AppKit it steals the
        // mouse-down from the NSTextView inside and the composer never focuses.
        // Focus is driven by the editor itself (and by programmatic FocusState).
        .onChange(of: text) { _, newValue in updateActivePalette(for: newValue) }
        .applyIf(isDialogPresentation) { view in
            view.shadcnCommandDialog(
                isPresented: isPaletteDialogPresented,
                groups: activePalette?.groups ?? [],
                placeholder: activePalette?.placeholder ?? "Type a command or search...",
                emptyText: activePalette?.emptyText ?? "No results found.",
                onSelect: { handlePaletteSelect($0) }
            )
        }
        .overlay(alignment: .top) {
            if !isDialogPresentation, let activePalette,
               case let .anchored(availableHeight) = palettePresentation {
                ShadcnCommand(
                    groups: activePalette.groups,
                    placeholder: activePalette.placeholder,
                    emptyText: activePalette.emptyText,
                    onEscape: { dismissPalette(restoreFocus: true) },
                    onSelect: { handlePaletteSelect($0) }
                )
                .frame(maxHeight: max(0, availableHeight))
                .shadcnBorder(palette.border, cornerRadius: theme.radius.xl)
                .shadcnShadow(.lg)
                // Anchors the palette's bottom edge to the composer's top
                // edge: the top-alignment guide reports its own height, so
                // the layout system shifts the whole view up by exactly
                // that much rather than down into the composer.
                .alignmentGuide(.top) { dimensions in dimensions.height + Space.x2 }
                .transition(.opacity)
            }
        }
    }

    private var isDialogPresentation: Bool {
        if case .dialog = palettePresentation { return true }
        return false
    }

    private var isPaletteDialogPresented: Binding<Bool> {
        Binding(
            get: { activePalette != nil },
            set: { isPresented in if !isPresented { dismissPalette(restoreFocus: true) } }
        )
    }

    /// A trailing trigger character (`@`/`/`) opens its palette, but only
    /// when it starts a token — the first character of the text, or
    /// preceded by whitespace — so an email or a path segment doesn't fire
    /// it. Once open, typing whitespace after the trigger, or the trigger no
    /// longer being where it was anchored (e.g. deleted), closes it — the
    /// behaviour the doc comment on `AIPromptPalette` promises.
    private func updateActivePalette(for value: String) {
        if let anchor = paletteAnchor, let trigger = activePalette?.trigger {
            guard anchor < value.count else { dismissPalette(restoreFocus: false); return }
            let anchorIndex = value.index(value.startIndex, offsetBy: anchor)
            guard value[anchorIndex] == trigger else {
                dismissPalette(restoreFocus: false)
                return
            }
            let afterTrigger = value[value.index(after: anchorIndex)...]
            if afterTrigger.contains(where: { $0.isWhitespace }) {
                dismissPalette(restoreFocus: false)
            }
            return
        }

        guard let last = value.last, let matched = palettes.first(where: { $0.trigger == last })
        else { return }

        let precededByWhitespace: Bool
        if value.count == 1 {
            precededByWhitespace = true
        } else {
            let beforeIndex = value.index(value.endIndex, offsetBy: -2)
            precededByWhitespace = value[beforeIndex].isWhitespace
        }
        guard precededByWhitespace else { return }

        activePalette = matched
        paletteAnchor = value.count - 1
    }

    private func handlePaletteSelect(_ item: ShadcnCommandItem) {
        guard let trigger = activePalette?.trigger, let anchor = paletteAnchor,
            anchor <= text.count
        else { return }
        let anchorIndex = text.index(text.startIndex, offsetBy: anchor)
        // Keep everything up to and including the trigger; replace whatever
        // was typed after it with the chosen item's insertion text.
        let insertion = item.insertion ?? item.title
        text.replaceSubrange(text.index(after: anchorIndex)..., with: insertion + " ")
        onPaletteSelect?(trigger, item)
        dismissPalette(restoreFocus: true)
    }

    private func dismissPalette(restoreFocus: Bool) {
        activePalette = nil
        paletteAnchor = nil
        guard restoreFocus else { return }
        // The dialog just released first responder; hop a beat so AppKit
        // finishes tearing it down before the composer reclaims focus.
        DispatchQueue.main.async {
            isFocused = true
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        let shaped = { (view: AnyView) -> AnyView in
            style.submitIsCircular ? AnyView(view.clipShape(Circle())) : view
        }

        switch status {
        case .streaming:
            // Streaming turns submit into a stop control.
            shaped(AnyView(
                ShadcnButton(icon: ShadcnIcon.square, variant: .primary, size: .iconSM) {
                    onStop?()
                }
                .accessibilityLabel("Stop")
            ))

        case .submitted:
            shaped(AnyView(
                ShadcnButton(variant: .primary, size: .iconSM, hasIcon: true, action: {}) {
                    AILoader(size: 16)
                }
                .disabled(true)
                .accessibilityLabel("Submitting")
            ))

        case .error:
            shaped(AnyView(
                ShadcnButton(icon: ShadcnIcon.xMark, variant: .destructive, size: .iconSM) {
                    onSubmit()
                }
                .accessibilityLabel("Retry")
            ))

        case .ready:
            shaped(AnyView(
                ShadcnButton(icon: AIPromptIcon.submit, variant: .primary, size: .iconSM) {
                    guard canSubmit else { return }
                    onSubmit()
                }
                .disabled(!canSubmit)
                .accessibilityLabel("Submit")
            ))
        }
    }
}

extension AIPromptInput where Trailing == EmptyView {
    public init(
        text: Binding<String>,
        placeholder: String = "What would you like to know?",
        status: AIPromptStatus = .ready,
        style: AIPromptInputStyle = .default,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder tools: () -> Tools
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            status: status,
            style: style,
            onSubmit: onSubmit,
            onStop: onStop,
            header: header,
            tools: tools,
            trailing: { EmptyView() }
        )
    }
}

extension AIPromptInput where Header == EmptyView {
    /// Tools on the left, extra controls beside submit on the right.
    public init(
        text: Binding<String>,
        placeholder: String = "What would you like to know?",
        status: AIPromptStatus = .ready,
        style: AIPromptInputStyle = .default,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        @ViewBuilder tools: () -> Tools,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            status: status,
            style: style,
            onSubmit: onSubmit,
            onStop: onStop,
            header: { EmptyView() },
            tools: tools,
            trailing: trailing
        )
    }
}

extension AIPromptInput where Header == EmptyView, Trailing == EmptyView {
    public init(
        text: Binding<String>,
        placeholder: String = "What would you like to know?",
        status: AIPromptStatus = .ready,
        style: AIPromptInputStyle = .default,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        @ViewBuilder tools: () -> Tools
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            status: status,
            style: style,
            onSubmit: onSubmit,
            onStop: onStop,
            header: { EmptyView() },
            tools: tools,
            trailing: { EmptyView() }
        )
    }
}

extension AIPromptInput where Header == EmptyView, Tools == EmptyView, Trailing == EmptyView {
    public init(
        text: Binding<String>,
        placeholder: String = "What would you like to know?",
        status: AIPromptStatus = .ready,
        style: AIPromptInputStyle = .default,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            status: status,
            style: style,
            onSubmit: onSubmit,
            onStop: onStop,
            header: { EmptyView() },
            tools: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

/// Glyphs specific to the composer.
public enum AIPromptIcon {
    /// `CornerDownLeftIcon` — the return-key arrow on the submit button.
    public static let submit = "arrow.turn.down.left"
}

/// `PromptInputButton` — a ghost `icon-sm` tool button for the composer footer.
public struct AIPromptInputButton: View {
    private let systemImage: String
    private let title: String?
    private let tooltip: String?
    private let isActive: Bool
    private let action: () -> Void

    public init(
        systemImage: String,
        title: String? = nil,
        tooltip: String? = nil,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.tooltip = tooltip
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Group {
            if let title {
                ShadcnButton(
                    title,
                    systemImage: systemImage,
                    variant: isActive ? .secondary : .ghost,
                    size: .small,
                    action: action
                )
            } else {
                ShadcnButton(
                    icon: systemImage,
                    variant: isActive ? .secondary : .ghost,
                    size: .iconSM,
                    action: action
                )
            }
        }
        .applyIf(tooltip != nil) { view in
            view.shadcnTooltip(tooltip ?? "")
        }
    }
}

/// `PromptInputModelSelect` — the model picker that sits in the composer's
/// tool row.
public struct AIPromptInputModelSelect<Value: Hashable>: View {
    @Binding private var selection: Value?
    private let models: [(value: Value, label: String)]

    public init(selection: Binding<Value?>, models: [(value: Value, label: String)]) {
        self._selection = selection
        self.models = models
    }

    public var body: some View {
        ShadcnSelect("Select model", selection: $selection, width: 180, options: models)
    }
}
