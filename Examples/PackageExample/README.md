# PackageExample

Open `Package.swift` in Xcode. The example uses the repository root as a local
package dependency and demonstrates:

- `import SwiftChat` with the full package.
- `import SwiftChatCore` plus `import SwiftChatUI` with a mock provider.
- Embedded and inspector presentation.
- A custom theme and host context.
- A host-owned custom tool-result card.
- Real OpenAI composition without a checked-in key. Set `OPENAI_API_KEY` in the
  run scheme and call `makeOpenAISessionFromEnvironment()` from the host.

The example intentionally reuses the package UI. It does not copy the upstream
application.
