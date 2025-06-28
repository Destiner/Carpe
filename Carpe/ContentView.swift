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
        
        // Extract title from HTML
        Task {
            if let title = await extractTitle(from: url) {
                await MainActor.run {
                    article.title = title
                }
            }
        }
        
        // Save for offline use
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
                case let .failed(_):
                    return
                case .finished:
                    article.pageData = try? await page.webArchiveData()
                    return
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
    
    private func extractTitle(from url: URL) async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            // Parse title tag
            let titlePattern = #"<title[^>]*>(.*?)</title>"#
            let regex = try NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let range = NSRange(html.startIndex..., in: html)
            
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let titleRange = Range(match.range(at: 1), in: html) {
                let title = String(html[titleRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"&amp;"#, with: "&")
                    .replacingOccurrences(of: #"&lt;"#, with: "<")
                    .replacingOccurrences(of: #"&gt;"#, with: ">")
                    .replacingOccurrences(of: #"&quot;"#, with: "\"")
                    .replacingOccurrences(of: #"&#39;"#, with: "'")
                return title.isEmpty ? nil : title
            }
        } catch {
            print("Error extracting title: \(error)")
        }
        return nil
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .foregroundStyle(isRead ? .secondary : .primary)
                        Text(item.url.absoluteString)
                            .foregroundStyle(.secondary)
                            .font(.caption)
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
