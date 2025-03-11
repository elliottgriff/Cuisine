//
//  FilterOption.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import SwiftUI

enum FilterOption: String, CaseIterable, Identifiable {
    case all = "All Cuisines"
    case italian = "Italian"
    case mexican = "Mexican"
    case asian = "Asian"
    case french = "French"
    case american = "American"
    case indian = "Indian"
    case mediterranean = "Mediterranean"
    case middleEastern = "Middle Eastern"
    case british = "British"
    case japanese = "Japanese"
    case thai = "Thai"
    case spanish = "Spanish"
    case greek = "Greek"
    case other = "Other"
    
    var id: String { self.rawValue }
}
