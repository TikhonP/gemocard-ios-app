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
        static let lastSyncedDateKey = "lastSyncedDate"
        static let medsengerContractIdKey = "medsengerContractId"
        static let medsengerAgentTokenKey = "medsengerAgentToken"
        static let lastMedsengerUploadedDateKey = "lastMedsengerUploadedDate"
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
    
    class var lastSyncedDateKey: Date? {
        get {
            return UserDefaults.standard.object(forKey: Keys.lastSyncedDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lastSyncedDateKey)
        }
    }
    
    class var medsengerContractId: Int? {
        get {
            return UserDefaults.standard.integer(forKey: Keys.medsengerContractIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.medsengerContractIdKey)
        }
    }
    
    class var medsengerAgentToken: String? {
        get {
            return UserDefaults.standard.string(forKey: Keys.medsengerAgentTokenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.medsengerAgentTokenKey)
        }
    }
    
    class var lastMedsengerUploadedDate: Date? {
        get {
            return UserDefaults.standard.object(forKey: Keys.lastMedsengerUploadedDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lastMedsengerUploadedDateKey)
        }
    }
    
    class func registerDefaultValues() {
        UserDefaults.standard.register(defaults: [
            Keys.saveUUIDkey: true,
        ])
    }
}
