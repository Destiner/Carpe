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

struct ModelUtils {
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
        
        // If content is short enough, process normally
        if content.count <= 15000 {
            let session = LanguageModelSession {
                "Summarize this article in 1-3 paragraphs. Focus on the main points and key insights."
            }
            let response = try await session.respond {
                content
            }
            return response.content
        }
        
        // For longer content, use chunking approach
        return try await generateChunkedSummary(from: content)
    }
    
    private static func generateChunkedSummary(from content: String) async throws -> String {
        let chunkSize = 15000
        let chunks = content.chunked(into: chunkSize)
        var chunkSummaries: [String] = []
        
        // Process chunks sequentially to avoid overwhelming the device
        for (index, chunk) in chunks.enumerated() {
            let session = LanguageModelSession {
                "Summarize this section of an article (part \(index + 1) of \(chunks.count)) in 1-2 paragraphs. Focus on the key points:"
            }
            let response = try await session.respond {
                chunk
            }
            chunkSummaries.append(response.content)
        }
        
        // Generate meta-summary from chunk summaries
        let combinedSummaries = chunkSummaries.joined(separator: "\n\n")
        let metaSession = LanguageModelSession {
            "These are summaries of different sections of a long article. Create a cohesive summary in 2-3 paragraphs that captures the overall main points and key insights:"
        }
        let metaResponse = try await metaSession.respond {
            combinedSummaries
        }
        return metaResponse.content
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
