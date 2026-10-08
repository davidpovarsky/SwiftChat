//
//  ChatQueryBuilder.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation
import OpenAI
import SwiftChatCore

/// Helper for building CreateModelResponseQuery for the Responses API
struct ChatQueryBuilder {

    private typealias Schemas = Components.Schemas

    /// Build a Responses API query with system instructions, conversation history, and optional web search
    static func buildQuery(
        modelId: String,
        systemPrompt: String,
        rules: String,
        conversationMessages: [Message],
        maxMessages: Int,
        stream: Bool = true,
        webSearchEnabled: Bool = false,
        isMultimodal: Bool = false
    ) -> CreateModelResponseQuery {

        let fullPrompt = rules.isEmpty ? systemPrompt : systemPrompt + "\n\n" + rules

        var inputItems: [InputItem] = []

        // Add conversation history
        let recentMessages = Array(conversationMessages.suffix(maxMessages))

        for msg in recentMessages {
            if msg.role == .user {
                var userContent = msg.content

                // Derive document content and image data from attachments
                let documentAttachments = msg.attachments.filter { $0.type == .document }
                let imageAttachments = msg.attachments.filter { $0.type == .image }

                // Prepend document content as context when present
                if !documentAttachments.isEmpty {
                    let docContent = documentAttachments
                        .compactMap { attachment -> String? in
                            guard let text = attachment.textContent, !text.isEmpty else { return nil }
                            return "Document title: \(attachment.fileName)\nDocument contents:\n\(text)"
                        }
                        .joined(separator: "\n\n")
                    if !docContent.isEmpty {
                        userContent = "---\nDocument content:\n\(docContent)\n---\n\n\(userContent)"
                    }
                }

                // Use multimodal content parts when model supports it and message has images
                if isMultimodal, !imageAttachments.isEmpty {
                    var parts: [InputContent] = []
                    parts.append(.inputText(Schemas.InputTextContent(_type: .inputText, text: userContent)))
                    for attachment in imageAttachments {
                        guard let base64 = attachment.base64,
                              let mimeType = attachment.mimeType else { continue }
                        let dataUrl = "data:\(mimeType);base64,\(base64)"
                        parts.append(.inputImage(InputImage(
                            _type: .inputImage,
                            imageUrl: dataUrl,
                            detail: .auto
                        )))
                    }
                    inputItems.append(.inputMessage(EasyInputMessage(role: .user, content: .inputItemContentList(parts))))
                } else if !imageAttachments.isEmpty {
                    // Non-multimodal model: append image descriptions as text fallback
                    let descriptions = imageAttachments
                        .compactMap { attachment -> String? in
                            guard let desc = attachment.description, !desc.isEmpty else { return nil }
                            return "Image: \(attachment.fileName)\nDescription:\n\(desc)"
                        }
                    if !descriptions.isEmpty {
                        let descText = descriptions.joined(separator: "\n\n")
                        userContent = userContent + "\n\n[Treat these descriptions as if they are the raw images.]\n" + descText
                    }
                    inputItems.append(.inputMessage(EasyInputMessage(role: .user, content: .textInput(userContent))))
                } else {
                    inputItems.append(.inputMessage(EasyInputMessage(role: .user, content: .textInput(userContent))))
                }
            } else if !msg.content.isEmpty {
                inputItems.append(.inputMessage(EasyInputMessage(role: .assistant, content: .textInput(msg.content))))
            }
        }

        // Build tools array
        var tools: [Tool]? = nil
        if webSearchEnabled {
            tools = [.webSearchTool(Schemas.WebSearchPreviewTool(_type: .webSearchPreview))]
        }

        return CreateModelResponseQuery(
            input: .inputItemList(inputItems),
            model: modelId,
            instructions: fullPrompt,
            stream: stream ? true : nil,
            tools: tools
        )
    }

    static func buildQuery(request: SwiftChatRequest) -> CreateModelResponseQuery {
        var systemPrompt = request.systemPrompt
        if let context = request.hostContext {
            var contextLines: [String] = []
            if let title = context.title { contextLines.append("Title: \(title)") }
            if let subtitle = context.subtitle { contextLines.append("Subtitle: \(subtitle)") }
            if let selectedText = context.selectedText {
                contextLines.append("Selected text:\n\(selectedText)")
            }
            if let surroundingText = context.surroundingText {
                contextLines.append("Surrounding text:\n\(surroundingText)")
            }
            if !context.metadata.isEmpty {
                let metadata = context.metadata
                    .sorted(by: { $0.key < $1.key })
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: "\n")
                contextLines.append("Metadata:\n\(metadata)")
            }
            if !contextLines.isEmpty {
                systemPrompt += "\n\nHost context:\n" + contextLines.joined(separator: "\n\n")
            }
        }

        return buildQuery(
            modelId: request.model.modelName,
            systemPrompt: systemPrompt,
            rules: request.rules,
            conversationMessages: request.messages,
            maxMessages: request.maxMessages,
            webSearchEnabled: request.webSearchEnabled,
            isMultimodal: request.model.isMultimodal
        )
    }
}
