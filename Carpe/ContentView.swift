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
                ArticleSection(
                    title: "To Read",
                    articles: unreadArticles,
                    isExpanded: $unreadExpanded,
                    isRead: false,
                    onDelete: deleteUnreadItems
                )
                
                ArticleSection(
                    title: "Read",
                    articles: readArticles,
                    isExpanded: $readExpanded,
                    isRead: true,
                    onDelete: deleteReadItems
                )
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
            var event = page.currentNavigationEvent
            while (true) {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                event = page.currentNavigationEvent
                if (event?.navigationID != id) {
                    continue
                }
                switch (event?.kind) {
                case .failed(_):
                    return
                case .finished:
                    article.title = page.title
                    article.coverImageUrl = await getPageCoverImage(page: page)
                    // Store page data for offline use
                    article.pageData = try? await page.webArchiveData()
                default:
                    continue
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
    
    private func getPageCoverImage(page: WebPage) async -> String? {
        // Extract cover image using JavaScript
        let coverImageScript = """
            // Try og:image first
            let ogImage = document.querySelector('meta[property="og:image"]');
            if (ogImage && ogImage.content) {
                return ogImage.content;
            }
            
            // Fallback to twitter:image
            let twitterImage = document.querySelector('meta[name="twitter:image"]');
            if (twitterImage && twitterImage.content) {
                return twitterImage.content;
            }
            
            // Fallback to twitter:image:src
            let twitterImageSrc = document.querySelector('meta[name="twitter:image:src"]');
            if (twitterImageSrc && twitterImageSrc.content) {
                return twitterImageSrc.content;
            }
            
            return null;
        """
        
        let coverImageUrl = try? await page.callJavaScript(coverImageScript) as? String
        return coverImageUrl
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

struct URLInputModal: View {
    @Binding var savedURL: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputURL: String = ""
    @State private var isValidURL: Bool = true
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter Web Page URL")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField("https://example.com", text: $inputURL)
                        .textFieldStyle(.roundedBorder)
#if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
#endif
                        .autocorrectionDisabled()
                        .onChange(of: inputURL) { _, newValue in
                            validateURL(newValue)
                        }
                    
                    if !isValidURL {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: 15) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Add URL") {
                        if isValidURL && !inputURL.isEmpty {
                            savedURL = inputURL
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!isValidURL || inputURL.isEmpty)
                }
            }
            .padding()
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .navigationBarBackButtonHidden()
        }
    }
    
    private func validateURL(_ urlString: String) {
        guard !urlString.isEmpty else {
            isValidURL = true
            errorMessage = ""
            return
        }
        
        // Add protocol if missing
        var processedURL = urlString
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            processedURL = "https://" + urlString
        }
        
        if let url = URL(string: processedURL),
           url.scheme != nil,
           url.host != nil {
            isValidURL = true
            errorMessage = ""
            inputURL = processedURL // Update with proper protocol
        } else {
            isValidURL = false
            errorMessage = "Please enter a valid URL"
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
