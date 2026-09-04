import SwiftUI

/// Which edge a `shadcnSheet` slides in from.
public enum ShadcnSheetEdge: Sendable {
    case leading
    case trailing
}

/// Radix `Sheet` — a `bg-black/40` scrim behind a fixed-width drawer that
/// slides in from `edge` and pins full-height, matching `ShadcnDialogModifier`'s
/// scrim/panel shape but anchored to a side instead of centered.
struct ShadcnSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let edge: ShadcnSheetEdge
    let width: CGFloat
    let sheetContent: SheetContent

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @FocusState private var focusTrap: Bool

    private var alignment: Alignment { edge == .leading ? .leading : .trailing }
    private var slideEdge: Edge { edge == .leading ? .leading : .trailing }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack(alignment: alignment) {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
                            }

                        panel
                            .transition(.move(edge: slideEdge))

                        // Escape dismisses. A hidden button carrying the
                        // window-level shortcut, not `.onKeyPress`, since
                        // nothing in the scrim itself holds keyboard focus.
                        Button("") {
                            withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
                        }
                        .keyboardShortcut(.cancelAction)
                        .opacity(0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                    .zIndex(1000)
                    .task { focusTrap = true }
                }
            }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetContent
        }
        .frame(width: width, alignment: .topLeading)
        .frame(maxHeight: .infinity)
        .background(
            ShadcnTranslucentFill(color: palette.background, cornerRadius: 0, material: .regularMaterial)
        )
        .overlay(alignment: edge == .leading ? .trailing : .leading) {
            Rectangle().fill(palette.border).frame(width: 1)
        }
        .shadcnShadow(.lg)
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
            } label: {
                Image(systemName: ShadcnIcon.xMark)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.mutedForeground)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                            .fill(Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .padding(Space.x3_5)
            .accessibilityLabel("Close")
        }
        .ignoresSafeArea(edges: .vertical)
        // Initial focus lands in the sheet on presentation, and VoiceOver is
        // told this subtree is modal — matching Radix `Dialog`/`Sheet`'s
        // `aria-modal` and focus-trap behaviour.
        .focusable()
        .focused($focusTrap)
        .accessibilityAddTraits(.isModal)
    }
}

extension View {
    /// Presents a `ShadcnSheet` drawer sliding in from `edge`.
    public func shadcnSheet<Content: View>(
        isPresented: Binding<Bool>,
        edge: ShadcnSheetEdge = .leading,
        width: CGFloat = 320,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(
            ShadcnSheetModifier(
                isPresented: isPresented,
                edge: edge,
                width: width,
                sheetContent: content()
            )
        )
    }
}
