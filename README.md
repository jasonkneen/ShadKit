# ShadKit

A SwiftUI port of [shadcn/ui](https://ui.shadcn.com) and
[Vercel AI Elements](https://ai-sdk.dev/elements), built to match the originals
rather than approximate them. No dependencies — pure SwiftUI, macOS 14+ / iOS 17+.

Components were ported from the actual registry sources
(`ui.shadcn.com/r/styles/new-york-v4/*.json` and `registry.ai-sdk.dev`), not from
screenshots, so class-for-class details — the `has-[>svg]:px-3` padding shift on
buttons, `dark:bg-input/30` on inputs, the ten-spoke loader's per-spoke opacity —
carry across.

## Products

| Library | Contents |
|---|---|
| `ShadcnUI` | Design tokens + the shadcn primitives |
| `AIElementsUI` | The AI Elements set, plus a `useChat`-shaped runtime |
| `CanvasUI` | Node-graph canvas, ReactFlow-shaped |
| `AIElementsGallery` | A browsable showcase of everything |

```swift
.package(url: "https://github.com/jasonkneen/ShadKit", from: "0.3.0")
```

## Design tokens

shadcn publishes its tokens in OKLCH. `OKLCH` converts to sRGB via OKLab, so a
theme can be pasted in verbatim:

```swift
OKLCH(css: "oklch(0.145 0 0)")          // #0A0A0A
OKLCH(0.577, 0.245, 27.325).hexString   // #E7000B
```

Apply a theme once near the root. Components below read the resolved palette for
the current appearance:

```swift
ContentView()
    .shadcnSurface()                 // theme + the `background` token
    .shadcnTheme(myTheme)            // theme only
```

Custom themes are the same shape as a shadcn `:root` block — see
`ShadcnPaletteSpec`. `Space.x4` maps Tailwind's spacing scale to points
(`p-4` → `16`), and `theme.radius` derives the whole radius scale from one
`--radius`.

## AI controls

```swift
AIConversation(streamToken: chat.streamToken) {
    ForEach(chat.messages) { AIMessageView(message: $0) }
}

AIReasoning(content: thinking, isStreaming: true)
AITool(name: "search_codebase", state: .outputAvailable) {
    AIToolInput(json: input)
    AIToolOutput(output: output)
}
AIResponse(markdown)                 // streaming-safe markdown
AICodeBlock(code: swift, language: "swift")
```

## `useChat` parity

`AIChat` is the Swift counterpart to the AI SDK's `useChat` — same message
shape (`UIMessage` / `UIMessagePart`), same `ChatStatus`, same verbs.

```swift
@StateObject private var chat = AIChat(transport: MyTransport())

AIChatbot(chat: chat, suggestions: ["Explain this repo"]) { text, status in
    AIPromptInput(text: text, status: status,
                  onSubmit: { chat.sendMessage() },
                  onStop: { chat.stop() })
}
```

Point it at a backend by conforming to `AIChatTransport`, which yields
`AIChatChunk`s (`.textDelta`, `.reasoningDelta`, `.toolCall`, `.toolResult`,
`.source`, `.finish`). `AIMockChatTransport` replays a canned script for
previews and tests.

Deltas coalesce into a single part as they stream, tool results update their
call in place, and `stop()` keeps whatever already arrived.

## Composer templates

The three provider composers from the AI Elements examples, ported 1:1:

```swift
AIChatGPTComposer(text: $text, suggestions: […], onSubmit: …)   // rounded-[28px] pills
AIClaudeComposer(text: $text, model: $model, models: […], …)     // bg-card, rounded-md
AIGrokComposer(text: $text, model: $model, models: […], …)       // segmented DeepSearch
```

They differ only in `AIPromptInputStyle`, so a fourth is a few lines.

## Gallery

```swift
NSHostingView(rootView: ShadcnAIGallery())
```

Or run it standalone:

```
swift run ShadKitDemo
swift run ShadKitDemo --section glass --scheme dark --opacity 0.45
swift run ShadKitDemo --section aiTemplates --scheme dark
```

`--section glass` is the transparency check: selects, menus, cards, dialogs and
the conversation picker sit on a wallpaper. Toggle **Glass** in the sidebar —
on frosts like a macOS menu, off is a flat fill. **Opacity** is independent.
Default opacity in the standalone demo is `0.45`.

## Notes and limits

- **Syntax highlighting** is a compact tokeniser using Shiki's `one-light` /
  `one-dark-pro` palettes — comments, strings, numbers, keywords and call sites.
  Not a full grammar per language.
- **Markdown** covers the block grammar assistants actually emit (headings,
  lists, fenced code, quotes, rules) and defers inline spans to
  `AttributedString`. Tables aren't rendered.
- **Overlays** (popover, dropdown, select) anchor to their trigger but render at
  the theme root, so stacking order can't hide them. They still can't escape a
  clipping ancestor above the theme root.
- **Canvas** covers pan, zoom, selection, marquee, node drag and custom node
  types. Dragging a handle to create an edge is not built yet, nor are
  sub-flows, `NodeResizer` or undo/redo.

## Tests

`swift test` — 321 tests, no UI harness required.

Coverage is deliberately weighted toward the four places a change looks harmless
in review but breaks something downstream:

| Surface | What's pinned |
|---|---|
| **Hand-transcribed values** | Button sizes/padding against their Tailwind classes, the radius scale deriving from one `--radius`, the type and spacing scales, badge/alert variant counts |
| **Colour space** | `OKLCH` against known shadcn hex, out-of-gamut clamping, hue wrapping, zero-chroma staying achromatic at every hue, every token in all ten shipped palettes |
| **Protocol boundaries** | `AIToolState` raw values (they cross the wire from Claude, ACP and Codex), tool-name extraction, per-provider event shapes |
| **Extension points** | Node registry dispatch and fallback, theme CSS round-trips in OKLCH/HSL/hex, the panel model contract |

Plus the streaming paths only reachable mid-turn: delta coalescing (and *not*
merging reasoning into prose), tool results updating their call in place,
out-of-order results, `stop()` keeping partial text, and an empty stream still
settling so the composer never hangs.

Two invariants worth knowing about, because both were real bugs first:

- Tool cards live outside `messages`, so a host rebuilding its transcript can't
  wipe them.
- `AIResponse` balances unclosed `**` — mid-stream the closing marker simply
  hasn't arrived, and one stray marker would embolden the rest of the message.

## Integration notes

These come out of porting a real AppKit app (a terminal with an embedded
assistant) onto the package. Every one of them cost time to diagnose, so they
are either fixed in the package or documented here.

### Embedding in AppKit

Use `ShadcnHostingView` rather than `NSHostingView` directly:

```swift
let host = ShadcnHostingView(colorScheme: .dark) { MyPanel() }
```

A bare `NSHostingView` reports an intrinsic content size that competes with the
constraints you set, so it collapses to a narrow column or refuses to fill.
`ShadcnHostingView` sets `sizingOptions = []`, applies the theme *inside* the
host, and pins `NSAppearance` so system-drawn chrome matches the palette.

Prefer replacing a **whole panel** over inserting a SwiftUI island into an
existing constraint layout. Mixed layouts are where the sizing surprises live.

### Theme injection and backgrounds

`.background(…)` attached *outside* an environment-injecting modifier reads the
environment from **above** the injection:

```swift
// Wrong — the backdrop gets the default palette and paints a white surface
// under a dark UI.
content.shadcnTheme(theme).background(SomeBackdrop())

// Right — the token resolves in the same place it is injected.
content.shadcnSurface(theme)
```

The symptom is misleading: content renders correctly but near-white text looks
"dimmed" and pure white text vanishes. If brighter text is *less* visible, the
surface is light, not the text dark.

### Overlays and stacking

Popovers, dropdowns and selects draw at the theme root, not inline, so no
ancestor's stacking order can paint over an open panel. This is automatic — but
it means `shadcnTheme(_:)` or `shadcnSurface(_:)` **must** be applied somewhere
above them, or overlays have nowhere to render.

`zIndex` alone cannot fix this: it only orders a view against its immediate
siblings, so any wrapper defeats it.

### Buttons and themed labels

Use `.buttonStyle(.shadcnBare)` rather than `.plain` when a label carries
palette colours. SwiftUI's `plain` style imposes its own label colour, which
resolves against `NSAppearance` rather than `\.colorScheme`.

### Greedy views

`AIResponse` deliberately does not set `maxWidth: .infinity` — that would
stretch a user bubble, which is `w-fit`. Apply the frame yourself where you
want a view to fill.
