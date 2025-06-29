//
//  ModelUtils.swift
//  Carpe
//
//  Created by Timur Badretdinov on 29/06/2025.
//

import Foundation
import FoundationModels

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
        
        // Trim content to 15000 characters (~3500 tokens)
        let trimmedContent = String(content.prefix(15000))
        
        let session = LanguageModelSession {
            "Summarize this article in 1-3 paragraphs. Focus on the main points and key insights."
        }
        
        let response = try await session.respond {
            trimmedContent
        }
        
        return response.content
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
