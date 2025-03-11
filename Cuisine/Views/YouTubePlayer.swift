//
//  YouTubePlayer.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import SwiftUI
import WebKit

struct YouTubePlayer: UIViewRepresentable {
    let videoURL: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: videoURL)
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = """
            var meta = document.createElement('meta');
            meta.setAttribute('name', 'viewport');
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
            document.getElementsByTagName('head')[0].appendChild(meta);
            """
            webView.evaluateJavaScript(script)
        }
    }
}

struct YouTubePlayerView: View {
    let youtubeURLString: String?
    
    var body: some View {
        if let urlString = youtubeURLString, let videoURL = extractYouTubeEmbedURL(from: urlString) {
            YouTubePlayer(videoURL: videoURL)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(12)
                .shadow(radius: 4)
        } else {
            noVideoView
        }
    }
    
    private var noVideoView: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray6))
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(12)
            
            VStack(spacing: 8) {
                Image(systemName: "video.slash")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                
                Text("No video available")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func extractYouTubeEmbedURL(from urlString: String) -> URL? {
        if urlString.contains("youtube.com/embed") {
            return URL(string: urlString)
        }
        
        let patterns = [
            "(?:youtube\\.com/watch\\?v=|youtu\\.be/)([a-zA-Z0-9_-]{11})",
            "youtube\\.com/embed/([a-zA-Z0-9_-]{11})",
            "youtube\\.com/v/([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)) {
                if let range = Range(match.range(at: 1), in: urlString) {
                    let videoID = String(urlString[range])
                    return URL(string: "https://www.youtube.com/embed/\(videoID)")
                }
            }
        }
        
        return URL(string: urlString)
    }
}
