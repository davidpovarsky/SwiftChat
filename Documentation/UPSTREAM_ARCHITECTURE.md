# SwiftChat upstream architecture

This document records the upstream repository at the package-conversion baseline
`d6f54ccf9e84d2fec672b7b89d5a67dd6ee0f957` before any source relocation or
modularization.

## Repository tree

```text
SwiftChat/
├── README.md
├── SwiftChat.xcodeproj/
│   ├── project.pbxproj
│   └── project.xcworkspace/
│       └── xcshareddata/swiftpm/Package.resolved
├── SwiftChat/
│   ├── SwiftChatApp.swift
│   ├── ContentView.swift
│   ├── Assets.xcassets/
│   │   ├── AccentColor.colorset/
│   │   ├── AppIcon.appiconset/
│   │   ├── LaunchColor.colorset/
│   │   └── openai-icon.imageset/
│   ├── swift-chat.icon/
│   ├── Config/
│   │   ├── AppConfig.swift
│   │   ├── Constants.swift
│   │   ├── SettingsManager.swift
│   │   └── Theme.swift
│   ├── Extensions/
│   │   ├── Color.swift
│   │   └── Color+Hex.swift
│   ├── Models/
│   │   ├── AttachmentModels.swift
│   │   └── ChatModels.swift
│   ├── Services/
│   │   ├── AudioRecordingService.swift
│   │   ├── StreamingMarkdownChunker.swift
│   │   ├── ThinkingSummaryService.swift
│   │   └── ThinkingTextChunker.swift
│   ├── Utilities/
│   │   ├── ChatQueryBuilder.swift
│   │   └── NetworkMonitor.swift
│   ├── ViewModels/
│   │   └── ChatViewModel.swift
│   └── Views/
│       ├── AttachmentPreviewBar.swift
│       ├── CameraPickerView.swift
│       ├── ChatListView.swift
│       ├── ChatSidebar.swift
│       ├── ChatView.swift
│       ├── DocumentPickerView.swift
│       ├── LaTeXMarkdownView.swift
│       ├── MessageAttachmentIndicator.swift
│       ├── MessageInputView.swift
│       ├── MessageTableView.swift
│       ├── MessageView.swift
│       ├── URLFetchBox.swift
│       └── WebSearchBox.swift
├── SwiftChatTests/
│   └── SwiftChatTests.swift
└── SwiftChatUITests/
    ├── SwiftChatUITests.swift
    └── SwiftChatUITestsLaunchTests.swift
```

The upstream tree does not contain a `LICENSE` file even though the README
declares the project to be MIT licensed.

## Existing Xcode targets

| Target | Kind | Source root | Purpose |
| --- | --- | --- | --- |
| `SwiftChat` | iOS application | `SwiftChat/` synchronized group | Complete upstream application |
| `SwiftChatTests` | unit-test bundle | `SwiftChatTests/` synchronized group | Placeholder Swift Testing target |
| `SwiftChatUITests` | UI-test bundle | `SwiftChatUITests/` synchronized group | Launch/performance smoke tests |

The project uses Xcode file-system-synchronized root groups. The application
target currently compiles every supported source found under `SwiftChat/`.
There are no entitlements, checked-in Info.plist, preview source files,
localization catalogs, or submodules. Xcode generates the Info.plist.

Important build settings:

- iOS deployment target: 18.0.
- Swift language version: 5.0.
- Generated Info.plist with microphone usage text.
- iPhone and iPad orientations are configured.
- Application bundle identifier: `com.3s.SwiftChat`.
- The project contains macOS deployment settings inherited from Xcode's
  generated project, but the sources use UIKit throughout and are iOS-only.

## External dependencies

