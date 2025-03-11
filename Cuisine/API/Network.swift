//
//  Network.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import SwiftUI

class NetworkService: NetworkServiceProtocol {
    private let baseURL: String
    private let session: URLSession
    
    private let malformedUrl = "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-malformed.json"
    private let emptyDataUrl = "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-empty.json"
    
    init(baseURL: String = "https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json",
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func fetchRecipes() async throws -> [Recipe] {
        guard let url = URL(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let recipeResponse = try JSONDecoder().decode(RecipeResponse.self, from: data)
            return recipeResponse.recipes
        } catch {
            throw NetworkError.decodingError
        }
    }
}

enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case invalidData
    case decodingError
    case serverError(statusCode: Int)
    
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.invalidData, .invalidData),
             (.decodingError, .decodingError):
            return true
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}

protocol NetworkServiceProtocol {
    func fetchRecipes() async throws -> [Recipe]
}
