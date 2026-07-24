import Foundation
import OpenAI
import SwiftChatCore
@_spi(Generated) import OpenAPIRuntime

public struct OpenAIResponsesProvider: SwiftChatProvider, SwiftChatTranscriptionProvider {
    public let configuration: OpenAIProviderConfiguration

    public init(configuration: OpenAIProviderConfiguration) {
        self.configuration = configuration
    }

    public func stream(
        request: SwiftChatRequest
    ) -> AsyncThrowingStream<SwiftChatEvent, Error> {
        let client = makeClient()
        let query = ChatQueryBuilder.buildQuery(request: request)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream: AsyncThrowingStream<ResponseStreamEvent, Error> =
                        client.responses.createResponseStreaming(query: query)

                    for try await event in stream {
                        if Task.isCancelled { break }
                        switch event {
                        case .outputText(.delta(let value)):
                            continuation.yield(.outputTextDelta(value.delta))
                        case .reasoning(.delta(let value)):
                            if let text = (value.delta.value as? [String: Any])?["text"] as? String {
                                continuation.yield(.reasoningDelta(text))
                            }
                        case .outputTextAnnotation(.added(let value)):
                            if let dictionary = value.annotation.value as? [String: Any],
                               dictionary["type"] as? String == "url_citation",
                               let url = dictionary["url"] as? String {
                                continuation.yield(
                                    .citation(
                                        WebSearchSource(
                                            title: dictionary["title"] as? String ?? url,
                                            url: url
                                        )
                                    )
                                )
                            }
                        case .webSearchCall(.inProgress(_)), .webSearchCall(.searching(_)):
                            continuation.yield(.webSearchStarted)
                        case .webSearchCall(.completed(_)):
                            continuation.yield(.webSearchCompleted)
                        default:
                            break
                        }
                    }

                    continuation.yield(.completed)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func transcribe(audio: Data, fileExtension: String) async throws -> String {
        let fileType: AudioTranscriptionQuery.FileType
        switch fileExtension.lowercased() {
        case "m4a": fileType = .m4a
        case "mp3": fileType = .mp3
        case "wav": fileType = .wav
        default:
            throw SwiftChatProviderError.unsupported(
                "Unsupported audio format: \(fileExtension)"
            )
        }

        let query = AudioTranscriptionQuery(
            file: audio,
            fileType: fileType,
            model: "whisper-1",
            responseFormat: .json
        )
        let result = try await makeClient().audioTranscriptions(query: query)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeClient() -> OpenAI {
        OpenAI(
            configuration: OpenAI.Configuration(
                token: configuration.apiKey,
                host: configuration.host,
                basePath: configuration.basePath
            )
        )
    }

    private static func map(_ error: Error) -> Error {
        if case OpenAIError.statusError(_, let statusCode) = error {
            switch statusCode {
            case 401: return SwiftChatProviderError.authentication
            case 404: return SwiftChatProviderError.modelNotFound
            case 429: return SwiftChatProviderError.rateLimited
            case 400...499:
                return SwiftChatProviderError.invalidRequest(
                    "Request failed (status \(statusCode))."
                )
            default:
                return SwiftChatProviderError.server(statusCode: statusCode)
            }
        }
        if let apiError = error as? APIErrorResponse {
            return SwiftChatProviderError.invalidRequest(apiError.error.message)
        }
        return error
    }
}
