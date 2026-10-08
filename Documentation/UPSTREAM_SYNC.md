# Updating from upstream

Upstream is `https://github.com/sachaservan/SwiftChat.git`. The package
conversion baseline is tag
`upstream-baseline-package-conversion-20260724` at
`d6f54ccf9e84d2fec672b7b89d5a67dd6ee0f957`.

## Sync procedure

```powershell
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
git switch codex/package-swiftchat-ui-complete-20260724
git merge main
.\Scripts\check-upstream-drift.ps1
```

Do not force-push, rewrite upstream history, or copy an updated source into both
the old and package paths.

## Canonical path map

| Upstream path | Package path |
| --- | --- |
| `SwiftChat/Models/*.swift` | `Sources/SwiftChatCore/Models/` |
| `SwiftChat/Services/StreamingMarkdownChunker.swift` | `Sources/SwiftChatCore/Services/` |
| `SwiftChat/Services/ThinkingTextChunker.swift` | `Sources/SwiftChatCore/Services/` |
| `SwiftChat/Views/*.swift` | `Sources/SwiftChatUI/Views/` |
| `SwiftChat/ViewModels/ChatViewModel.swift` | `Sources/SwiftChatUI/ViewModels/ChatViewModel.swift` |
| `SwiftChat/Config/Constants.swift` | `Sources/SwiftChatUI/Config/Constants.swift` |
| `SwiftChat/Config/SettingsManager.swift` | `Sources/SwiftChatUI/Config/SettingsManager.swift` |
| `SwiftChat/Config/Theme.swift` | `Sources/SwiftChatUI/Config/Theme.swift` |
| `SwiftChat/Extensions/*.swift` | `Sources/SwiftChatUI/Extensions/` |
| `SwiftChat/Services/AudioRecordingService.swift` | `Sources/SwiftChatUI/Services/AudioRecordingService.swift` |
| `SwiftChat/Services/ThinkingSummaryService.swift` | `Sources/SwiftChatUI/Services/ThinkingSummaryService.swift` |
| `SwiftChat/Utilities/NetworkMonitor.swift` | `Sources/SwiftChatUI/Utilities/NetworkMonitor.swift` |
| `SwiftChat/Config/AppConfig.swift` | `Sources/SwiftChatOpenAI/AppConfig.swift` |
| `SwiftChat/Utilities/ChatQueryBuilder.swift` | `Sources/SwiftChatOpenAI/ChatQueryBuilder.swift` |
| `SwiftChat/Assets.xcassets/openai-icon.imageset` | `Sources/SwiftChatUI/Resources/SwiftChatUI.xcassets/` |

`SwiftChat/SwiftChatApp.swift`, `SwiftChat/ContentView.swift`, app icons, launch
assets, and the icon-composer source remain in the app target.

## Files changed for package boundaries

- Core model files: public integration access, removal of UIKit/global config.
- `ChatViewModel.swift`: injected provider/store/configuration/context and
  provider-neutral stream events.
- `AudioRecordingService.swift` and `MessageInputView.swift`: injected
  transcription instead of constructing OpenAI.
- `AppConfig.swift` and `ChatQueryBuilder.swift`: OpenAI adapter ownership.
- `ChatView.swift` and related views: module imports and package root wiring.
- `MessageInputView.swift`: package-resource bundle for the OpenAI icon.
- `ContentView.swift`: composition root consuming the local package.

New adapters and facades live outside the upstream map:

- `Sources/SwiftChatCore/{Configuration,Provider,Storage,Tooling}.swift`.
- `Sources/SwiftChatUI/SwiftChatView.swift`.
- `Sources/SwiftChatOpenAI/OpenAIResponsesProvider.swift`.
- `Sources/SwiftChat/Exports.swift`.

## Resolving a ChatView conflict

1. Keep the package path as canonical.
2. Compare the upstream `SwiftChat/Views/ChatView.swift` version with
   `Sources/SwiftChatUI/Views/ChatView.swift`.
3. Apply upstream UI behavior to the package file.
4. Preserve the injected `ChatViewModel` environment object and the public
   `SwiftChatView` wrapper.
5. Remove the temporary old-path copy after the merge.
6. Run the drift script and both package/app builds.

Use the same process for `ChatViewModel.swift`, while retaining provider-neutral
events and dependency injection around upstream's reduction logic.

## Duplicate-source verification

The app synchronized group is rooted only at `SwiftChat/`. Shared source is
under `Sources/`, so Xcode cannot compile it directly into the app target. The
app links the local `SwiftChatCore`, `SwiftChatUI`, and `SwiftChatOpenAI`
package products. This avoids a build-target name collision while the public
umbrella product remains named `SwiftChat`. The drift script rejects
re-created old source directories, duplicate Swift filenames, duplicate
resources, and a missing local package reference.

The OpenAI fork is intentionally pinned to exact version `0.0.4`. Later
`0.0.x` releases changed generated Responses API types incompatibly despite
remaining in the same semantic-versioning minor line.

## Regression comparison

After every sync:

1. Build and run the original app target.
2. Exercise streaming, reasoning, web search/citations, Markdown/code/LaTeX,
   images, documents, voice, history, titles, model selection, iPhone, and iPad.
3. Run the package example in embedded and inspector modes.
4. Compare the UI with the baseline screenshots in the upstream README.
5. Run package tests and the CI workflow.
