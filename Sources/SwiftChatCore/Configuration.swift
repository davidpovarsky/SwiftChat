import Foundation

public struct ModelType: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let fullName: String
    public let iconName: String
    public let isMultimodal: Bool

    public var modelName: String { id }

    public init(
        id: String,
        displayName: String,
        fullName: String,
        iconName: String = "openai-icon",
        isMultimodal: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.fullName = fullName
        self.iconName = iconName
        self.isMultimodal = isMultimodal
    }
}

public struct SwiftChatConfiguration: Sendable {
    public var models: [ModelType]
    public var defaultModelID: String?
    public var titleModelID: String?
    public var systemPrompt: String
    public var rules: String
    public var selectedLanguage: String
    public var maxPromptMessages: Int
    public var webSearchEnabled: Bool
    public var presentationStyle: SwiftChatPresentationStyle

    public init(
        models: [ModelType] = ModelType.swiftChatDefaults,
        defaultModelID: String? = nil,
        titleModelID: String? = "gpt-4.1-mini",
        systemPrompt: String = "You are a helpful AI assistant.",
        rules: String = "",
        selectedLanguage: String = "System",
        maxPromptMessages: Int = 75,
        webSearchEnabled: Bool = false,
        presentationStyle: SwiftChatPresentationStyle = .embedded
    ) {
        precondition(!models.isEmpty, "SwiftChatConfiguration requires at least one model.")
        self.models = models
        self.defaultModelID = defaultModelID
        self.titleModelID = titleModelID
        self.systemPrompt = systemPrompt
        self.rules = rules
        self.selectedLanguage = selectedLanguage
        self.maxPromptMessages = maxPromptMessages
        self.webSearchEnabled = webSearchEnabled
        self.presentationStyle = presentationStyle
    }

    public var defaultModel: ModelType {
        models.first(where: { $0.id == defaultModelID }) ?? models[0]
    }

    public var titleModel: ModelType? {
        guard let titleModelID else { return nil }
        return models.first(where: { $0.id == titleModelID })
    }
}

public extension ModelType {
    static let swiftChatDefaults: [ModelType] = [
        ModelType(
            id: "gpt-4.1",
            displayName: "GPT-4.1",
            fullName: "GPT-4.1",
            isMultimodal: true
        ),
        ModelType(
            id: "gpt-4.1-mini",
            displayName: "GPT-4.1 Mini",
            fullName: "GPT-4.1 Mini",
            isMultimodal: true
        ),
        ModelType(
            id: "o4-mini",
            displayName: "o4-mini",
            fullName: "o4-mini",
            isMultimodal: true
        ),
    ]
}

public enum SwiftChatPresentationStyle: String, Codable, Hashable, Sendable {
    case embedded
    case inspector
    case sheet
    case fullScreen
}

public struct SwiftChatHostContext: Codable, Hashable, Sendable {
    public var title: String?
    public var subtitle: String?
    public var selectedText: String?
    public var surroundingText: String?
    public var sourceIdentifier: String?
    public var metadata: [String: String]

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        selectedText: String? = nil,
        surroundingText: String? = nil,
        sourceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.selectedText = selectedText
        self.surroundingText = surroundingText
        self.sourceIdentifier = sourceIdentifier
        self.metadata = metadata
    }
}
