import Foundation

public struct SwiftChatToolCall: Identifiable, Codable, Hashable, Sendable {
    public enum State: String, Codable, Hashable, Sendable {
        case pending
        case running
        case success
        case failure
        case permissionRequired
    }

    public let id: String
    public let name: String
    public let arguments: String
    public var state: State

    public init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        arguments: String,
        state: State = .pending
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.state = state
    }
}

public struct SwiftChatToolResult: Codable, Hashable, Sendable {
    public let callID: String
    public let content: String
    public let isError: Bool

    public init(callID: String, content: String, isError: Bool = false) {
        self.callID = callID
        self.content = content
        self.isError = isError
    }
}

public protocol SwiftChatToolExecutor: Sendable {
    func execute(_ call: SwiftChatToolCall) async throws -> SwiftChatToolResult
}
