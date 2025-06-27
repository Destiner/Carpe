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
                page.load(URLRequest(url: article.url))
            }
            .onChange(of: article.url) { _, newURL in
                page.load(URLRequest(url: newURL))
            }
            .ignoresSafeArea(.all, edges: .bottom)
    }
}
