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

enum ViewMode: CaseIterable {
    case web, reader, ai

    var buttonTitle: String {
        switch self {
        case .web: return "Reader Mode"
        case .reader: return ModelUtils.isAvailable ? "AI Mode" : "Web View"
        case .ai: return "Web View"
        }
    }

    var systemImage: String {
        switch self {
        case .web: return "doc.text"
        case .reader: return ModelUtils.isAvailable ? "sparkles" : "safari"
        case .ai: return "safari"
        }
    }

    func next() -> ViewMode {
        switch self {
        case .web: return .reader
        case .reader: return ModelUtils.isAvailable ? .ai : .web
        case .ai: return .web
        }
    }
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
                    viewMode = viewMode.next()
                }) {
                    Label(
                        viewMode.buttonTitle,
                        systemImage: viewMode.systemImage
                    )
                }
            }
        }
    }
    
    private func loadPage(url: URL) async {
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
