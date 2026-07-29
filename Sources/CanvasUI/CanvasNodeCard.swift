import ShadcnUI
import SwiftUI

/// What a node view is told about its situation.
public struct CanvasNodeContext: Sendable {
    public var isSelected: Bool
    public var isDragging: Bool
    public var zoom: CGFloat

    public init(isSelected: Bool = false, isDragging: Bool = false, zoom: CGFloat = 1) {
        self.isSelected = isSelected
        self.isDragging = isDragging
        self.zoom = zoom
    }
}

/// A view that renders one node.
///
/// Swift has no JSX and `View` can't be subclassed, so extensibility is a
/// protocol plus a registry — the direct analogue of ReactFlow's
/// `nodeTypes={{ custom: MyNode }}`.
public protocol CanvasNodeView: View {
    associatedtype Data
    init(node: CanvasNode<Data>, context: CanvasNodeContext)
}

/// Maps a node's `type` to the view that draws it.
public struct CanvasNodeRegistry<Data> {
    public typealias Builder = (CanvasNode<Data>, CanvasNodeContext) -> AnyView

    private var builders: [String: Builder] = [:]
    private var fallback: Builder?

    public init() {}

    /// ```swift
    /// registry.register("prompt") { PromptNode(node: $0, context: $1) }
    /// ```
    public mutating func register<V: View>(
        _ type: String,
        @ViewBuilder builder: @escaping (CanvasNode<Data>, CanvasNodeContext) -> V
    ) {
        builders[type] = { AnyView(builder($0, $1)) }
    }

    /// Used for any `type` with no registered builder.
    public mutating func registerFallback<V: View>(
        @ViewBuilder builder: @escaping (CanvasNode<Data>, CanvasNodeContext) -> V
    ) {
        fallback = { AnyView(builder($0, $1)) }
    }

    func view(for node: CanvasNode<Data>, context: CanvasNodeContext) -> AnyView {
        if let builder = builders[node.type] { return builder(node, context) }
        if let fallback { return fallback(node, context) }
        return AnyView(EmptyView())
    }
}

/// AI Elements' `node.tsx`: a shadcn `Card` at `w-sm`, `rounded-md p-0`, with
/// `bg-secondary` header and footer separated by rules.
///
/// Compose this in a custom node to inherit the look and override only the
/// parts you care about.
public struct CanvasNodeCard<Content: View>: View {
    private let isSelected: Bool
    private let width: CGFloat?
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        isSelected: Bool = false,
        width: CGFloat? = 320,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.width = width
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .fill(palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                .strokeBorder(
                    isSelected ? palette.ring : palette.border,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous))
        .shadcnShadow(isSelected ? .md : .sm)
    }
}

/// `bg-secondary` header strip with an optional trailing action.
public struct CanvasNodeHeader<Content: View, Action: View>: View {
    private let content: Content
    private let action: Action

    @Environment(\.shadcnPalette) private var palette

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) {
        self.content = content()
        self.action = action()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Space.x2) {
            VStack(alignment: .leading, spacing: 2) { content }
            Spacer(minLength: Space.x2)
            action
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.secondary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border).frame(height: 1)
        }
    }
}

extension CanvasNodeHeader where Action == EmptyView {
    public init(@ViewBuilder content: () -> Content) {
        self.init(content: content, action: { EmptyView() })
    }
}

public struct CanvasNodeTitle: View {
    private let text: String

    @Environment(\.shadcnTheme) private var theme

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.sm, weight: .medium))
            .lineLimit(1)
    }
}

public struct CanvasNodeDescription: View {
    private let text: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(theme.typography.sans(theme.typography.xs))
            .foregroundStyle(palette.mutedForeground)
            .lineLimit(1)
    }
}

/// The node's body. Content here stays fully interactive — a node can host a
/// text field or a whole prompt input.
public struct CanvasNodeContentView<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            content
        }
        .padding(Space.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `bg-secondary` footer, ruled off from the body.
public struct CanvasNodeFooter<Content: View>: View {
    private let content: Content

    @Environment(\.shadcnPalette) private var palette

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Space.x2) { content }
            .padding(.horizontal, Space.x3)
            .padding(.vertical, Space.x2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.secondary)
            .overlay(alignment: .top) {
                Rectangle().fill(palette.border).frame(height: 1)
            }
    }
}

/// The dot drawn at a handle's anchor.
struct CanvasHandleDot: View {
    let handle: CanvasHandle
    let isActive: Bool

    @Environment(\.shadcnPalette) private var palette

    var body: some View {
        Circle()
            .fill(isActive ? palette.primary : palette.background)
            .frame(width: CanvasGeometry.handleSize, height: CanvasGeometry.handleSize)
            .overlay(
                Circle().strokeBorder(
                    isActive ? palette.primary : palette.mutedForeground,
                    lineWidth: 1.5
                )
            )
    }
}
