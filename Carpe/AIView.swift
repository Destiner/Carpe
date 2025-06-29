//
//  AIView.swift
//  Carpe
//
//  Created by Timur Badretdinov on 29/06/2025.
//

import SwiftUI
import FoundationModels

struct AIView: View {
    let article: Article
    
    @State private var isLoading = false
    @State private var loadingError: String?
    private let model = SystemLanguageModel.default
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let title = article.readerMode?.title {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                }
                
                if let author = article.readerMode?.author {
                    Text("By \(author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                Group {
                    if isLoading {
                        VStack {
                            ProgressView()
                            Text("Making a summary...")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let error = loadingError {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Failed to generate AI summary")
                                .font(.headline)
                                .padding(.top, 8)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let summary = article.aiSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Summary")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(summary)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    } else {
                        switch model.availability {
                        case .available:
                            EmptyView()
                        case .unavailable(.appleIntelligenceNotEnabled):
                            VStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Apple Intelligence not enabled")
                                    .font(.headline)
                                    .padding(.top, 8)
                                Text("Enable Apple Intelligence in Settings to use AI summaries")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        case .unavailable(.modelNotReady):
                            VStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("AI model not ready")
                                    .font(.headline)
                                    .padding(.top, 8)
                                Text("Please try again later")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        case .unavailable(.deviceNotEligible):
                            VStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Device not eligible")
                                    .font(.headline)
                                    .padding(.top, 8)
                                Text("This device doesn't support Apple Intelligence")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        case .unavailable(_):
                            VStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Device not eligible")
                                    .font(.headline)
                                    .padding(.top, 8)
                                Text("This device doesn't support Apple Intelligence")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // Auto-generate summary if we have reader content but no summary yet
            if article.aiSummary == nil && article.readerMode?.content != nil && model.availability == .available {
                Task {
                    await generateSummary()
                }
            }
        }
    }
    
    private func generateSummary() async {
        guard model.availability == .available else { return }
        guard let readerContent = article.readerMode?.content else {
            loadingError = "No reader content available. Please switch to Reader Mode first."
            return
        }
        
        isLoading = true
        loadingError = nil
        
        do {
            // Trim content to 15000 characters (~3500 tokens)
            let trimmedContent = String(readerContent.prefix(15000))
            
            let session = LanguageModelSession {
                "Summarize this article in 1-3 paragraphs. Focus on the main points and key insights."
            }
            
            let response = try await session.respond {
                trimmedContent
            }
            
            await MainActor.run {
                article.aiSummary = response.content
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadingError = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    let article = Article(url: URL(string: "https://example.com")!, title: "Sample Article")
    article.readerMode = PageReaderMode(
        title: "Sample Article Title",
        author: "John Doe",
        content: "This is sample content for the article that would normally be extracted from reader mode."
    )
    return AIView(article: article)
        .frame(minWidth: 500, minHeight: 500)
}
