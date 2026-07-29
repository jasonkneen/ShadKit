# Recipes

Working snippets for the things that aren't obvious from the type names.
Everything here is exercised by the gallery, so it stays honest.

## A chat surface, end to end

```swift
@StateObject private var chat = AIChat(transport: MyTransport())

AIChatbot(chat: chat, suggestions: ["Explain this repo"]) { text, status in
    AIPromptInput(text: text, status: status,
                  onSubmit: { chat.sendMessage() },
                  onStop:   { chat.stop() })
}
```

`MyTransport` is the only part you write:

```swift
struct MyTransport: AIChatTransport {
    func send(
        messages: [UIMessage], options: AIChatRequestOptions
    ) -> AsyncThrowingStream<AIChatChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for try await token in myBackend.stream(messages) {
                    continuation.yield(.textDelta(token))
                }
                continuation.yield(.finish)
                continuation.finish()
            }
        }
    }
}
```

Deltas coalesce automatically — yield per token, don't batch.

## Tool cards

Yield the call, then the result with the **same id**:

```swift
continuation.yield(.toolCall(
    UIToolPart(id: id, type: "tool-search", state: .inputAvailable, input: json)))
continuation.yield(.toolResult(id: id, output: result, errorText: nil))
```

The result updates the call in place. Omitting the name on the result is
correct — the card keeps the one from the call.

## Driving the panel from AppKit

```swift
let host = ShadcnHostingView(colorScheme: .dark) {
    AIAssistantPanel(model: model)
}
```

Use `ShadcnHostingView`, not `NSHostingView` — it fixes the sizing, theming and
appearance traps in one place. Then feed the model:

```swift
model.messages = transcript.map { UIMessage(role: $0.role, text: $0.text) }
model.streamingText = inFlightAnswer     // renders as a real assistant turn
model.applyTool(id: id, name: name, state: .outputAvailable, output: out)
```

Tools are separate from `messages` on purpose: rebuilding the transcript won't
wipe the cards.

## Bringing a theme

Paste a shadcn or tweakcn `:root` block:

```swift
let theme = ShadcnTheme(
    light: ShadcnPaletteSpec(css: lightBlock, fallback: .neutralLight)!,
    dark:  ShadcnPaletteSpec(css: darkBlock,  fallback: .neutralDark)!)

ContentView().shadcnSurface(theme)
```

OKLCH, HSL and hex all parse. Anything omitted falls back, so a partial theme
still yields a complete palette.

## Custom canvas nodes

```swift
var registry = CanvasNodeRegistry<MyData>()
registry.register("prompt") { PromptNode(node: $0, context: $1) }

struct PromptNode: CanvasNodeView {
    let node: CanvasNode<MyData>
    let context: CanvasNodeContext

    var body: some View {
        CanvasNodeCard(isSelected: context.isSelected) {
            CanvasNodeHeader { CanvasNodeTitle(node.data.title) }
            CanvasNodeContentView {
                ShadcnTextEditor("Prompt…", text: $text)   // stays interactive
            }
        }
    }
}
```

Compose `CanvasNodeCard` to inherit the shadcn chrome and override only what
you need.

## Gotchas

- Apply `shadcnTheme(_:)` or `shadcnSurface(_:)` **above** anything using a
  popover, dropdown or select — that's where overlays render.
- Menus open downward only; a picker near a hosted view's bottom edge can clip.
- `AIResponse` isn't greedy. Add `.frame(maxWidth: .infinity)` where you want it
  to fill; without it a user bubble stays `w-fit`.
- Use `.buttonStyle(.shadcnBare)` for buttons whose labels carry palette colours.
