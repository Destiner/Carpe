//
//  ArticleView.swift
//  Carpe
//
//  Created by Timur Badretdinov on 27/06/2025.
//

import Foundation
import SwiftUI
import WebKit

struct ArticleView: View {
    let article: Article
    @State private var page = WebPage()
    @State private var scrollPosition = ScrollPosition()
    
    var body: some View {
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
            .ignoresSafeArea(.all, edges: .bottom)
    }
    
    private func loadPage(url: URL) async -> Void {
        if let pageData = article.pageData {
            page.load(pageData, mimeType: "text/html", characterEncoding: .utf8, baseURL: url)
        } else {
            page.load(URLRequest(url: url))
        }
        let isLoaded = await PageUtils.waitPageLoad(page: page, url: url)
        if (isLoaded) {
            let pageHeight = await PageUtils.getPageHeight(page: page)
            let pageState = article.pageState ?? PageState(height: 0, scrollY: 0)
            pageState.height = pageHeight ?? 0
            article.pageState = pageState
            
            scrollPosition.scrollTo(y: pageState.scrollY)
        }
    }
}
