import Foundation
import Combine
import OpenAI
import SwiftChatCore

public struct OpenAIProviderConfiguration: Sendable {
    public var apiKey: String
    public var host: String
    public var basePath: String

    public init(
        apiKey: String,
        host: String = "api.openai.com",
        basePath: String = "/v1"
    ) {
        self.apiKey = apiKey
        self.host = host
        self.basePath = basePath
    }
}

/// Backwards-compatible configuration used by the original example app.
@MainActor
public final class AppConfig: ObservableObject {
    public static let shared = AppConfig()

    public var apiKey: String = "YOUR_API_KEY"
    public var apiHost: String = "api.openai.com"
    public var apiBasePath: String = "/v1"
    public var systemPrompt: String = "You are a helpful AI assistant."
    public var rules: String = ""
    public var currentModel: ModelType
    public var availableModels: [ModelType]

    public init(models: [ModelType] = ModelType.swiftChatDefaults) {
        precondition(!models.isEmpty, "AppConfig requires at least one model.")
        availableModels = models
        if let savedID = UserDefaults.standard.string(forKey: "selectedModel"),
           let saved = models.first(where: { $0.id == savedID }) {
            currentModel = saved
        } else {
            currentModel = models[0]
        }
    }

    public var titleModel: ModelType? {
        availableModels.first(where: { $0.id == "gpt-4.1-mini" })
            ?? availableModels.first
    }

    public func filteredModelTypes() -> [ModelType] {
        availableModels
    }

    public func provider() -> OpenAIResponsesProvider {
        OpenAIResponsesProvider(
            configuration: OpenAIProviderConfiguration(
                apiKey: apiKey,
                host: apiHost,
                basePath: apiBasePath
            )
        )
    }
}
