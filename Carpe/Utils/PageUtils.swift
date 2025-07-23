//
//  PageUtils.swift
//  Carpe
//
//  Created by Timur Badretdinov on 28/06/2025.
//

import Foundation
import WebKit
import Reeeed

@MainActor
class PageUtils {
    // TODO rewrite with Observations
    static func waitPageLoad(page: WebPage, url: URL, eventId: WebPage.NavigationID?) async -> Bool {
        var event = page.currentNavigationEvent
        while (true) {
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                print("Sleep failed")
            }
            event = page.currentNavigationEvent
            if (event?.navigationID != eventId) {
                continue
            }
            switch (event?.kind) {
            case .failed(_):
                return false
            case .finished:
                return true
            default:
                continue
            }
        }
    }
    
    static func getPageCoverImage(page: WebPage) async -> String? {
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
    
    static func getPageHeight(page: WebPage) async -> Double? {
        let heightScript = """
            return document.body.scrollHeight
            """
        
        let height = try? await page.callJavaScript(heightScript) as? Double
        return height
    }
    
    static func extractReaderModeData(fromURL url: URL) async throws -> PageReaderMode {
        let result = try await Reeeed.fetchAndExtractContent(fromURL: url)
        let html = result.html(includeExitReaderButton: false)
        
        return PageReaderMode(
            title: result.title,
            author: result.extracted.author,
            excerpt: result.extracted.excerpt,
            content: result.extracted.extractPlainText,
            html: html
        )
    }
}
