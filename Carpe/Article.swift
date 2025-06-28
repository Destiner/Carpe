//
//  Item.swift
//  Carpe
//
//  Created by Timur Badretdinov on 27/06/2025.
//

import Foundation
import SwiftData

@Model
final class Article {
    var url: URL
    var title: String
    var pageData: Data?
    var coverImageUrl: String?
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