| Dependency | Requirement at baseline | Product | Purpose |
| --- | --- | --- | --- |
| `https://github.com/tinfoilsh/openai-swift-fork.git` | `0.0.4..<1.0.0` | `OpenAI` | Responses API, streamed response events, web-search events, audio transcription |
| `https://github.com/tinfoilsh/textual` | branch `main`, resolved at `9f58137` | `Textual` | SwiftUI Markdown and rich-text rendering |
| `https://github.com/mgriebling/SwiftMath` | `1.7.3..<2.0.0` | `SwiftMath` | Native LaTeX rendering |

The resolved transitive dependencies are `swift-concurrency-extras`,
`swift-http-types`, `swift-openapi-runtime`, and `swiftui-math`.

## Swift source inventory

| Source | Category | Responsibility and coupling |
| --- | --- | --- |
| `SwiftChat/SwiftChatApp.swift` | Application shell | `@main` entry point; app-target-only |
| `SwiftChat/ContentView.swift` | Application shell | Creates `ChatViewModel`, prompts for an API key, writes the key to `UserDefaults`, and embeds `ChatContainer` |
| `SwiftChat/Config/AppConfig.swift` | Provider/network configuration | Defines model metadata and global OpenAI-compatible host/key/model configuration; directly constructs `OpenAI` |
| `SwiftChat/Config/Constants.swift` | Shared utility | Rendering, streaming, context, title, attachment, and audio constants |
| `SwiftChat/Config/SettingsManager.swift` | Persistence/UI configuration | Global observable settings persisted through `UserDefaults` |
| `SwiftChat/Config/Theme.swift` | UI | Internal semantic color, dimension, and animation tokens |
| `SwiftChat/Extensions/Color.swift` | UI | UIKit-backed adaptive color palette |
| `SwiftChat/Extensions/Color+Hex.swift` | UI | SwiftUI `Color` hex initializer |
| `SwiftChat/Models/AttachmentModels.swift` | Core model | Codable image/document metadata and transient processing state; imports UIKit unnecessarily |
| `SwiftChat/Models/ChatModels.swift` | Core model plus platform service | Conversation, message, reasoning chunks, search/citation/fetch state; also contains UIKit haptic behavior and a global `AppConfig` factory dependency |
| `SwiftChat/Services/AudioRecordingService.swift` | Platform service plus provider | Microphone permissions, AVAudioSession recording, temporary-file lifecycle, and direct OpenAI Whisper transcription |
| `SwiftChat/Services/StreamingMarkdownChunker.swift` | Core model/utility | Incremental semantic Markdown chunk reduction |
| `SwiftChat/Services/ThinkingSummaryService.swift` | UI state utility | Throttled tail-text reasoning summary |
| `SwiftChat/Services/ThinkingTextChunker.swift` | Core model/utility | Incremental reasoning paragraph reduction |
| `SwiftChat/Utilities/ChatQueryBuilder.swift` | Provider/network | Converts messages, document context, image data, and web-search settings to OpenAI Responses API types |
| `SwiftChat/Utilities/NetworkMonitor.swift` | Platform service | `NWPathMonitor` exposed as observable UI state |
| `SwiftChat/ViewModels/ChatViewModel.swift` | UI controller plus provider/network | Owns chats, selection, attachments, image processing, streaming, reasoning, citations, search state, retry/cancel, model changes, and title generation; directly imports OpenAI/OpenAPIRuntime and uses UIKit application/background-task APIs |
| `SwiftChat/Views/AttachmentPreviewBar.swift` | UI | Pending attachment previews and processing/error states |
| `SwiftChat/Views/CameraPickerView.swift` | UI/platform | UIKit camera picker wrapper |
| `SwiftChat/Views/ChatListView.swift` | UI | Message list, scroll-to-bottom behavior, and iPad padding |
| `SwiftChat/Views/ChatSidebar.swift` | UI | Conversation navigation, rename, delete, and selection |
| `SwiftChat/Views/ChatView.swift` | UI/application presentation | Main adaptive container, sidebar, lifecycle handling, toolbars, and empty state |
| `SwiftChat/Views/DocumentPickerView.swift` | UI/platform | UIDocumentPicker wrapper and supported content types |
| `SwiftChat/Views/LaTeXMarkdownView.swift` | UI/rendering | Segmentation, Textual Markdown, syntax highlighting, tables, inline/block LaTeX, render caching, and memory-pressure handling |
| `SwiftChat/Views/MessageAttachmentIndicator.swift` | UI/rendering | Document/image chips, thumbnails, full-screen paging, and zoom |
| `SwiftChat/Views/MessageInputView.swift` | UI/platform/provider | Composer, photo/document/camera inputs, web-search toggle, model picker, audio recording, and direct OpenAI transcription call |
| `SwiftChat/Views/MessageTableView.swift` | UI/platform | UITableView-backed high-performance message list and streaming height management |
| `SwiftChat/Views/MessageView.swift` | UI/rendering | User/assistant messages, actions, reasoning, Markdown chunks, error/retry, citations, selection, raw content, and long-message attachments |
| `SwiftChat/Views/URLFetchBox.swift` | UI | URL fetch state and external URL opening |
| `SwiftChat/Views/WebSearchBox.swift` | UI | Search progress, sources, favicons, and external URL opening |

