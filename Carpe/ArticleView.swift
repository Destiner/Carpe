//
//  ArticleView.swift
//  Carpe
//
//  Created by Timur Badretdinov on 27/06/2025.
//

import Foundation
import SwiftUI
import WebKit
import Reeeed
import FoundationModels

enum ViewMode {
    case web, reader, ai
}

struct ArticleView: View {
    let article: Article
    @State private var page = WebPage()
    @State private var scrollPosition = ScrollPosition()
    @State private var viewMode: ViewMode = .web
    
    var body: some View {
        Group {
            switch viewMode {
            case .web:
                WebView(page)
                    .onAppear() {
                        Task {
                            await loadPage(url: article.url)
                        }
                    }
                    .onChange(of: article.url) { _, newURL in
                        Task {
                            await loadPage(url: newURL)
                        }
                    }
                    .webViewScrollPosition($scrollPosition)
                    .webViewOnScrollGeometryChange(for: CGFloat.self, of: \.contentOffset.y) { _, newValue in
                        if (newValue == 0) {
                            return
                        }
                        if let pageState = article.pageState {
                            article.pageState = PageState(height: pageState.height, scrollY: newValue)
                        }
                    }
            case .reader:
                ReaderView(article: article)
            case .ai:
                AIView(article: article)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    switch viewMode {
                    case .web:
                        viewMode = .reader
                    case .reader:
                        viewMode = ModelUtils.isAvailable ? .ai : .web
                    case .ai:
                        viewMode = .web
                    }
                }) {
                    Label(
                        viewMode == .web ? "Reader Mode" : viewMode == .reader ? (ModelUtils.isAvailable ? "AI Mode" : "Web View") : "Web View",
                        systemImage: viewMode == .web ? "doc.text" : viewMode == .reader ? (ModelUtils.isAvailable ? "sparkles" : "safari") : "safari"
                    )
                }
            }
        }
    }
    
    private func loadPage(url: URL) async -> Void {
        var eventId: WebPage.NavigationID? = nil
        if let pageData = article.pageData {
            eventId = page.load(pageData, mimeType: "text/html", characterEncoding: .utf8, baseURL: url)
        } else {
            eventId = page.load(URLRequest(url: url))
        }
        let isLoaded = await PageUtils.waitPageLoad(page: page, url: url, eventId: eventId)
        if (isLoaded) {
            let pageHeight = await PageUtils.getPageHeight(page: page)
            let pageState = article.pageState ?? PageState(height: 0, scrollY: 0)
            pageState.height = pageHeight ?? 0
            article.pageState = pageState
            
            scrollPosition.scrollTo(y: pageState.scrollY)
        }
    }
}
