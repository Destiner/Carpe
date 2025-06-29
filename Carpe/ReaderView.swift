//
//  CustomReaderView.swift
//  Carpe
//
//  Created by Timur Badretdinov on 29/06/2025.
//

import SwiftUI
import WebKit

struct ReaderView: View {
    let article: Article
    
    @State private var readerPage = WebPage()
    @State private var isLoading = true
    @State private var loadingError: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading reader mode...")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            } else if let error = loadingError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Failed to load reader mode")
                        .font(.headline)
                        .padding(.top, 8)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                WebView(readerPage)
            }
        }
        .onAppear {
            Task {
                await loadReaderContent()
            }
        }
        .onChange(of: article.url) { _, newURL in
            Task {
                await loadReaderContent()
            }
        }
    }
    
    private func loadReaderContent() async {
        isLoading = true
        loadingError = nil
        
        // First try to use cached reader mode data
        if let readerMode = article.readerMode, let cachedHTML = readerMode.html {
            await MainActor.run {
                readerPage.load(html: cachedHTML, baseURL: article.url)
                isLoading = false
            }
            return
        }
        
        // Fallback to fetching content if no cached version
        do {
            let readerMode = try await PageUtils.extractReaderModeData(fromURL: article.url)
            
            await MainActor.run {
                // Load the styled HTML into our WebView
                if let html = readerMode.html {
                    readerPage.load(html: html, baseURL: article.url)
                }
                isLoading = false
                
                // Cache the result for future use
                article.readerMode = readerMode
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
    let article = Article(url: URL(string: "https://benanderson.work/blog/agentic-search-for-dummies/")!, title: "Sample Article")
    return ReaderView(article: article)
        .frame(minWidth: 500, minHeight: 500)
}
