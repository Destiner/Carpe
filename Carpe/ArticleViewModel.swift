//
//  ArticleViewModel.swift
//  Carpe
//
//  Created by Timur Badretdinov on 27/06/2025.
//

import Foundation
import SwiftUI
import WebKit

@Observable
@MainActor
final class ArticleViewModel {
    var page: WebPage
    var article: Article
    
    init(article: Article) {
        self.article = article
        self.page = WebPage()
    }
    
    func loadArticle() {
        page.load(URLRequest(url: article.url))
    }
    
    func updateArticle(_ newArticle: Article) {
        if article.id != newArticle.id {
            article = newArticle
            loadArticle()
        }
    }
}