## Existing feature map

- Responses API text streaming: implemented in `ChatViewModel`.
- Reasoning streaming and collapsible reasoning UI: implemented.
- Web-search status and source citations: implemented.
- Incremental Markdown, fenced code, syntax highlighting, tables, and LaTeX:
  implemented.
- Images: photo library, camera, resizing/compression, thumbnails, model input,
  gallery, and zoom are implemented.
- Documents: picker and UTF-8 text-context injection are implemented. The
  advertised PDF support is not backed by PDF text extraction; binary PDFs
  fail the current UTF-8 loader.
- Voice: AVFoundation recording and OpenAI Whisper transcription are
  implemented.
- Conversation history: multiple conversations, sidebar, rename, delete, and
  selection are implemented in memory. No durable conversation store exists.
- Automatic titles and model selection: implemented.
- iPhone/iPad and light/dark presentation: implemented.
- Generic custom tool calls/cards: not implemented upstream.
- Keychain storage: not implemented upstream. The example app stores the API
  key in `UserDefaults`.

## Current dependency graph

```text
SwiftChatApp
  └── ContentView
      └── ChatContainer and all Views
          └── ChatViewModel
              ├── Chat/Message/Attachment models
              ├── AppConfig and SettingsManager singletons
              ├── OpenAI + OpenAPIRuntime
              ├── ChatQueryBuilder
              ├── Markdown/reasoning chunkers
              ├── NetworkMonitor
              └── UIKit/AVFoundation platform services

Rendering views
  ├── Textual
  ├── SwiftMath
  └── UIKit
```

This graph prevents a UI-only consumer because the UI controller and composer
construct and use the OpenAI client directly.

## Packaging assessment

### Can move without behavioral changes

- `AttachmentModels.swift` after removing its unused UIKit import.
- The data portions of `ChatModels.swift`.
- `StreamingMarkdownChunker.swift`.
- `ThinkingTextChunker.swift`.
- Most view and rendering files after adding module imports and the access
  control needed by the public root API.
- The color/theme implementation and most UI constants.

### Access-control-only changes

The intended public surface requires public declarations and initializers for
the root view, session/controller, configuration, model metadata, conversation
and message models, provider protocol/events, storage protocol, host context,
theme, attachment types, and presentation style. Rendering helpers and
implementation-only subviews remain internal.

### Requires dependency isolation

- `AppConfig.swift`: split provider-neutral model/configuration data from the
  OpenAI client factory.
- `ChatModels.swift`: remove the global `AppConfig` factory dependency and
  UIKit haptic implementation from the core model layer.
- `AudioRecordingService.swift`: retain recording in UI/platform code and move
  transcription behind a provider-neutral protocol implemented by OpenAI.
