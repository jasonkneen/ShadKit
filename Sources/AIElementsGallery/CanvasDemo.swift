import AIElementsUI
import CanvasUI
import ShadcnUI
import SwiftUI

/// What the demo's nodes carry. Any type works — the canvas only needs
/// position, size and handles.
struct WorkflowNodeData {
    var title: String
    var subtitle: String
    var status: AIToolState?
    var body: String?
}

struct CanvasDemo: View {
    @State private var graph = CanvasDemo.sampleGraph()

    private var registry: CanvasNodeRegistry<WorkflowNodeData> {
        var registry = CanvasNodeRegistry<WorkflowNodeData>()
        registry.register("prompt") { PromptWorkflowNode(node: $0, context: $1) }
        registry.register("tool") { ToolWorkflowNode(node: $0, context: $1) }
        registry.registerFallback { node, context in
            CanvasNodeCard(isSelected: context.isSelected) {
                CanvasNodeHeader {
                    CanvasNodeTitle(node.data.title)
                    CanvasNodeDescription(node.data.subtitle)
                }
            }
        }
        return registry
    }

    var body: some View {
        GalleryHeading(
            title: "Canvas",
            subtitle: "Native node graph — scroll to pan, pinch to zoom, drag to select or move."
        )

        GalleryBlock("Workflow") {
            CanvasView(graph: $graph, registry: registry)
                .frame(height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    static func sampleGraph() -> CanvasGraph<WorkflowNodeData> {
        CanvasGraph(
            nodes: [
                CanvasNode(
                    id: "in",
                    type: "prompt",
                    position: CGPoint(x: 0, y: 40),
                    data: WorkflowNodeData(
                        title: "Prompt",
                        subtitle: "user input",
                        status: nil,
                        body: "Summarise the OKLCH conversion."
                    ),
                    handles: [CanvasHandle(id: "source", kind: .source, position: .right)]
                ),
                CanvasNode(
                    id: "search",
                    type: "tool",
                    position: CGPoint(x: 420, y: 0),
                    data: WorkflowNodeData(
                        title: "search_codebase",
                        subtitle: "tool call",
                        status: .outputAvailable,
                        body: nil
                    )
                ),
                CanvasNode(
                    id: "read",
                    type: "tool",
                    position: CGPoint(x: 420, y: 190),
                    data: WorkflowNodeData(
                        title: "read_file",
                        subtitle: "tool call",
                        status: .inputAvailable,
                        body: nil
                    )
                ),
                CanvasNode(
                    id: "out",
                    type: "prompt",
                    position: CGPoint(x: 840, y: 95),
                    data: WorkflowNodeData(
                        title: "Response",
                        subtitle: "assistant",
                        status: nil,
                        body: "Three matrix multiplies and a gamma step."
                    ),
                    handles: [CanvasHandle(id: "target", kind: .target, position: .left)]
                ),
            ],
            edges: [
                CanvasEdge(id: "e1", source: "in", target: "search"),
                CanvasEdge(id: "e2", source: "in", target: "read"),
                CanvasEdge(id: "e3", source: "search", target: "out"),
                CanvasEdge(id: "e4", source: "read", target: "out", type: "temporary"),
            ]
        )
    }
}

/// A custom node: composes `CanvasNodeCard` so it inherits the shadcn look, and
/// overrides only its content — which stays fully interactive.
private struct PromptWorkflowNode: CanvasNodeView {
    let node: CanvasNode<WorkflowNodeData>
    let context: CanvasNodeContext

    @State private var text: String = ""

    init(node: CanvasNode<WorkflowNodeData>, context: CanvasNodeContext) {
        self.node = node
        self.context = context
        self._text = State(initialValue: node.data.body ?? "")
    }

    var body: some View {
        CanvasNodeCard(isSelected: context.isSelected) {
            CanvasNodeHeader {
                CanvasNodeTitle(node.data.title)
                CanvasNodeDescription(node.data.subtitle)
            } action: {
                ShadcnButton(icon: ShadcnIcon.dotsHorizontal, variant: .ghost, size: .iconXS) {}
            }
            CanvasNodeContentView {
                ShadcnTextEditor("Prompt…", text: $text, minHeight: 56, maxHeight: 96)
            }
            CanvasNodeFooter {
                ShadcnBadge("ready", variant: .secondary)
            }
        }
    }
}

private struct ToolWorkflowNode: CanvasNodeView {
    let node: CanvasNode<WorkflowNodeData>
    let context: CanvasNodeContext

    init(node: CanvasNode<WorkflowNodeData>, context: CanvasNodeContext) {
        self.node = node
        self.context = context
    }

    var body: some View {
        CanvasNodeCard(isSelected: context.isSelected, width: 280) {
            CanvasNodeHeader {
                CanvasNodeTitle(node.data.title)
                CanvasNodeDescription(node.data.subtitle)
            } action: {
                ShadcnIconView(ShadcnIcon.wrench, size: 14)
            }
            CanvasNodeContentView {
                if let status = node.data.status {
                    if let tint = status.iconTint {
                        ShadcnBadge(
                            status.label, systemImage: status.systemImage,
                            iconTint: tint, variant: .secondary)
                    } else {
                        ShadcnBadge(
                            status.label, systemImage: status.systemImage, variant: .secondary)
                    }
                }
            }
        }
    }
}
