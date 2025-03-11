//
//  CuisineApp.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import SwiftUI

@main
struct CuisineApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
