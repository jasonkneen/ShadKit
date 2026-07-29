import SwiftUI

/// A button style that applies nothing at all.
///
/// SwiftUI's own `plain` style still imposes a label colour. Every button in
/// this package colours its own label from the palette, so the style is handed
/// back untouched — keeping the button's semantics and keyboard behaviour
/// without a second colour fighting the themed one.
public struct ShadcnBareButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == ShadcnBareButtonStyle {
    /// Use instead of `.plain` wherever the label carries themed colours.
    public static var shadcnBare: ShadcnBareButtonStyle { ShadcnBareButtonStyle() }
}

/// Radix `Collapsible` — a trigger plus content that expands and collapses.
///
/// This is the workhorse behind AI Elements' `Tool`, `Task`, `Reasoning`,
/// `Sources` and `ChainOfThought`, so it reproduces shadcn's
/// `slide-in-from-top-2` + `fade-in` transition rather than a plain reveal.
public struct ShadcnCollapsible<Trigger: View, Content: View>: View {
    @Binding private var isOpen: Bool
    private let trigger: (Bool) -> Trigger
    private let content: Content
    private let spacing: CGFloat

    public init(
        isOpen: Binding<Bool>,
        spacing: CGFloat = 0,
        @ViewBuilder trigger: @escaping (Bool) -> Trigger,
        @ViewBuilder content: () -> Content
    ) {
        self._isOpen = isOpen
        self.spacing = spacing
        self.trigger = trigger
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: isOpen ? spacing : 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                trigger(isOpen)
            }
            .buttonStyle(.shadcnBare)

            if isOpen {
                content
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: -8).combined(with: .opacity),
                            removal: .offset(y: -8).combined(with: .opacity)
                        )
                    )
            }
        }
        .clipped()
    }
}

/// Uncontrolled variant — owns its own open state, like passing only
/// `defaultOpen` in React.
public struct ShadcnDisclosure<Trigger: View, Content: View>: View {
    @State private var isOpen: Bool
    private let spacing: CGFloat
    private let trigger: (Bool) -> Trigger
    private let content: Content

    public init(
        defaultOpen: Bool = false,
        spacing: CGFloat = 0,
        @ViewBuilder trigger: @escaping (Bool) -> Trigger,
        @ViewBuilder content: () -> Content
    ) {
        self._isOpen = State(initialValue: defaultOpen)
        self.spacing = spacing
        self.trigger = trigger
        self.content = content()
    }

    public var body: some View {
        ShadcnCollapsible(isOpen: $isOpen, spacing: spacing, trigger: trigger) {
            content
        }
    }
}

/// The chevron that rotates 180° when its collapsible opens — shadcn's
/// `group-data-[state=open]:rotate-180`.
public struct ShadcnDisclosureChevron: View {
    private let isOpen: Bool
    private let size: CGFloat

    public init(isOpen: Bool, size: CGFloat = 16) {
        self.isOpen = isOpen
        self.size = size
    }

    public var body: some View {
        ShadcnIconView(ShadcnIcon.chevronDown, size: size)
            .rotationEffect(.degrees(isOpen ? 180 : 0))
            .animation(.easeOut(duration: 0.2), value: isOpen)
    }
}