- `ChatQueryBuilder.swift`: belongs wholly in the OpenAI adapter.
- `ChatViewModel.swift`: preserve the original controller and reduction logic,
  but inject provider, store, configuration, host context, and presentation
  behavior instead of reading OpenAI/global app singletons.
- `MessageInputView.swift`: invoke the session's transcription provider instead
  of constructing an OpenAI client.
- `ChatView.swift`: expose an embeddable root without requiring the host to
  provide a hidden environment object; keep the original full-screen container
  behavior as the default.

### App-target-only files

- `SwiftChat/SwiftChatApp.swift`.
- `SwiftChat/ContentView.swift`.
- App icon and launch assets under `SwiftChat/`.

The app shell will become a thin composition root that imports the local
package, creates an `OpenAIResponsesProvider`, and displays the package's
original UI implementation.

## Bundle and resource audit

No Swift source uses `Bundle.main`. The only named non-system image reference
is `Image(model.iconName)`, whose default value is `openai-icon`. That asset
must be placed in `SwiftChatUI` resources and loaded from `Bundle.module`
through a package resource helper. App icon and launch assets remain in the
application target.

No localizations, prompt files, fonts, templates, sample content, or secrets
are checked in.

## Platform and global-state audit

Direct `UIApplication`/UIKit coupling exists in:

- `ChatViewModel.swift` (keyboard dismissal, background tasks, image processing,
  haptics).
- `ChatView.swift` (lifecycle notifications, scene/window lookup, keyboard).
- `ChatListView.swift`, `MessageTableView.swift` (device idiom and UIKit list).
- `LaTeXMarkdownView.swift` (UIKit renderer and memory warning).
- `MessageView.swift`, `URLFetchBox.swift`, `WebSearchBox.swift` (URL opening).
- Camera, attachment, and composer views.
- `Color.swift`.

Global environment-object coupling exists in `ChatView`, `MessageView`, and
`MessageAttachmentIndicator`; child views also accept the same view model
explicitly. The package root must install its session/controller environment
object itself.

Global singleton coupling exists in `AppConfig`, `SettingsManager`,
`ThinkingSummaryService`, and through `UserDefaults`.

## Target design for conversion

```text
SwiftChatCore
  provider-neutral models, events, protocols, store, configuration, context

SwiftChatUI
  ├── depends on SwiftChatCore
  ├── original ChatViewModel adapted to injected protocols
  ├── original Views and rendering
  ├── recording/platform helpers
  ├── Textual
  └── SwiftMath

SwiftChatOpenAI
  ├── depends on SwiftChatCore
  ├── OpenAI Responses provider
  ├── OpenAI query mapping
  ├── stream-event mapping
  └── Whisper transcription

SwiftChat
  re-exports SwiftChatCore, SwiftChatUI, and SwiftChatOpenAI
```

The app target will contain only its composition root and app-only resources.
Every shared implementation will have one canonical path under `Sources/` and
will be compiled by SwiftPM, not separately by the app target.

## Upstream merge risks

1. Moving synchronized source directories means upstream changes to the old
   paths will appear as delete/add conflicts. Git rename detection and a drift
   script are required.
2. `ChatViewModel.swift` is both the largest file and the most likely conflict
   point because provider injection touches the streaming loop.
3. `AppConfig.swift`, `ChatModels.swift`, `AudioRecordingService.swift`, and
   `MessageInputView.swift` cross the new target boundaries and are additional
   high-risk files.
4. The Xcode project uses a synchronized group. Keeping package sources outside
   `SwiftChat/` prevents duplicate app compilation, but the project must add a
   local package reference and product dependency explicitly.
5. Xcode and `Package.swift` dependency requirements can drift. The conversion
   should make the local package the single dependency owner for the shared
   code.
6. The upstream README claims MIT while omitting the license text. Attribution
   and the standard MIT text must be recorded without changing the declared
   license.

