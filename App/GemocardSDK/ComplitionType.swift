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

/// Callback for gemocard controller failure
/// - Parameter failureCode: error code
typealias OnFailure = (_ failureCode: FailureCodes) -> Void

/// Device status completion
/// - Parameters:
///  - deviceStatus: Current device status mode
///  - cuffPressure: Current cuff oreasure
typealias GetDeviceStatusCompletion = (_ deviceStatus: DeviceStatus, _ deviceOperatingMode: DeviceOperatingMode, _ cuffPressure: UInt16) -> Void

/// Get device datetimne completion
/// - Parameter date: optional datetime
typealias GetDateAndTimeFromDeviceCompletion = (_ date: Date?) -> Void

/// Get nukmber of measurements in device memory completion
/// - Parameter measurementsCount: number of measuremnts
typealias GetNumberOfMeasurementsInDeviceMemoryCompletion = (_ measurementsCount: Int) -> Void

/// Get data completion
/// - Parameter data: array of packets
typealias GetDataCompletion = (_ data: [GetDataModel]) -> Void

/// Get header results N previous measurent
/// - Parameter measurementHeaderResult: measurement headers results struct
typealias GetHeaderResultsNumberOfPreviousMeasurementCompletion = (_ measurementHeaderResult: MeasurementHeaderResult) -> Void

/// Get results N previous measurent
/// - Parameter measurementResult: measurement results struct
typealias GetResultsNumberOfPreviousMeasurementCompletion = (_ measurementResult: MeasurementResult) -> Void

/// Get ECG completion
/// - Parameters:
///  - ECGdata: array of ecg
///  - ECGStatusData: array of ``BrokenElectrodesAndPacemaker``
typealias GetECGCompletion = (_ ECGdata: [UInt32], _ ECGStatusData: [UInt8]) -> Void

/// Get setted value of packets count
/// - Parameter packetCount: packet count
typealias RequestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGCompletion = (_ packetCount: UInt8) -> Void
