
### Changed

- The bubble scrolls back through the whole conversation, not just the last question and the last answer. Everything said in it since Claude Code started is there, one turn under another, and scrolling up goes as far back as the app has seen. A new answer still brings the panel down to the newest turn, which stands at the top of it the way it always did. A conversation that was already going when the app started begins its history here.
- "Stop" stands next to the message it stops, beside the "Working…" line, instead of taking the place of "Open in Terminal" at the foot of the panel. "Open in Terminal" keeps its own place and is simply out of reach while a turn is going, as it was before.

### Fixed

- "Open in Terminal" no longer does nothing without a word. The button either hands the conversation over, or says why it cannot — the turn is still going, there is nothing said yet, or the conversation was started in another folder — and writes the reason down where it can be read afterwards. A Terminal that refuses to start is written down too, which it never was.
- The bubble's panel opens over a full-screen app again. After the macOS 27 update it could stay behind on the ordinary desktop: the circle was there over the full-screen app, and pointing at it or clicking it showed nothing. A panel that is open when you switch desktops and is missing from the new one now comes up there by itself.
- The bubble no longer travels across the screen when you switch desktops. It is simply in its place on the desktop you switched to — beside the Dock, or at the edge of the screen over a full-screen app. Within one desktop nothing changed.
- Pressing ⌘ while the first-run guide waits for a dictation key no longer looks like a key that did not register. The page says why ⌘ cannot be that key, and goes on waiting for another one. The Settings window said this already.
- The first-run guide no longer greets the sample text with "Done". When the recognition model isn't ready yet and a sample lands in the practice field, the line above it says so: "The model isn't ready yet — your text will land the same way as this sample".
- When Claude Code turns down the first-run guide's practice command because it isn't signed in, the page says what happened and what to do: "Claude Code wouldn't take the request without sign-in — sign in, then click Try Again". It used to show the same line as a page nobody had tried yet.
- When Claude's usage limit runs out and Claude Code doesn't say when it's back, the bubble speaks the language of the interface: "What you say meanwhile waits — press Send when the limit is back." It used to show Claude Code's own English line, on a Russian screen too.
- A permission request with a long list of sites names whole sites and says how many more there are — "…, mirror4.registry.example.com and 10 more sites" — instead of cutting a domain in half around a number in brackets.
- A table in Claude's answer is drawn as a table in the bubble, not as lines of bars and dashes: columns lined up, the header row on its own shade, bold and code inside cells as elsewhere, numbers set to the right when Claude sets them so. In the narrow panel long cells wrap without breaking a word in two; a table too wide even for that scrolls sideways on its own, and the rest of the answer stays in place. Copying the answer still copies it as Claude wrote it.

