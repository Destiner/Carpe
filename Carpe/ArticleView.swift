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
    @Environment(ArticleViewModel.self) private var model
    
    var body: some View {
        WebView(model.page)
            .onAppear() {
                model.loadArticle()
            }
            .onChange(of: model.article) { _, _ in
                model.loadArticle()
            }
            .ignoresSafeArea(.all, edges: .bottom)
    }
}
