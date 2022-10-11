//
//  App.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 04.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI

@main
struct Medsenger_GemocardApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        UserDefaults.registerDefaultValues()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
