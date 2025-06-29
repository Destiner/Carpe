//
//  ContentView.swift
//  Carpe
//
//  Created by Timur Badretdinov on 27/06/2025.
//

import SwiftUI
import SwiftData
import WebKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [Article]
    
    @State private var showAlert = false
    @State private var urlString = ""
    @State private var unreadExpanded = true
    @State private var readExpanded = false

    var body: some View {
        NavigationSplitView {
            List {
                if !unreadArticles.isEmpty {
                    ArticleSection(
                        title: "To Read",
                        articles: unreadArticles,
                        isExpanded: $unreadExpanded,
                        isRead: false,
                        onDelete: deleteUnreadItems
                    )
                }
                
                if !readArticles.isEmpty {
                    ArticleSection(
                        title: "Read",
                        articles: readArticles,
                        isExpanded: $readExpanded,
                        isRead: true,
                        onDelete: deleteReadItems
                    )
                }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        showAlert = true
                    }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .alert("Add new article", isPresented: $showAlert) {
                // Text field
                TextField("https://example.com", text: $urlString)
#if os(iOS)
                    .keyboardType(.URL)
#endif
#if os(macOS)
                    .textContentType(NSTextContentType.URL)
#endif
                
                Button("Cancel", role: .cancel) { urlString = "" }
                Button("Add", action: addURL)
                    .disabled(!isValidURL)
            }
        } detail: {
            Text("Select an item")
        }
    }
    
    private func addURL() {
        guard let url = URL(string: urlString) else {
            return
        }
        let article = Article(url: url, title: "Loading…")
        modelContext.insert(article)
        
        // Save for offline use and extract metadata
        Task {
            let page = WebPage()
            let id = page.load(URLRequest(url: article.url))
            let isLoaded = await PageUtils.waitPageLoad(page: page, url: article.url, eventId: id)
            if (isLoaded) {
                article.title = page.title
                article.coverImageUrl = await PageUtils.getPageCoverImage(page: page)

                // Store page data for offline use
                article.pageData = try? await page.webArchiveData()
                
                // Extract and store reader mode data
                do {
                    article.readerMode = try await PageUtils.extractReaderModeData(fromURL: article.url)
                    
                    // Use reader mode title if available and better than page title
                    if let readerTitle = article.readerMode?.title, !readerTitle.isEmpty {
                        article.title = readerTitle
                    }
                } catch {
                    print("Failed to extract reader mode content: \(error)")
                }
            }
        }
        
        urlString = ""
    }
    
    private var unreadArticles: [Article] {
        articles
            .filter { $0.readAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var readArticles: [Article] {
        articles
            .filter { $0.readAt != nil }
            .sorted { $0.readAt! > $1.readAt! }
    }
    
    private var isValidURL: Bool {
        URL(string: urlString)?.scheme?.hasPrefix("http") == true
    }

    private func deleteUnreadItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(unreadArticles[index])
            }
        }
    }
    
    private func deleteReadItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(readArticles[index])
            }
        }
    }
}

struct ArticleSection: View {
    let title: String
    let articles: [Article]
    @Binding var isExpanded: Bool
    let isRead: Bool
    let onDelete: (IndexSet) -> Void
    
    @State var viewHeight: Double = 0
    
    var body: some View {
        Section(isExpanded: $isExpanded) {
            ForEach(articles) { item in
                NavigationLink {
                    ArticleView(article: item)
                        .toolbar {
                            ToolbarItem {
                                Button(action: {
                                    if isRead {
                                        item.unread()
                                    } else {
                                        item.read()
                                    }
                                }) {
                                    Label(
                                        isRead ? "Mark as Unread" : "Mark as Read",
                                        systemImage: isRead ? "circle" : "checkmark.circle"
                                    )
                                }
                            }
                        }
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { _, newValue in
                            viewHeight = newValue
                        }
                } label: {
                    HStack(spacing: 12) {
                        if let coverImageUrl = item.coverImageUrl {
                            AsyncImage(url: URL(string: coverImageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .foregroundStyle(isRead ? .secondary : .primary)
                                .lineLimit(2)
                            Text(item.url.absoluteString)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if let pageState = item.pageState {
                            let progress = (pageState.scrollY + viewHeight) / pageState.height
                            CircularProgressView(progress: progress, size: 16)
                        }
                    }
                }
            }
            .onDelete(perform: onDelete)
        } header: {
            HStack {
                Text(title)
            }
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 0.98 ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Article.self, configurations: config)
    
    guard let articleAUrl = URL(string: "https://zed.dev/blog/software-craftsmanship-in-the-era-of-vibes") else {
        return ContentView()
            .modelContainer(for: Article.self, inMemory: true)
    }
    let articleA = Article(url: articleAUrl, title: "The Case for Software Craftsmanship in the Era of Vibes")
    
    guard let articleBUrl = URL(string: "https://www.anthropic.com/engineering/building-effective-agents") else {
        return ContentView()
            .modelContainer(for: Article.self, inMemory: true)
    }
    let articleB = Article(url: articleBUrl, title: "Building effective agents")
    
    guard let articleCUrl = URL(string: "https://supermemory.ai/blog/memory-engine/") else {
        return ContentView()
            .modelContainer(for: Article.self, inMemory: true)
    }
    let articleC = Article(url: articleCUrl, title: "Architecting a memory engine inspired by the human brain")
    
    container.mainContext.insert(articleA)
    container.mainContext.insert(articleB)
    container.mainContext.insert(articleC)
    
    return ContentView()
        .modelContainer(container)
}
