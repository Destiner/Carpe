//
//  Item.swift
//  Carpe
//
//  Created by Timur Badretdinov on 27/06/2025.
//

import Foundation
import SwiftData

@Model
class PageState {
    var height: Double
    var scrollY: Double
    
    init(height: Double, scrollY: Double) {
        self.height = height
        self.scrollY = scrollY
    }
}

@Model
class PageReaderMode {
    var title: String?
    var author: String?
    var excerpt: String?
    var content: String?
    var html: String?
    
    init(title: String? = nil, author: String? = nil, excerpt: String? = nil, content: String? = nil, html: String? = nil) {
        self.title = title
        self.author = author
        self.excerpt = excerpt
        self.content = content
        self.html = html
    }
}

@Model
final class Article {
    var url: URL
    var title: String
    var pageData: Data?
    var coverImageUrl: String?
    var pageState: PageState?
    var readerMode: PageReaderMode?
    var aiSummary: String?
    var createdAt: Date
    var readAt: Date?
    
    init(url: URL, title: String) {
        self.url = url
        self.title = title
        self.createdAt = .now
    }
    
    func read() {
        self.readAt = .now
    }
    
    func unread() {
        self.readAt = nil
    }
}
