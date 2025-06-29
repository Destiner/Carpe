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

struct ArticleView: View {
    let article: Article
    @State private var page = WebPage()
    @State private var scrollPosition = ScrollPosition()
    @State private var isReaderMode = false
    
    var body: some View {
        Group {
            if isReaderMode {
                ReaderView(article: article)
            } else {
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
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    isReaderMode.toggle()
                }) {
                    Label(
                        isReaderMode ? "Web View" : "Reader Mode",
                        systemImage: isReaderMode ? "safari" : "doc.text"
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
