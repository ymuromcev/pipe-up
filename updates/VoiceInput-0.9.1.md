
### Added

- Your own way to answer Claude's questions. Besides Claude's options, each question has "Let Claude decide" (Claude picks and says what it chose) and "Your answer" (type it or dictate into it). Skip stops Claude, like Esc in Terminal: the conversation stays, and Claude waits for your next command.
- "Deny and tell Claude what to do instead" under a permission request: type it or say it, and Claude changes course. Deny with the field empty stops Claude, like Esc in Terminal.
- Answers by voice. While a question or a permission request waits in the bubble, open or folded, hold the dictation key with the right ⌘: the recording pill says "Answer for Claude" or "Answer to Claude's request", and your words answer it, added after anything typed in its field. A plain yes ("yes", "go ahead", "да, давай") allows a permission request when nothing is typed in its field; anything else denies it with your words. The bubble then says what happened, naming the request. Where the words go is decided when you press the key: a question that arrives while you speak doesn't catch them, and if nothing waits for them by the time they're recognized, the bubble shows them as not sent instead of starting a task; a permission request that moved to a notification because you closed the bubble still gets them. The tip about this closes for good with its ×.

### Changed

- Claude's questions come one at a time: "Question 1 of 3", Back to see or change an earlier answer, and the answers go to Claude together. Permission requests in a row also come one at a time, in the order Claude asked.
- A question continues Claude's message in one scroll: everything Claude wrote in the turn is there to scroll back to, and a very long turn keeps its end, the words right before the question.
- A question no longer holds the bubble open. It folds into the circle like anything else and stays asked: the circle shows a "?", and a click brings the question back.
- The bubble shows the Pipe Up mark.
- "Working..." shows only while Claude is working on a reply, and its dots move.

### Fixed

- Update, offered when Claude Code is too old, now installs a current copy of Claude Code just for your account with Anthropic's official installer, with no admin password. It used to update the old copy it had found, and when that copy was shared by the whole Mac, the update said it was done, nothing changed, and the button went round in circles.
- On the Claude Code page of the first-launch guide, while the page is getting Claude Code ready (checking it, signing in, updating or installing it), the buttons sit right under the sentence instead of at the bottom of an empty window.
- When Claude Code doesn't start, its own error line ends with a full stop instead of running into the next sentence.
- A subagent's working notes no longer show in the bubble as Claude's words.
- In Russian, Terminal is «Терминал», capitalized, like the app.

