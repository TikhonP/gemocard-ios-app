//
//  UserDefaults+AppPrefs.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 04.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

/// Extention for quick accsess to UserDefault information
extension UserDefaults {
    private enum Keys {
        static let savedGemocardUUIDkey = "savedGemocardUUID"
        static let saveUUIDkey = "saveUUID"
    }
    
    class var savedGemocardUUID: String? {
        get {
            return UserDefaults.standard.string(forKey: Keys.savedGemocardUUIDkey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.savedGemocardUUIDkey)
        }
    }
    
    class var saveUUID: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.saveUUIDkey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.saveUUIDkey)
        }
    }
    
    class func registerDefaultValues() {
        UserDefaults.standard.register(defaults: [
            Keys.saveUUIDkey: true,
        ])
    }
}
