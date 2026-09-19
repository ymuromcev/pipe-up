
VoiceInput is now **Pipe Up**. It's the same app under a new name, and the update installs as usual: your settings, dictation key, downloaded speech model and permissions stay as they were.

### Added

- Tasks for Claude Code. Hold the right ⌘ together with the dictation key and say what you need done. The task goes to the Claude Code already installed and signed in on your Mac, and the answer appears in a small bubble over whatever window you're in. If Claude Code asks for permission, you answer in the bubble. It's off until you turn it on in the first-launch guide or in Settings, and it needs Claude Code on a paid Claude plan or API access. Dictation works without it.
- English works right away. You can dictate in English as soon as the app is installed: macOS's own speech engine handles it while the speech model downloads in the background, and the model takes over once it's ready. Other languages start once the model has downloaded.
- Dictation limit. A single dictation stops at 10 minutes by default, and you can set it from 3 to 30 minutes in Settings → Dictation. What you said up to the limit is still transcribed.
- Esc closes the menu.

### Changed

- A new icon for the app and the menu bar.
- macOS 26 or later is required. Macs on older versions aren't offered this update and stay on VoiceInput 0.8.3.
- Speech model settings moved into Settings → Dictation, under Recognition.

### Fixed

- A recording now stops when the Mac goes to sleep, the screen locks or a system password prompt appears, instead of leaving the microphone on. What you said up to then is still transcribed, and the recording pill says why it stopped.
- The first press of the dictation key after the Mac has been idle or asleep works; it used to take a few tries.
- Changing the dictation language takes effect right away instead of after a restart.

