//
//  ModelView.swift
//  Carpe
//
//  Created by Timur Badretdinov on 29/06/2025.
//

import SwiftUI
import FoundationModels

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct ModelView: View {
    let article: Article
    
    @State private var isLoading = false
    @State private var loadingError: String?
    @State private var messages: [ChatMessage] = []
    @State private var questionText = ""
    @State private var isAnswering = false
    
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
                        EmptyView()
                    }
                }
                
                // Chat interface
                if article.aiSummary != nil && ModelUtils.isAvailable {
                    Divider()
                        .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Q&A")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        // Chat messages
                        if !messages.isEmpty {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        if isAnswering {
                            HStack {
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Input area
                        HStack {
                            TextField("Ask a question...", text: $questionText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Task {
                                            await askQuestion()
                                        }
                                    }
                                }
                                .disabled(isAnswering)
                            
                            Button("Ask") {
                                Task {
                                    await askQuestion()
                                }
                            }
                            .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnswering)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // Auto-generate summary if we have reader content but no summary yet
            if article.aiSummary == nil && article.readerMode?.content != nil && ModelUtils.isAvailable {
                Task {
                    await generateSummary()
                }
            }
        }
    }
    
    private func generateSummary() async {
        guard let readerContent = article.readerMode?.content else {
            loadingError = "No reader content available. Please switch to Reader Mode first."
            return
        }
        
        isLoading = true
        loadingError = nil
        
        do {
            let summary = try await ModelUtils.generateSummary(from: readerContent)
            self.updateSummary(summary)
        } catch {
            self.saveError(error)
        }
    }
    
    @MainActor
    private func updateSummary(_ summary: String) {
        article.aiSummary = summary
        isLoading = false
    }
    
    @MainActor
    private func saveError(_ error: Error) {
        loadingError = error.localizedDescription
        isLoading = false
    }
    
    private func askQuestion() async {
        guard let readerContent = article.readerMode?.content,
              !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.saveQuestion(question)
        
        do {
            let answer = try await ModelUtils.answer(content: readerContent, question: question)
            self.saveResponse(answer)
        } catch {
            self.saveResponse("Sorry, I couldn't answer your question: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func saveQuestion(_ question: String) {
        messages.append(ChatMessage(text: question, isUser: true))
        questionText = ""
        isAnswering = true
    }
    
    @MainActor
    private func saveResponse(_ response: String) {
        messages.append(ChatMessage(text: response, isUser: false))
        isAnswering = false
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
            } else {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.4))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                    .frame(maxWidth: .infinity * 0.8, alignment: .leading)
                Spacer()
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
    return ModelView(article: article)
        .frame(minWidth: 500, minHeight: 500)
}
