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
    @State private var scrollPosition = ScrollPosition()
    
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
                    .webViewScrollPosition($scrollPosition)
                    .webViewOnScrollGeometryChange(for: CGFloat.self, of: \.contentOffset.y) { _, newValue in
                        if (newValue == 0) {
                            return
                        }
                        if let pageState = article.pageState {
                            article.pageState = PageState(height: pageState.height, scrollY: newValue)
                        }
                    }
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
            let eventId = readerPage.load(html: cachedHTML, baseURL: article.url)
            await waitForPageLoadAndUpdateState(page: readerPage, url: article.url, eventId: eventId)
            isLoading = false
            return
        }
        
        // Fallback to fetching content if no cached version
        do {
            let readerMode = try await PageUtils.extractReaderModeData(fromURL: article.url)
            
            // Load the styled HTML into our WebView
            if let html = readerMode.html {
                let eventId = readerPage.load(html: html, baseURL: article.url)
                await waitForPageLoadAndUpdateState(page: readerPage, url: article.url, eventId: eventId)
            }
            isLoading = false
            
            // Cache the result for future use
            article.readerMode = readerMode
        } catch {
            await MainActor.run {
                loadingError = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func waitForPageLoadAndUpdateState(page: WebPage, url: URL, eventId: WebPage.NavigationID?) async {
        let isLoaded = await PageUtils.waitPageLoad(page: page, url: url, eventId: eventId)
        if (!isLoaded) {
            return
        }
        let pageHeight = await PageUtils.getPageHeight(page: readerPage)
        let pageState = article.pageState ?? PageState(height: 0, scrollY: 0)
        pageState.height = pageHeight ?? 0
        article.pageState = pageState
        
        // Restore scroll position
        await MainActor.run {
            scrollPosition.scrollTo(y: pageState.scrollY)
        }
    }
}

#Preview {
    let article = Article(url: URL(string: "https://benanderson.work/blog/agentic-search-for-dummies/")!, title: "Sample Article")
    return ReaderView(article: article)
        .frame(minWidth: 500, minHeight: 500)
}
