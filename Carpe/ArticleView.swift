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
    
    var body: some View {
        WebView(page)
            .onAppear() {
                guard let pageData = article.pageData else {
                    page.load(URLRequest(url: article.url))
                    return
                }
                page.load(pageData, mimeType: "text/html", characterEncoding: .utf8, baseURL: article.url)
            }
            .onChange(of: article.url) { _, newURL in
                guard let pageData = article.pageData else {
                    page.load(URLRequest(url: newURL))
                    return
                }
                page.load(pageData, mimeType: "text/html", characterEncoding: .utf8, baseURL: newURL)
            }
            .ignoresSafeArea(.all, edges: .bottom)
    }
}
