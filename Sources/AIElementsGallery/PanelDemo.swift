import AIElementsUI
import ShadcnUI
import SwiftUI

/// The assistant panel at the size it runs in Infinitty's sidebar, so layout
/// problems show up here rather than after installing.
struct PanelDemo: View {
    @StateObject private var idle = PanelDemo.makeModel(populated: false)
    @StateObject private var live = PanelDemo.makeModel(populated: true)

    var body: some View {
        GalleryHeading(
            title: "Assistant panel",
            subtitle: "The whole surface — transcript, queue and composer — at sidebar width."
        )

        HStack(alignment: .top, spacing: Space.x6) {
            GalleryBlock("Empty") {
                AIAssistantPanel(model: idle)
                    .frame(width: 340, height: 520)
                    .shadcnBorderedBox()
            }
            GalleryBlock("With a conversation") {
                AIAssistantPanel(model: live)
                    .frame(width: 380, height: 520)
                    .shadcnBorderedBox()
            }
        }
    }

    static func makeModel(populated: Bool) -> AIAssistantPanelModel {
        let model = AIAssistantPanelModel()
        model.models = [
            (value: "opus", label: "Claude Opus 5"),
            (value: "sonnet", label: "Claude Sonnet 5"),
        ]
        model.efforts = [
            (value: "auto", label: "Auto"),
            (value: "high", label: "High"),
        ]
        model.model = "opus"
        model.effort = "auto"
        guard populated else { return model }

        model.messages = [
            UIMessage(role: .user, text: "Which file does the OKLCH conversion live in?"),
            UIMessage(
                role: .assistant,
                parts: [
                    .reasoning("Searching for the conversion, then confirming the matrices.", duration: 3),
                    .tool(
                        UIToolPart(
                            id: "t1", type: "tool-search_codebase", state: .outputAvailable,
                            input: "{\n  \"query\": \"OKLCH\"\n}",
                            output: "{\n  \"file\": \"OKLCH.swift\",\n  \"matches\": 3\n}")),
                    .text(
                        """
                        It's in `Sources/ShadcnUI/Theme/OKLCH.swift`.

                        ```swift
                        let background = OKLCH(0.145, 0, 0)
                        ```
                        """),
                ]),
        ]
        model.streamingText = "Want me to walk through the matrices"
        model.isThinking = true
        model.queued = ["Then check the dark palette"]
        return model
    }
}
