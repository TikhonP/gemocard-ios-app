//
//  ComplitionType.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 06.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation
import CoreBluetooth

// MARK: - GemocardSDK completions

/// Status update callback with ``CompletionCodes`` status
/// - Parameter completionCode: tatus codes for different events situations
typealias GemocardStatusUpdateCallback = (_ completionCode: CompletionCodes) -> Void

/// Callback for discovered devices after call `GemocardSDK.discover()`
/// - Parameters:
///   - peripheral: A `CBPeripheral` object.
///   - advertisementData: A dictionary containing any advertisement and scan response data.
///   - RSSI: The current RSSI of _peripheral_, in dBm. A value of `127` is reserved and indicates the RSSI
typealias OnDiscoverCallback = (_ peripheral: CBPeripheral, _ advertisementData: [String : Any], _ RSSI: NSNumber) -> Void

/// Progress status from 0.0 to 1.0
/// - Parameter progress: Float value from `0.0` to `1.0`
typealias OnProgressUpdate = (_ progress: Float) -> Void

// MARK: - GemocardController callbacks

/// Send data to device
/// - Parameter data: `Data` object to send
typealias WriteValueCallback = (_ data: Data) -> Void

// MARK: - GemocardController commands completions

/// Device status completion
/// - Parameters:
///  - deviceStatus: Current device status mode
///  - cuffPressure: Current cuff oreasure
typealias GetDeviceStatus = (_ deviceStatus: DeviceStatus, _ cuffPressure: UInt16) -> Void
