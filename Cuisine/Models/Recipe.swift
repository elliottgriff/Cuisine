//
//  RecipeResponse.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import Foundation

struct RecipeResponse: Decodable {
    let recipes: [Recipe]
}

struct Recipe: Identifiable, Decodable, Equatable {
    let cuisine: String
    let name: String
    let photoUrlLarge: String?
    let photoUrlSmall: String?
    let uuid: String
    let sourceUrl: String?
    let youtubeUrl: String?
    
    var id: String { uuid }
    
    enum CodingKeys: String, CodingKey {
        case cuisine
        case name
        case photoUrlLarge = "photo_url_large"
        case photoUrlSmall = "photo_url_small"
        case uuid
        case sourceUrl = "source_url"
        case youtubeUrl = "youtube_url"
    }
    
    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
