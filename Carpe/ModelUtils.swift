//
//  ModelUtils.swift
//  Carpe
//
//  Created by Timur Badretdinov on 29/06/2025.
//

import Foundation
import FoundationModels

extension String {
    func chunked(into size: Int) -> [String] {
        var chunks: [String] = []
        var startIndex = self.startIndex
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: size, limitedBy: self.endIndex) ?? self.endIndex
            chunks.append(String(self[startIndex..<endIndex]))
            startIndex = endIndex
        }
        
        return chunks
    }
}

struct SummaryParams {
    let paragraphsMin: Int
    let paragraphsMax: Int
    
    init(_ paragraphsMin: Int = 1, _ paragraphsMax: Int = 3) {
        self.paragraphsMin = paragraphsMin
        self.paragraphsMax = paragraphsMax
    }
}

struct ModelUtils {
    private static let CHUNK_SIZE = 10_000
    private static let model = SystemLanguageModel.default
    
    static var isAvailable: Bool {
        model.availability == .available
    }
    
    static var availabilityStatus: SystemLanguageModel.Availability {
        model.availability
    }
    
    static func generateSummary(from content: String) async throws -> String {
        guard model.availability == .available else {
            throw LLMError.modelUnavailable(model.availability)
        }
        
        let params = getSummaryParams(content: content)
        
        // If content is short enough, process normally
        if content.count <= CHUNK_SIZE {
            let session = LanguageModelSession {
                "Summarize this article in \(params.paragraphsMin)-\(params.paragraphsMax) paragraphs. Focus on the main points and key insights."
            }
            let response = try await session.respond(options: .init(maximumResponseTokens: 1_000)) {
                content
            }
            return response.content
        }
        
        // For longer content, use chunking approach
        return try await generateChunkedSummary(from: content)
    }
    
    private static func generateChunkedSummary(from content: String) async throws -> String {
        let chunks = content.chunked(into: CHUNK_SIZE)
        var chunkSummaries: [String] = []
        
        // Process chunks sequentially to avoid overwhelming the device
        for (index, chunk) in chunks.enumerated() {
            let session = LanguageModelSession {
                "Summarize this section of an article (part \(index + 1) of \(chunks.count)) in 1-2 short paragraphs. Focus on the key points:"
            }
            let response = try await session.respond(options: .init(maximumResponseTokens: 500)) {
                chunk
            }
            chunkSummaries.append(response.content)
        }
        
        // Generate meta-summary from chunk summaries
        let params = getSummaryParams(content: content)
        let combinedSummaries = chunkSummaries.joined(separator: "\n\n")
        let metaSession = LanguageModelSession {
            "These are summaries of different sections of a long article. Create a cohesive summary in \(params.paragraphsMin)-\(params.paragraphsMax) paragraphs that captures the overall main points and key insights:"
        }
        let metaResponse = try await metaSession.respond(options: .init(maximumResponseTokens: 1_000)) {
            combinedSummaries
        }
        return metaResponse.content
    }
    
    /// Dynamic summary shape based on the content's size
    private static func getSummaryParams(content: String) -> SummaryParams {
        switch content.count {
        case 0..<5_000:
            SummaryParams(1, 2)
        case 5_000..<10_000:
            SummaryParams(2, 3)
        case 10_000..<20_000:
            SummaryParams(2, 4)
        case 20_000..<40_000:
            SummaryParams(3, 5)
        default:
            SummaryParams(3, 6)
        }
    }
    
    static func answer(content: String, question: String) async throws -> String {
        guard model.availability == .available else {
            throw LLMError.modelUnavailable(model.availability)
        }
        
        // If content is short enough, process normally
        if content.count <= CHUNK_SIZE {
            let session = LanguageModelSession {
                "Based on the following article content, answer the user's question. Be concise and accurate. If the answer cannot be found in the content, say so clearly."
            }
            let response = try await session.respond(options: .init(maximumResponseTokens: 500)) {
                "Question: \(question)\n\nArticle content:\n\(content)"
            }
            return response.content
        }
        
        // For longer content, use chunking approach
        return try await generateChunkedAnswer(content: content, question: question)
    }
    
    private static func generateChunkedAnswer(content: String, question: String) async throws -> String {
        let chunks = content.chunked(into: CHUNK_SIZE)
        var chunkAnswers: [String] = []
        
        // Process chunks sequentially to avoid overwhelming the device
        for (index, chunk) in chunks.enumerated() {
            let session = LanguageModelSession {
                "Based on this section of an article (part \(index + 1) of \(chunks.count)), try to answer the user's question. If this section doesn't contain relevant information, say 'No relevant information found in this section.'"
            }
            let response = try await session.respond(options: .init(maximumResponseTokens: 300)) {
                "Question: \(question)\n\nArticle section:\n\(chunk)"
            }
            chunkAnswers.append(response.content)
        }
        
        // Synthesize final answer from chunk answers
        let combinedAnswers = chunkAnswers.joined(separator: "\n\n")
        let synthesisSession = LanguageModelSession {
            "These are answers from different sections of a long article for the same question. Synthesize a comprehensive and coherent final answer. If no relevant information was found in any section, say so clearly."
        }
        let finalResponse = try await synthesisSession.respond(options: .init(maximumResponseTokens: 500)) {
            "Question: \(question)\n\nAnswers from different sections:\n\(combinedAnswers)"
        }
        return finalResponse.content
    }
    
    enum LLMError: LocalizedError {
        case modelUnavailable(SystemLanguageModel.Availability)
        
        var errorDescription: String? {
            switch self {
            case .modelUnavailable(let availability):
                switch availability {
                case .unavailable(.appleIntelligenceNotEnabled):
                    return "Apple Intelligence not enabled"
                case .unavailable(.modelNotReady):
                    return "AI model not ready. Please try again later."
                case .unavailable(.deviceNotEligible):
                    return "This device doesn't support Apple Intelligence"
                case .unavailable(_):
                    return "AI model unavailable"
                case .available:
                    return "AI model should be available"
                }
            }
        }
    }
}
