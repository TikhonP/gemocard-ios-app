//
//  GemocardController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 06.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

class CompletionStorage {
    public var getDeviceStatus: GetDeviceStatus?
}

enum GemocardDeviceControllerStatus {
    case unknown
    case getDeviceStatus
}

/// Implements steps and methods to communicate with Gemocard
class GemocardDeviceController {

    // MARK: - private vars
    
    private var status: GemocardDeviceControllerStatus = .unknown
    
    private var completionStorage = CompletionStorage()
    
    // Callbacks
    private let writeValueCallback: WriteValueCallback
    private let onProgressUpdate: OnProgressUpdate
    
    
    /// Initilize ``GemocardDeviceController`` store all callbacks
    /// - Parameters:
    ///   - writeValueCallback: function gets `Data` object and sends it to spirometer
    ///   - onProgressUpdate: push progress when data loading, from 0.0 to 1.0
    init(
        writeValueCallback: @escaping WriteValueCallback,
        onProgressUpdate: @escaping OnProgressUpdate
    ) {
        self.writeValueCallback = writeValueCallback
        self.onProgressUpdate = onProgressUpdate
    }
    
    // MARK: - Public functions
    
    public func onDataReceived(data: [UInt8]) {
        switch status {
        case .unknown:
            break;
        case .getDeviceStatus:
            let result = DataSerializer.deviceStatusDeserializer(bytes: data)
            completionStorage.getDeviceStatus!(result.deviceStatus, result.cuffPressure)
        }
    }
    
    public func getDeviceStatus(completion: @escaping GetDeviceStatus) {
        status = .getDeviceStatus
        completionStorage.getDeviceStatus = completion
        writeValueCallback(DataSerializer.deviceStatusQuery())
    }
}
