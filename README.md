# LaunchControl

LaunchControl is a lightweight macOS SwiftUI app for inspecting launch agents from:

- `~/Library/LaunchAgents`
- `/Library/LaunchAgents`
- `/System/Library/LaunchAgents`

It lets you:

- browse installed launch agents
- see whether each agent appears loaded
- inspect key plist fields
- view the full plist source
- run `start`, `stop`, and `restart` actions through `launchctl`

## Run

```bash
swift run
```

You can also open the folder in Xcode and run the `LaunchControl` package target as a macOS app.

## Notes

- User launch agents can usually be controlled directly.
- Local and system launch agents may require elevated privileges depending on the service and domain.
- The app reads plist files from disk, so it is best suited to agents that are installed in the standard LaunchAgents directories.
