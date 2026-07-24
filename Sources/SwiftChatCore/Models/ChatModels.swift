//
//  ChatModels.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//


import Foundation

/// Represents a chat conversation
public struct Chat: Identifiable, Codable, Sendable {
    public enum TitleState: String, Codable, Sendable {
        case placeholder
        case generated
        case manual
    }

    public static let placeholderTitle = "Untitled"

    public let id: String
    public var title: String
    public var titleState: TitleState
    public var messages: [Message]
    public var hasActiveStream: Bool = false
    public var createdAt: Date
    public var modelType: ModelType
    public var language: String?

    // Computed properties
    public var isBlankChat: Bool {
        return messages.isEmpty
    }

    public var needsGeneratedTitle: Bool {
        return titleState == .placeholder
    }

    /// Generates a permanent reverse-timestamp ID locally.
    /// Format: {reverseTimestamp padded to 13 digits}_{UUID}
    public static func generateReverseId(timestampMs: Int = Int(Date().timeIntervalSince1970 * 1000)) -> String {
        let maxReverseTimestamp = 9999999999999
        let reverseTimestamp = maxReverseTimestamp - timestampMs
        let unpadded = String(reverseTimestamp)
        let digits = String(maxReverseTimestamp).count
        let reverseTsStr = String(repeating: "0", count: max(0, digits - unpadded.count)) + unpadded
        return "\(reverseTsStr)_\(UUID().uuidString.lowercased())"
    }

    public static func deriveTitleState(for title: String, messages: [Message]) -> TitleState {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if messages.isEmpty {
            return normalizedTitle.isEmpty || normalizedTitle == placeholderTitle ? .placeholder : .manual
        }
        if normalizedTitle.isEmpty || normalizedTitle == placeholderTitle {
            return .placeholder
        }
        return .generated
    }

    public init(
        id: String = Chat.generateReverseId(),
        title: String = Chat.placeholderTitle,
        titleState: TitleState? = nil,
        messages: [Message] = [],
        createdAt: Date = Date(),
        modelType: ModelType,
        language: String? = nil)
    {
        let resolvedTitleState = titleState ?? Chat.deriveTitleState(for: title, messages: messages)

        self.id = id
        self.title = title
        self.titleState = resolvedTitleState
        self.messages = messages
        self.createdAt = createdAt
        self.modelType = modelType
        self.language = language
    }

    // MARK: - Factory Methods

    /// Creates a new chat using an explicit or default package model.
    public static func create(
        id: String = Chat.generateReverseId(),
        title: String = Chat.placeholderTitle,
        titleState: TitleState? = nil,
        messages: [Message] = [],
        createdAt: Date = Date(),
        modelType: ModelType = ModelType.swiftChatDefaults[0],
        language: String? = nil
    ) -> Chat {
        return Chat(
            id: id,
            title: title,
            titleState: titleState,
            messages: messages,
            createdAt: createdAt,
            modelType: modelType,
            language: language
        )
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, title, titleState, messages, createdAt, modelType, language
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        messages = try container.decode([Message].self, forKey: .messages)
        titleState = (try? container.decode(TitleState.self, forKey: .titleState)) ?? Chat.deriveTitleState(for: title, messages: messages)
        // hasActiveStream is transient UI state — always reset to false on decode
        hasActiveStream = false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modelType = try container.decode(ModelType.self, forKey: .modelType)
        language = try container.decodeIfPresent(String.self, forKey: .language)
    }

}

/// Represents a message role
public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

// MARK: - Web Search Types

/// Represents a source from web search results
public struct WebSearchSource: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let url: String

    public init(id: String = UUID().uuidString.lowercased(), title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(String.self, forKey: .url)
    }
}

/// Status of a web search operation
public enum WebSearchStatus: String, Codable, Equatable, Sendable {
    case searching
    case completed
    case failed
    case blocked
}

/// State of web search for a message
public struct WebSearchState: Codable, Equatable, Sendable {
    public var query: String?
    public var status: WebSearchStatus
    public var sources: [WebSearchSource]
    public var reason: String?

    public init(
        query: String? = nil,
        status: WebSearchStatus = .searching,
        sources: [WebSearchSource] = [],
        reason: String? = nil
    ) {
        self.query = query
        self.status = status
        self.sources = sources
        self.reason = reason
    }
}

// MARK: - URL Fetch Types

/// Status of a URL fetch operation
public enum URLFetchStatus: String, Codable, Equatable, Sendable {
    case fetching
    case completed
    case failed
    case blocked
}

/// Tracks the state of a single URL being fetched during web search
public struct URLFetchState: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let url: String
    public var status: URLFetchStatus

    public init(id: String = UUID().uuidString.lowercased(), url: String, status: URLFetchStatus = .fetching) {
        self.id = id
        self.url = url
        self.status = status
    }
}

