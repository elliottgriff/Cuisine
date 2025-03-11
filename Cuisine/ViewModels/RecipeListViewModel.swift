//
//  RecipeListState.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import Foundation
import SwiftUI
import Combine

enum RecipeListState: Equatable {
    case idle
    case loading
    case loaded([Recipe])
    case empty
    case error(String)
    
    static func == (lhs: RecipeListState, rhs: RecipeListState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty):
            return true
        case (.loaded(let lhsRecipes), .loaded(let rhsRecipes)):
            return lhsRecipes.map { $0.id } == rhsRecipes.map { $0.id }
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

class RecipeListViewModel: ObservableObject {
    @Published var state: RecipeListState = .idle
    @Published var selectedFilter: FilterOption = .all
    @Published var filteredRecipes: [Recipe] = []
    
    private var allRecipes: [Recipe] = []
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService()) {
        self.networkService = networkService
        
        $selectedFilter
            .combineLatest($state)
            .map { filterOption, state -> [Recipe] in
                var recipes: [Recipe] = []
                if case .loaded(let loadedRecipes) = state {
                    recipes = loadedRecipes
                    self.allRecipes = loadedRecipes
                }
                
                if filterOption == .all {
                    return recipes
                } else {
                    return recipes.filter { $0.cuisine.lowercased() == filterOption.rawValue.lowercased() }
                }
            }
            .assign(to: &$filteredRecipes)
    }
    
    func updateAvailableFilterOptions() -> [FilterOption] {
        var options: [FilterOption] = [.all]
        
        let uniqueCuisines = Set(allRecipes.map { $0.cuisine })
        
        for cuisine in uniqueCuisines {
            if let option = FilterOption.allCases.first(where: { $0.rawValue.lowercased() == cuisine.lowercased() }) {
                options.append(option)
            } else if !cuisine.isEmpty {
                if !options.contains(.other) {
                    options.append(.other)
                }
            }
        }
        
        return options
    }
    
    @MainActor
    func loadRecipes() async {
        state = .loading
        
        do {
            let recipes = try await networkService.fetchRecipes()
            
            if recipes.isEmpty {
                state = .empty
            } else {
                state = .loaded(recipes)
                allRecipes = recipes
            }
        } catch {
            let errorMessage: String
            
            if let networkError = error as? NetworkError {
                switch networkError {
                case .invalidURL:
                    errorMessage = "Invalid URL"
                case .invalidResponse:
                    errorMessage = "Invalid response from server"
                case .invalidData:
                    errorMessage = "Invalid data received"
                case .decodingError:
                    errorMessage = "Could not decode the data. The data might be malformed."
                case .serverError(let statusCode):
                    errorMessage = "Server error: \(statusCode)"
                }
            } else {
                errorMessage = error.localizedDescription
            }
            
            state = .error(errorMessage)
        }
    }
    
    @MainActor
    func refreshRecipes() async {
        await loadRecipes()
    }
}
