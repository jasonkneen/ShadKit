import SwiftUI

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

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.onSubmit = onSubmit
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(palette.mutedForeground)
                    .allowsHitTesting(false)
            }
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
        }
        .font(theme.typography.sans(theme.typography.sm))
        .foregroundStyle(palette.foreground)
        .padding(.horizontal, Space.x3)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                // dark:bg-input/30
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
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
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
            maxHeight: maxHeight
        )
        .focused($isFocused)
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
public struct ShadcnPlainTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    /// `nil` uses `text-sm`; templates that want `md:text-base` pass it in.
    let font: Font?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var contentHeight: CGFloat = 0

    public init(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat = 64,
        maxHeight: CGFloat = 200,
        font: Font? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.font = font
    }

    private var resolvedFont: Font {
        font ?? theme.typography.sans(theme.typography.sm)
    }

    private var resolvedHeight: CGFloat {
        min(max(contentHeight, minHeight), maxHeight)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(resolvedFont)
                    .foregroundStyle(palette.mutedForeground)
                    // TextEditor insets its text by ~5pt; match it so the
                    // placeholder doesn't jump when typing starts.
                    .padding(.leading, 5)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(resolvedFont)
                .foregroundStyle(palette.foreground)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .frame(height: resolvedHeight)
                .scrollDisabled(contentHeight <= maxHeight)
        }
        .frame(height: resolvedHeight)
        .background(heightProbe)
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
