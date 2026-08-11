# OPE Game Catalog App

SwiftUI client for the OpenPhysicsEngine game inventory hosted on this site.

- Fetches the master list from `https://theothegooddog.github.io/ope/api/games`
  (entries look like `(Default Game/Default Game for OPE/1)`).
- Scripts are resolved flat by build index: `https://theothegooddog.github.io/ope/api/1.py`.

## Files

| File | Purpose |
| --- | --- |
| `GameFetchService.swift` | `GameItem` model + network layer (inventory list and per-game script download) |
| `GameCatalogViewModel.swift` | Catalog state, loading/error handling, sort order |
| `ContentView.swift` | Sidebar + catalog list, navigation, card rows, yellow `JoinButton` |
| `GameDetailView.swift` | Dedicated page per game: join button, copy/open/reload actions, script source viewer |

Drop these files into an iOS 17+ SwiftUI app target in Xcode and set `ContentView` as the root view.
