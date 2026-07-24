//
//  ContentView.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI
import SwiftChat

struct ContentView: View {
    @State private var session: SwiftChatSession?
    @State private var showAPIKeyPrompt = false
    @State private var apiKeyInput = ""

    private var needsAPIKey: Bool {
        let key = AppConfig.shared.apiKey
        return key.isEmpty || key == "YOUR_API_KEY"
    }

    var body: some View {
        Group {
            if let session {
                SwiftChatView(session: session)
            } else {
                ProgressView("Configuring SwiftChat…")
            }
        }
            .onAppear {
                if let saved = UserDefaults.standard.string(forKey: "apiKey"), !saved.isEmpty {
                    AppConfig.shared.apiKey = saved
                    session = makeSession()
                } else if needsAPIKey {
                    showAPIKeyPrompt = true
                } else {
                    session = makeSession()
                }
            }
            .alert("API Key Required", isPresented: $showAPIKeyPrompt) {
                TextField("Paste your API key", text: $apiKeyInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save") {
                    let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    AppConfig.shared.apiKey = trimmed
                    UserDefaults.standard.set(trimmed, forKey: "apiKey")
                    session = makeSession()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your API key to start chatting.")
            }
    }

    private func makeSession() -> SwiftChatSession {
        let appConfig = AppConfig.shared
        let configuration = SwiftChatConfiguration(
            models: appConfig.availableModels,
            defaultModelID: appConfig.currentModel.id,
            titleModelID: appConfig.titleModel?.id,
            systemPrompt: appConfig.systemPrompt,
            rules: appConfig.rules,
            webSearchEnabled: UserDefaults.standard.bool(forKey: "webSearchEnabled")
        )
        let provider = appConfig.provider()
        return SwiftChatSession(
            provider: provider,
            configuration: configuration,
            transcriptionProvider: provider
        )
    }
}
