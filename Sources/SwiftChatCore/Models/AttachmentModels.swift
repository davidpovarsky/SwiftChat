//
//  AttachmentModels.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation

public enum AttachmentType: String, Codable, Equatable, Sendable {
    case document
    case image
}

public enum AttachmentProcessingState: String, Codable, Equatable, Sendable {
    case pending
    case processing
    case completed
    case failed
}

public struct Attachment: Identifiable, Equatable, Sendable {
    public let id: String
    public let type: AttachmentType
    public let fileName: String
    public var mimeType: String?
    public var base64: String?
    public var thumbnailBase64: String?
    public var textContent: String?
    public var description: String?
    public var fileSize: Int64
    // v1 format: per-attachment AES-256 key as standard base64 (32 raw bytes → 44 chars).
    // Cross-platform contract: iOS uses Data.base64EncodedString(), React uses btoa().
    // The encrypted blob (nonce || ciphertext || tag) is stored separately at /api/storage/attachment/:id.
    public var encryptionKey: String?
    public var processingState: AttachmentProcessingState

    public init(
        id: String = UUID().uuidString.lowercased(),
        type: AttachmentType,
        fileName: String,
        mimeType: String? = nil,
        base64: String? = nil,
        thumbnailBase64: String? = nil,
        textContent: String? = nil,
        description: String? = nil,
        fileSize: Int64 = 0,
        encryptionKey: String? = nil,
        processingState: AttachmentProcessingState = .pending
    ) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.mimeType = mimeType
        self.base64 = base64
        self.thumbnailBase64 = thumbnailBase64
        self.textContent = textContent
        self.description = description
        self.fileSize = fileSize
        self.encryptionKey = encryptionKey
        self.processingState = processingState
    }
}

// MARK: - Codable (exclude transient UI state from serialization)

extension Attachment: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, fileName, mimeType, base64, thumbnailBase64
        case textContent, description, fileSize
        case encryptionKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        type = try container.decode(AttachmentType.self, forKey: .type)
        fileName = try container.decode(String.self, forKey: .fileName)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        base64 = try container.decodeIfPresent(String.self, forKey: .base64)
        thumbnailBase64 = try container.decodeIfPresent(String.self, forKey: .thumbnailBase64)
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
        encryptionKey = try container.decodeIfPresent(String.self, forKey: .encryptionKey)
        // processingState is transient UI state — always reset to completed on decode
        processingState = .completed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(fileName, forKey: .fileName)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(base64, forKey: .base64)
        try container.encodeIfPresent(thumbnailBase64, forKey: .thumbnailBase64)
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(description, forKey: .description)
        if fileSize > 0 {
            try container.encode(fileSize, forKey: .fileSize)
        }
        try container.encodeIfPresent(encryptionKey, forKey: .encryptionKey)
        // processingState is transient UI state — never encode
    }
}
