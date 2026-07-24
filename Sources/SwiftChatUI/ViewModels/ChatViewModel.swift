//
//  ChatViewModel.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import SwiftChatCore

@MainActor
public final class ChatViewModel: ObservableObject {
    private static let citationMarkerRegex = try? NSRegularExpression(pattern: "【(\\d+)[^】]*】", options: [])

    // Published properties for UI updates
    @Published public var chats: [Chat] = []
    @Published public var currentChat: Chat?
    @Published public var isLoading: Bool = false
    @Published public var thinkingSummary: String = ""
    @Published public var webSearchSummary: String = ""
    @Published public var scrollTargetMessageId: String? = nil
    @Published public var scrollTargetOffset: CGFloat = 0
    @Published public var shouldFocusInput: Bool = false
    @Published public var isScrollInteractionActive: Bool = false
    @Published public var isAtBottom: Bool = true
    @Published public var scrollToBottomTrigger: UUID = UUID()
    @Published public var scrollToUserMessageTrigger: UUID = UUID()
    @Published public var isWebSearchEnabled: Bool = false
    @Published public var imageViewerImages: [Attachment] = []
    @Published public var imageViewerIndex: Int = 0
    @Published public var showImageViewer: Bool = false
    @Published public var editRequestedForMessageIndex: Int? = nil

    // Model properties
    @Published public var currentModel: ModelType

    // Attachment properties
    @Published public var pendingAttachments: [Attachment] = []
    @Published public var isProcessingAttachment: Bool = false
    @Published public var attachmentError: String? = nil
    @Published public var pendingImageThumbnails: [String: String] = [:]

    public var messages: [Message] {
        currentChat?.messages ?? []
    }

    public var availableModels: [ModelType] {
        configuration.models
    }

    // Private properties
    private let provider: any SwiftChatProvider
    private let transcriptionProvider: (any SwiftChatTranscriptionProvider)?
    private let store: any SwiftChatConversationStore
    private let configuration: SwiftChatConfiguration
    private let hostContext: SwiftChatHostContext?
    private var currentTask: Task<Void, Error>?
    private var streamUpdateTimer: Timer?
    private var pendingStreamUpdate: Chat?

    public init(
        provider: any SwiftChatProvider,
        configuration: SwiftChatConfiguration = SwiftChatConfiguration(),
        store: any SwiftChatConversationStore = InMemoryConversationStore(),
        context: SwiftChatHostContext? = nil,
        transcriptionProvider: (any SwiftChatTranscriptionProvider)? = nil
    ) {
        self.provider = provider
        self.transcriptionProvider = transcriptionProvider
            ?? (provider as? any SwiftChatTranscriptionProvider)
        self.store = store
        self.configuration = configuration
        self.hostContext = context
        self.currentModel = configuration.defaultModel
        self.isWebSearchEnabled = configuration.webSearchEnabled

        // Create initial blank chat
        let newChat = Chat.create(modelType: currentModel)
        currentChat = newChat
        chats = [newChat]

        Task { await loadStoredConversations() }
    }

    deinit {
        streamUpdateTimer?.invalidate()
    }

    private func loadStoredConversations() async {
        guard let stored = try? await store.conversations(), !stored.isEmpty else { return }
        chats = stored
        currentChat = stored[0]
        currentModel = stored[0].modelType
    }

    // MARK: - Chat Management

    public func createNewChat(language: String? = nil, modelType: ModelType? = nil, focusInput: Bool = true) {
        if isLoading { cancelGeneration() }

        // Check if we already have a blank chat
        if let existing = chats.first(where: { $0.isBlankChat }) {
            selectChat(existing)
            shouldFocusInput = focusInput
            return
        }

        let newChat = Chat.create(modelType: modelType ?? currentModel, language: language)
        chats.insert(newChat, at: 0)
        selectChat(newChat)
        shouldFocusInput = focusInput
    }

    public func selectChat(_ chat: Chat) {
        if isLoading { cancelGeneration() }

        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            currentChat = chats[index]
        } else {
            currentChat = chat
            chats.append(chat)
        }