/// URL citation from web search results
public struct URLCitation: Codable, Equatable, Sendable {
    public let title: String
    public let url: String
    public let start_index: Int?
    public let end_index: Int?

    public init(title: String, url: String, startIndex: Int? = nil, endIndex: Int? = nil) {
        self.title = title
        self.url = url
        self.start_index = startIndex
        self.end_index = endIndex
    }
}

/// Annotation wrapper for URL citations
public struct Annotation: Codable, Equatable, Sendable {
    public let type: String
    public let url_citation: URLCitation

    public init(type: String = "url_citation", urlCitation: URLCitation) {
        self.type = type
        self.url_citation = urlCitation
    }
}

/// Represents a single message in a chat
public struct Message: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let role: MessageRole
    public var content: String
    public var thoughts: String? = nil
    public var isThinking: Bool = false
    public var timestamp: Date
    public var isCollapsed: Bool = true
    public var isStreaming: Bool = false
    public var streamError: String? = nil
    public var isRequestError: Bool = false
    public var generationTimeSeconds: Double? = nil
    public var contentChunks: [ContentChunk] = []
    public var thinkingChunks: [ThinkingChunk] = []
    public var webSearchState: WebSearchState? = nil
    public var urlFetches: [URLFetchState] = []
    public var attachments: [Attachment] = []

    // Passthrough fields for cross-platform round-trip
    public var annotations: [Annotation]? = nil

    public static let longMessageAttachmentThreshold = 1200
    public var shouldDisplayAsAttachment: Bool {
        role == .user && content.count >= Message.longMessageAttachmentThreshold
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public init(id: String = UUID().uuidString.lowercased(), role: MessageRole, content: String, thoughts: String? = nil, isThinking: Bool = false, timestamp: Date = Date(), isCollapsed: Bool = true, generationTimeSeconds: Double? = nil, contentChunks: [ContentChunk] = [], thinkingChunks: [ThinkingChunk] = [], webSearchState: WebSearchState? = nil, attachments: [Attachment] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.thoughts = thoughts
        self.isThinking = isThinking
        self.timestamp = timestamp
        self.isCollapsed = isCollapsed
        self.generationTimeSeconds = generationTimeSeconds
        self.contentChunks = contentChunks
        self.thinkingChunks = thinkingChunks
        self.webSearchState = webSearchState
        self.attachments = attachments
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, role, content, thoughts, isThinking, timestamp, isCollapsed, isStreaming, streamError, isRequestError, generationTimeSeconds, webSearchState
        case webSearch // Alternative key used by React app
        case urlFetches
        case attachments
        case annotations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        thoughts = try container.decodeIfPresent(String.self, forKey: .thoughts)
        isThinking = try container.decodeIfPresent(Bool.self, forKey: .isThinking) ?? false

        // Handle timestamp as either Date or String (ISO8601)
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else if let dateString = try? container.decode(String.self, forKey: .timestamp) {
            timestamp = Self.iso8601Formatter.date(from: dateString)
                ?? Self.iso8601FormatterNoFractional.date(from: dateString)
                ?? Date()
        } else {
            timestamp = Date()
        }

        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? true
        isStreaming = try container.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false
        streamError = try container.decodeIfPresent(String.self, forKey: .streamError)
        isRequestError = try container.decodeIfPresent(Bool.self, forKey: .isRequestError) ?? false
        generationTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .generationTimeSeconds)
        contentChunks = []
        thinkingChunks = []
        webSearchState = try container.decodeIfPresent(WebSearchState.self, forKey: .webSearchState)
            ?? container.decodeIfPresent(WebSearchState.self, forKey: .webSearch)
        urlFetches = try container.decodeIfPresent([URLFetchState].self, forKey: .urlFetches) ?? []
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        annotations = try container.decodeIfPresent([Annotation].self, forKey: .annotations)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role.rawValue, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(thoughts, forKey: .thoughts)
        try container.encode(isThinking, forKey: .isThinking)
        try container.encode(Self.iso8601Formatter.string(from: timestamp), forKey: .timestamp)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(isStreaming, forKey: .isStreaming)
        try container.encodeIfPresent(streamError, forKey: .streamError)
        if isRequestError { try container.encode(isRequestError, forKey: .isRequestError) }
        try container.encodeIfPresent(generationTimeSeconds, forKey: .generationTimeSeconds)
        try container.encodeIfPresent(webSearchState, forKey: .webSearch)
        if !urlFetches.isEmpty {
            try container.encode(urlFetches, forKey: .urlFetches)
        }
        if !attachments.isEmpty {
            try container.encode(attachments, forKey: .attachments)
        }
        try container.encodeIfPresent(annotations, forKey: .annotations)
    }
}

