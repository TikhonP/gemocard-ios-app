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
    
    init() {
        UserDefaults.registerDefaultValues()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
