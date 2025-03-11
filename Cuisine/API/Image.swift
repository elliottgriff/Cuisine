//
//  ImageCacheServiceProtocol.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import Foundation
import UIKit
import SwiftUI

protocol ImageCacheServiceProtocol {
    func loadImage(from urlString: String) async throws -> UIImage
    func clearCache()
}

class ImageCacheService: ImageCacheServiceProtocol {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let session: URLSession
    
    init(cacheDirectory: URL? = nil, session: URLSession = .shared) {
        if let cacheDirectory = cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let cacheDirectoryURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = cacheDirectoryURL.appendingPathComponent("RecipeImageCache")
        }
        
        self.session = session
        
        if !fileManager.fileExists(atPath: self.cacheDirectory.path) {
            try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    func loadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let fileName = String(urlString.hash)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        guard let image = UIImage(data: data) else {
            throw NetworkError.invalidData
        }
        
        try? data.write(to: fileURL)
        
        return image
    }
    
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

struct AsyncImageView: View {
    let urlString: String?
    let placeholderSystemName: String
    @StateObject private var imageLoader = ImageLoader()
    
    init(urlString: String?, placeholderSystemName: String = "photo") {
        self.urlString = urlString
        self.placeholderSystemName = placeholderSystemName
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if imageLoader.isLoading {
                ProgressView()
            } else {
                Image(systemName: placeholderSystemName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .onAppear {
            if let urlString = urlString {
                imageLoader.loadImage(from: urlString)
            }
        }
        .onChange(of: urlString) { newValue, _ in
            if let newUrlString = newValue {
                imageLoader.loadImage(from: newUrlString)
            } else {
                imageLoader.cancel()
            }
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    private var cancellable: Task<Void, Never>?
    private let imageCacheService = ImageCacheService()
    
    func loadImage(from urlString: String) {
        guard !isLoading else { return }
        
        cancellable?.cancel()
        isLoading = true
        
        cancellable = Task {
            do {
                let loadedImage = try await imageCacheService.loadImage(from: urlString)
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Failed to load image: \(error)")
            }
        }
    }
    
    func cancel() {
        cancellable?.cancel()
        cancellable = nil
        isLoading = false
    }
    
    deinit {
        cancel()
    }
}
