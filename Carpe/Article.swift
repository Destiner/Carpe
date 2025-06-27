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
    var createdAt: Date
    
    init(url: URL, title: String) {
        self.url = url
        self.title = title
        self.createdAt = .now
    }
}
