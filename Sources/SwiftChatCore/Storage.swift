import Foundation

public protocol SwiftChatConversationStore: Sendable {
    func conversations() async throws -> [Chat]
    func save(_ conversation: Chat) async throws
    func delete(id: Chat.ID) async throws
}

public actor InMemoryConversationStore: SwiftChatConversationStore {
    private var values: [Chat.ID: Chat]

    public init(conversations: [Chat] = []) {
        values = Dictionary(uniqueKeysWithValues: conversations.map { ($0.id, $0) })
    }

    public func conversations() async throws -> [Chat] {
        values.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func save(_ conversation: Chat) async throws {
        values[conversation.id] = conversation
    }

    public func delete(id: Chat.ID) async throws {
        values.removeValue(forKey: id)
    }
}