        if currentModel != chat.modelType {
            changeModel(to: chat.modelType, shouldUpdateChat: false)
        }
    }

    public func deleteChat(_ id: String) {
        if let index = chats.firstIndex(where: { $0.id == id }) {
            chats.remove(at: index)
        }

        if currentChat?.id == id {
            if let first = chats.first {
                currentChat = first
            } else {
                createNewChat()
            }
        }
        Task { try? await store.delete(id: id) }
    }

    public func updateChatTitle(_ id: String, newTitle: String) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            chats[index].title = Chat.placeholderTitle
            chats[index].titleState = .placeholder
        } else {
            chats[index].title = trimmed
            chats[index].titleState = .manual
        }
        if currentChat?.id == id {
            currentChat = chats[index]
        }
        Task { try? await store.save(chats[index]) }
    }

    // MARK: - Message Sending

    public func sendMessage(text: String) {
        guard !isLoading else { return }
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !pendingAttachments.isEmpty
        guard hasText || hasAttachments else { return }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        isLoading = true

        let messageAttachments = pendingAttachments
        clearPendingAttachments()

        let userMessage = Message(role: .user, content: text, attachments: messageAttachments)
        addMessage(userMessage)

        generateResponse()
    }

    // MARK: - Attachment Management

    public func addImageAttachment(data: Data, fileName: String) {
        isProcessingAttachment = true
        attachmentError = nil

        let attachmentId = UUID().uuidString.lowercased()
        var attachment = Attachment(
            id: attachmentId,
            type: .image,
            fileName: fileName,
            fileSize: Int64(data.count),
            processingState: .processing
        )
        pendingAttachments.append(attachment)

        Task {
            // Simple image processing — resize and compress
            guard let uiImage = UIImage(data: data) else {
                attachment.processingState = .failed
                if let index = pendingAttachments.firstIndex(where: { $0.id == attachmentId }) {
                    pendingAttachments[index] = attachment
                }
                attachmentError = "Failed to load image"
                isProcessingAttachment = false
                return
            }

            let maxDim = Constants.Attachments.maxImageDimension
            let scale = min(maxDim / max(uiImage.size.width, uiImage.size.height), 1.0)
            let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
            let resized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            guard let compressed = resized?.jpegData(compressionQuality: Constants.Attachments.imageCompressionQuality) else {
                attachment.processingState = .failed
                if let index = pendingAttachments.firstIndex(where: { $0.id == attachmentId }) {
                    pendingAttachments[index] = attachment
                }
                attachmentError = "Failed to compress image"
                isProcessingAttachment = false
                return
            }

            attachment.mimeType = Constants.Attachments.defaultImageMimeType
            attachment.base64 = compressed.base64EncodedString()
            attachment.fileSize = Int64(compressed.count)
            attachment.processingState = .completed

            let sizeKB = compressed.count / 1024
            attachment.description = "\(fileName) — \(Int(newSize.width))x\(Int(newSize.height)) JPEG, \(sizeKB) KB"

            // Generate thumbnail
            let thumbMax = Constants.Attachments.thumbnailMaxDimension
            let thumbScale = min(thumbMax / max(newSize.width, newSize.height), 1.0)
            let thumbSize = CGSize(width: newSize.width * thumbScale, height: newSize.height * thumbScale)
            UIGraphicsBeginImageContextWithOptions(thumbSize, false, 1.0)
            resized?.draw(in: CGRect(origin: .zero, size: thumbSize))
            let thumb = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            attachment.thumbnailBase64 = thumb?.jpegData(compressionQuality: 0.6)?.base64EncodedString()

            if let index = pendingAttachments.firstIndex(where: { $0.id == attachmentId }) {
                pendingAttachments[index] = attachment
            }
            if let tb = attachment.thumbnailBase64 {
                pendingImageThumbnails[attachmentId] = tb
            }
            isProcessingAttachment = false
        }
    }

    public func addDocumentAttachment(url: URL, fileName: String) {
        isProcessingAttachment = true
        attachmentError = nil

        let attachmentId = UUID().uuidString.lowercased()
        var attachment = Attachment(
            id: attachmentId,
            type: .document,
            fileName: fileName,
            processingState: .processing
        )
        pendingAttachments.append(attachment)

        Task {
            do {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                let text = try String(contentsOf: url, encoding: .utf8)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

                attachment.textContent = text
                attachment.fileSize = fileSize
                attachment.processingState = .completed

                if let index = pendingAttachments.firstIndex(where: { $0.id == attachmentId }) {
                    pendingAttachments[index] = attachment
                }
            } catch {
                attachment.processingState = .failed
                if let index = pendingAttachments.firstIndex(where: { $0.id == attachmentId }) {
                    pendingAttachments[index] = attachment
                }
                attachmentError = error.localizedDescription
            }
            isProcessingAttachment = false
        }
    }

    public func removePendingAttachment(id: String) {
        pendingAttachments.removeAll { $0.id == id }
        pendingImageThumbnails.removeValue(forKey: id)
        if pendingAttachments.isEmpty { attachmentError = nil }
    }

    public func clearPendingAttachments() {
        pendingAttachments.removeAll()
        pendingImageThumbnails.removeAll()
        attachmentError = nil
        isProcessingAttachment = false
    }

    public func transcribeAudio(at fileURL: URL) async throws -> String {
        guard let transcriptionProvider else {
            throw SwiftChatProviderError.unsupported(
                "The configured provider does not support audio transcription."
            )
        }
        let audioData = try await Task.detached {
            try Data(contentsOf: fileURL)
        }.value
        guard !audioData.isEmpty else {
            throw AudioRecordingError.emptyRecording
        }
        let result = try await transcriptionProvider.transcribe(
            audio: audioData,
            fileExtension: fileURL.pathExtension
        )
        guard !result.isEmpty else {
            throw AudioRecordingError.emptyTranscription
        }
        return result
    }

    // MARK: - Response Generation

    private func generateResponse() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isLoading = true

        let assistantMessage = Message(role: .assistant, content: "", isCollapsed: true)
        addMessage(assistantMessage)

        if var chat = currentChat {
            chat.hasActiveStream = true
            replaceChat(chat)
            currentChat = chat
        }

        let streamChatId = currentChat?.id
        currentTask?.cancel()

        currentTask = Task {
            var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
            backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "CompleteStreamingResponse") {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
                backgroundTaskId = .invalid
            }
            defer {
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }

            do {
                let settingsManager = SettingsManager.shared

                var systemPrompt: String
                if settingsManager.isUsingCustomPrompt && !settingsManager.customSystemPrompt.isEmpty {
                    systemPrompt = settingsManager.customSystemPrompt
                } else {
                    systemPrompt = configuration.systemPrompt
                }

                systemPrompt = systemPrompt.replacingOccurrences(of: "{MODEL_NAME}", with: currentModel.fullName)

                let languageToUse = settingsManager.selectedLanguage != "System" ? settingsManager.selectedLanguage : "English"
                systemPrompt = systemPrompt.replacingOccurrences(of: "{LANGUAGE}", with: languageToUse)
                systemPrompt = systemPrompt.replacingOccurrences(of: "{USER_PREFERENCES}", with: "")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let currentDateTime = dateFormatter.string(from: Date())
                let timezone = TimeZone.current.abbreviation() ?? TimeZone.current.identifier
                systemPrompt = systemPrompt.replacingOccurrences(of: "{CURRENT_DATETIME}", with: currentDateTime)
                systemPrompt = systemPrompt.replacingOccurrences(of: "{TIMEZONE}", with: timezone)

                var processedRules = configuration.rules
                if !processedRules.isEmpty {
                    processedRules = processedRules.replacingOccurrences(of: "{MODEL_NAME}", with: currentModel.fullName)
                    processedRules = processedRules.replacingOccurrences(of: "{LANGUAGE}", with: languageToUse)
                    processedRules = processedRules.replacingOccurrences(of: "{USER_PREFERENCES}", with: "")
                    processedRules = processedRules.replacingOccurrences(of: "{CURRENT_DATETIME}", with: currentDateTime)
                    processedRules = processedRules.replacingOccurrences(of: "{TIMEZONE}", with: timezone)
                }

                let request = SwiftChatRequest(
                    conversationID: streamChatId ?? Chat.generateReverseId(),
                    model: currentModel,
                    messages: self.messages,
                    systemPrompt: systemPrompt,
                    rules: processedRules,
                    maxMessages: settingsManager.maxMessages,
                    webSearchEnabled: self.isWebSearchEnabled,
                    hostContext: hostContext
                )

                var collectedSources: [WebSearchSource] = []

                let stream = provider.stream(request: request)

                var thinkStartTime: Date? = nil
                var thoughtsBuffer = ""
                var isInThinkingMode = false
                var responseContent = ""
                var currentThoughts: String? = nil
                var generationTimeSeconds: TimeInterval? = nil
                let hapticEnabled = SettingsManager.shared.hapticFeedbackEnabled
                var hapticGenerator: UIImpactFeedbackGenerator?
                var lastHapticTime = Date.distantPast
                let minHapticInterval: TimeInterval = 0.1
                let chunker = StreamingMarkdownChunker()
                let thinkingChunker = ThinkingTextChunker()
                var hapticChunkCount = 0
                var hasStartedResponse = false
                var lastUIUpdateTime = Date.distantPast
                let uiUpdateInterval: TimeInterval = 0.033

                await MainActor.run {
                    if let chat = self.currentChat,
                       !chat.messages.isEmpty,
                       let lastIndex = chat.messages.indices.last {
                        responseContent = chat.messages[lastIndex].content
                        currentThoughts = chat.messages[lastIndex].thoughts
                        generationTimeSeconds = chat.messages[lastIndex].generationTimeSeconds
                        isInThinkingMode = chat.messages[lastIndex].isThinking
                    }
                    if hapticEnabled {
                        hapticGenerator = UIImpactFeedbackGenerator(style: .light)
                        hapticGenerator?.prepare()
                    }
                }

                for try await event in stream {
                    if Task.isCancelled { break }

                    // Haptic feedback
                    if hapticEnabled, let generator = hapticGenerator {
                        if hapticChunkCount < 5 {
                            let now = Date()
                            if now.timeIntervalSince(lastHapticTime) >= minHapticInterval {
                                generator.impactOccurred(intensity: 0.5)
                                lastHapticTime = now
                                hapticChunkCount += 1
                            }
                        }
                        if !isInThinkingMode && !hasStartedResponse {
                            hasStartedResponse = true
                            hapticChunkCount = 0
                        }
                    }

                    var didMutateState = false

                    switch event {
                    case .outputTextDelta(let content):
                        if !content.isEmpty {
                            if isInThinkingMode {
                                if let startTime = thinkStartTime {
                                    generationTimeSeconds = Date().timeIntervalSince(startTime)
                                }
                                isInThinkingMode = false
                                thinkStartTime = nil
                                thinkingChunker.finalize()
                                currentThoughts = thoughtsBuffer.isEmpty ? nil : thoughtsBuffer
                                Task { @MainActor [weak self] in
                                    ThinkingSummaryService.shared.reset()
                                    self?.thinkingSummary = ""
                                }
                            }
                            responseContent += content
                            chunker.appendToken(content)
                            didMutateState = true
                            if !hasStartedResponse {
                                hasStartedResponse = true
                                hapticChunkCount = 0
                            }
                        }

                    case .reasoningDelta(let text):
                        if !text.isEmpty {
                            if !isInThinkingMode {
                                isInThinkingMode = true
                                thinkStartTime = Date()
                                Task { @MainActor in ThinkingSummaryService.shared.reset() }
                            }
                            thoughtsBuffer += text
                            thinkingChunker.appendToken(text)
                            currentThoughts = thoughtsBuffer.isEmpty ? nil : thoughtsBuffer
                            didMutateState = true
                            let currentThoughtsForSummary = thoughtsBuffer
                            Task { @MainActor [weak self] in
                                ThinkingSummaryService.shared.generateSummary(thoughts: currentThoughtsForSummary) { summary in
                                    self?.thinkingSummary = summary
                                }
                            }
                        }

                    case .citation(let source):
                        collectedSources.append(source)
                        didMutateState = true

                    case .webSearchStarted:
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            guard var chat = self.currentChat,
                                  !chat.messages.isEmpty,
                                  let lastIndex = chat.messages.indices.last else { return }
                            if chat.messages[lastIndex].webSearchState == nil {
                                chat.messages[lastIndex].webSearchState = WebSearchState(status: .searching)
                            }
                            self.webSearchSummary = "Searching the web..."
                            self.replaceChat(chat)
                            self.currentChat = chat
                        }

                    case .webSearchCompleted:
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            guard var chat = self.currentChat,
                                  !chat.messages.isEmpty,
                                  let lastIndex = chat.messages.indices.last else { return }
                            chat.messages[lastIndex].webSearchState?.status = .completed
                            self.webSearchSummary = ""
                            self.replaceChat(chat)
                            self.currentChat = chat
                        }

                    case .completed:
                        break
                    }

                    // Throttled UI update
                    let now = Date()
                    if didMutateState && now.timeIntervalSince(lastUIUpdateTime) >= uiUpdateInterval {
                        lastUIUpdateTime = now
                        let currentChunks = chunker.getAllChunks()
                        let currentThinkingChunks = thinkingChunker.getAllChunks()
                        let capturedContent = responseContent
                        let capturedThoughts = currentThoughts
                        let capturedThinking = isInThinkingMode
                        let capturedGenTime = generationTimeSeconds
                        let capturedSources = collectedSources

                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            guard self.currentChat?.id == streamChatId else { return }
                            guard var chat = self.currentChat,
                                  chat.hasActiveStream,
                                  !chat.messages.isEmpty,
                                  let lastIndex = chat.messages.indices.last else { return }

                            let processedContent = self.processCitationMarkers(capturedContent, sources: capturedSources)
                            let processedChunks = self.processChunksWithCitations(currentChunks, sources: capturedSources)

                            chat.messages[lastIndex].content = processedContent
                            chat.messages[lastIndex].thoughts = capturedThoughts
                            chat.messages[lastIndex].thinkingChunks = currentThinkingChunks
                            chat.messages[lastIndex].isThinking = capturedThinking
                            chat.messages[lastIndex].generationTimeSeconds = capturedGenTime
                            chat.messages[lastIndex].contentChunks = processedChunks

                            if !capturedSources.isEmpty {
                                var searchState = chat.messages[lastIndex].webSearchState ?? WebSearchState(status: .searching)
                                searchState.sources = capturedSources
                                chat.messages[lastIndex].webSearchState = searchState
                            }

                            self.replaceChat(chat)
                            self.currentChat = chat
                        }
                    }
                }

                // Handle remaining thinking content when stream ends
                if isInThinkingMode && !thoughtsBuffer.isEmpty {
                    currentThoughts = thoughtsBuffer.isEmpty ? nil : thoughtsBuffer
                    if responseContent.isEmpty {
                        responseContent = thoughtsBuffer
                        currentThoughts = nil
                    }
                    if let startTime = thinkStartTime { generationTimeSeconds = Date().timeIntervalSince(startTime) }
                    isInThinkingMode = false
                }

                // Finalize message
                await MainActor.run {
                    guard var chat = self.currentChat, chat.id == streamChatId else {
                        self.isLoading = false
                        return
                    }
                    chat.hasActiveStream = false

                    ThinkingSummaryService.shared.reset()
                    self.thinkingSummary = ""
                    self.webSearchSummary = ""

                    if !chat.messages.isEmpty, let lastIndex = chat.messages.indices.last {
                        chunker.finalize()
                        thinkingChunker.finalize()
                        let processedContent = self.processCitationMarkers(responseContent, sources: collectedSources)
                        chat.messages[lastIndex].content = processedContent
                        chat.messages[lastIndex].thoughts = currentThoughts
                        chat.messages[lastIndex].thinkingChunks = thinkingChunker.getAllChunks()
                        chat.messages[lastIndex].isThinking = false
                        chat.messages[lastIndex].generationTimeSeconds = generationTimeSeconds
                        let processedChunks = self.processChunksWithCitations(chunker.getAllChunks(), sources: collectedSources)
                        chat.messages[lastIndex].contentChunks = processedChunks
                        if !collectedSources.isEmpty {
                            var searchState = chat.messages[lastIndex].webSearchState ?? WebSearchState(status: .searching)
                            searchState.sources = collectedSources
                            chat.messages[lastIndex].webSearchState = searchState
                        }
                    }

                    self.replaceChat(chat)
                    self.currentChat = chat
                    self.isLoading = false

                    // Generate title if needed
                    if chat.needsGeneratedTitle && chat.messages.count >= 2 {
                        Task {
                            if let generated = await self.generateLLMTitle(from: chat.messages) {
                                if var updatedChat = self.chats.first(where: { $0.id == chat.id }) {
                                    updatedChat.title = generated
                                    updatedChat.titleState = .generated
                                    self.replaceChat(updatedChat)
                                    if self.currentChat?.id == updatedChat.id {
                                        self.currentChat = updatedChat
                                    }
                                    HapticFeedback.trigger(.success)
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.thinkingSummary = ""
                    self.webSearchSummary = ""

                    if var chat = self.currentChat, chat.id == streamChatId {
                        chat.hasActiveStream = false
                        if !chat.messages.isEmpty {
                            let lastIndex = chat.messages.count - 1
                            chat.messages[lastIndex].streamError = self.formatUserFriendlyError(error)
                            chat.messages[lastIndex].isRequestError = self.isRequestError(error)
                        }
                        self.replaceChat(chat)
                        self.currentChat = chat
                    }
                }
            }
        }
    }

    public func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        thinkingSummary = ""
        webSearchSummary = ""

        if var chat = currentChat {
            chat.hasActiveStream = false
            replaceChat(chat)
            currentChat = chat
        }
    }

    public func regenerateLastResponse() {
        guard let chat = currentChat, !isLoading else { return }
        guard let lastUserMessageIndex = chat.messages.lastIndex(where: { $0.role == .user }) else { return }

        var updatedChat = chat
        updatedChat.messages = Array(chat.messages.prefix(lastUserMessageIndex + 1))
        replaceChat(updatedChat)
        currentChat = updatedChat

        isScrollInteractionActive = false
        scrollToUserMessageTrigger = UUID()
        generateResponse()
    }

    public func editMessage(at messageIndex: Int, newContent: String) {
        guard let chat = currentChat,
              !isLoading,
              messageIndex >= 0,
              messageIndex < chat.messages.count,
              chat.messages[messageIndex].role == .user else { return }

        let trimmedContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        var updatedChat = chat
        updatedChat.messages = Array(chat.messages.prefix(messageIndex))
        replaceChat(updatedChat)
        currentChat = updatedChat

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isLoading = true

        let userMessage = Message(role: .user, content: trimmedContent)
        addMessage(userMessage)
        generateResponse()
    }

    public func regenerateMessage(at messageIndex: Int) {
        guard let chat = currentChat,
              !isLoading,
              messageIndex >= 0,
              messageIndex < chat.messages.count,
              chat.messages[messageIndex].role == .user else { return }

        var updatedChat = chat
        updatedChat.messages = Array(chat.messages.prefix(messageIndex + 1))
        replaceChat(updatedChat)
        currentChat = updatedChat

        isScrollInteractionActive = false
        scrollToUserMessageTrigger = UUID()
        generateResponse()
    }

    // MARK: - Model Management

    public func changeModel(to modelType: ModelType, shouldUpdateChat: Bool = true) {
        guard modelType != currentModel else { return }
        currentTask?.cancel()
        currentTask = nil
        isLoading = false

        self.currentModel = modelType
        UserDefaults.standard.set(modelType.id, forKey: "selectedModel")

        if shouldUpdateChat, var chat = currentChat {
            chat.modelType = modelType
            replaceChat(chat)
            currentChat = chat
        }
    }

    // MARK: - Thoughts Collapse

    public func setThoughtsCollapsed(for messageId: String, collapsed: Bool) {
        guard var chat = currentChat,
              let messageIndex = chat.messages.firstIndex(where: { $0.id == messageId }) else { return }
        guard chat.messages[messageIndex].isCollapsed != collapsed else { return }
        chat.messages[messageIndex].isCollapsed = collapsed
        replaceChat(chat)
        currentChat = chat
    }

    // MARK: - Private Helpers

    private func addMessage(_ message: Message) {
        guard var chat = currentChat else { return }
        chat.messages.append(message)
        replaceChat(chat)
        currentChat = chat
    }

    private func replaceChat(_ updatedChat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == updatedChat.id }) {
            chats[index] = updatedChat
        } else if !updatedChat.isBlankChat {
            chats.insert(updatedChat, at: min(1, chats.count))
        }
        Task { try? await store.save(updatedChat) }
    }

    private func formatUserFriendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed:
                return "The Internet connection appears to be offline."
            case NSURLErrorNetworkConnectionLost:
                return "Network connection was lost."
            case NSURLErrorTimedOut:
                return "Request timed out. Please try again."
            default:
                return "Network error. Please check your connection."
            }
        }
        if let providerError = error as? SwiftChatProviderError {
            return providerError.localizedDescription
        }
        return "An error occurred. Please try again."
    }

    private func isRequestError(_ error: Error) -> Bool {
        guard let providerError = error as? SwiftChatProviderError else { return false }
        if case .invalidRequest = providerError { return true }
        return false
    }

    static func isAuthenticationError(_ error: Error) -> Bool {
        guard let providerError = error as? SwiftChatProviderError else { return false }
        if case .authentication = providerError { return true }
        return false
    }

    private func processChunksWithCitations(_ chunks: [ContentChunk], sources: [WebSearchSource]) -> [ContentChunk] {
        chunks.map { chunk in
            ContentChunk(id: chunk.id, type: chunk.type, content: processCitationMarkers(chunk.content, sources: sources), isComplete: chunk.isComplete)
        }
    }

    private func processCitationMarkers(_ content: String, sources: [WebSearchSource]) -> String {
        guard !sources.isEmpty else { return content }
        guard let regex = Self.citationMarkerRegex else { return content }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
        guard !matches.isEmpty else { return content }

        var result = ""
        var lastEnd = content.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: content),
                  let numRange = Range(match.range(at: 1), in: content),
                  let num = Int(content[numRange]) else { continue }

            let index = num - 1
            guard index >= 0, index < sources.count else { continue }
            let source = sources[index]

            let encodedUrl = source.url
                .replacingOccurrences(of: "(", with: "%28")
                .replacingOccurrences(of: ")", with: "%29")
                .replacingOccurrences(of: "|", with: "%7C")
                .replacingOccurrences(of: "~", with: "%7E")
            let encodedTitle = (source.title
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? source.title)
                .replacingOccurrences(of: "(", with: "%28")
                .replacingOccurrences(of: ")", with: "%29")
                .replacingOccurrences(of: "~", with: "%7E")

            result += content[lastEnd..<matchRange.lowerBound]
            result += "[\(num)](#cite-\(num)~\(encodedUrl)~\(encodedTitle))"
            lastEnd = matchRange.upperBound
        }

        result += content[lastEnd...]
        return result
    }
}

// MARK: - LLM Title Generation
extension ChatViewModel {
    fileprivate func generateLLMTitle(from messages: [Message]) async -> String? {
        guard let assistantMessage = messages.first(where: { $0.role == .assistant }),
              !assistantMessage.content.isEmpty else { return nil }

        // Use the title model if available, otherwise skip title generation
        guard let titleModelConfig = configuration.titleModel else { return nil }

        let words = assistantMessage.content.split(separator: " ", omittingEmptySubsequences: true)
        let truncatedContent = words.prefix(Constants.TitleGeneration.wordThreshold).joined(separator: " ")

        do {
            let titleRequest = SwiftChatRequest(
                conversationID: Chat.generateReverseId(),
                model: titleModelConfig,
                messages: [Message(role: .user, content: truncatedContent)],
                systemPrompt: Constants.TitleGeneration.systemPrompt,
                maxMessages: 1
            )

            var title = ""
            for try await event in provider.stream(request: titleRequest) {
                if case .outputTextDelta(let text) = event {
                    title += text
                }
            }

            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }
}
