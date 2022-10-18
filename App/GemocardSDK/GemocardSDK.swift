//
//  GemocardSDK.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 04.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Status codes for different events situations
enum CompletionCodes {
    case bluetoothIsOff
    case bluetoothIsOn
    case periferalIsNotFromThisQueue
    case disconnected
    case failedToDiscoverServiceError
    case periferalIsNotReady
    case connected
    case failedToConnect
}

/// Gemocard UUIDs for using with GATT services and
private struct GemocardUUIDs {
    static let service = CBUUID.init(string: "ffe0")
    static let characteristic = CBUUID.init(string: "ffe1")
}

/// Main Gemocard controller class
class GemocardSDK: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    
    // MARK: - Private Varibles
    
    private let completion: GemocardStatusUpdateCallback
    private let onDiscoverCallback: OnDiscoverCallback
    
    private var centralManager: CBCentralManager?
    private var isCentralManagerReady: Bool = false
    
    private var peripheral: CBPeripheral!
    private var isPeriferalReady: Bool = false
    
    private var characteristic: CBCharacteristic!
    
    private var gemocardDeviceController: GemocardDeviceController!
    
    public var deviceStatus: DeviceStatus?
    public var deviceOperatingMode: DeviceOperatingMode?
    public var cuffPressure: UInt16?
    
    /// Initialization of ``GemocardSDK`` class
    /// - Parameters:
    ///   - completion: update status callback for differrent events
    ///   - onDiscoverCallback: on device discover push to display it in view list
    ///   - onProgressUpdate: update progress number
    init (
        completion: @escaping GemocardStatusUpdateCallback,
        onDiscoverCallback: @escaping OnDiscoverCallback
    ) {
        self.completion = completion
        self.onDiscoverCallback = onDiscoverCallback
    }
    
    // MARK: - Private Methods
    
    private func checkIsSentralManagerReady(completion: () -> Void) {
        if isCentralManagerReady {
            completion()
        } else {
            self.completion(.bluetoothIsOff)
        }
    }
    
    private func checkIfPeripheralReady(completion: () -> Void) {
        if isPeriferalReady {
            completion()
        } else {
            self.completion(.periferalIsNotReady)
        }
    }
    
    // MARK: - Public Methods
    
    // MARK: BLE Controls
    
    /// Start BLE devices discovering
    ///
    /// Discovered devices with type `CBPeripheral` will be go
    /// to `onDiscoverCallback` mentioned in `init(onSuccessCallback:onDiscoverCallback:onFailCallback:)`
    public func discover() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /// Stop BLE devices discovering
    public func stopDiscover() {
        checkIsSentralManagerReady() {
            centralManager!.stopScan()
        }
    }
    
    /// Connect to suggested peripheral
    /// - Parameter peripheral: BLE devices from discovered device callback
    public func connect(_ peripheral: CBPeripheral) {
        checkIsSentralManagerReady() {
            centralManager!.stopScan()
            self.peripheral = peripheral
            self.peripheral.delegate = self
            centralManager!.connect(self.peripheral, options: nil)
            gemocardDeviceController = GemocardDeviceController(writeValueCallback: sendData)
        }
    }
    
    /// Disconnect peripheral
    public func disconnect() {
        checkIfPeripheralReady() {
            checkIsSentralManagerReady() {
                centralManager!.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    // MARK: - Gemocard Controls: Get Data
    
    public func getDeviceStatus(completion: @escaping GetDeviceStatusCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.getDeviceStatus(completion: completion, оnFailure: оnFailure)
        }
    }
    
    public func getDeviceDateTime(completion: @escaping GetDateAndTimeFromDeviceCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.getDeviceDateTime(completion: completion, оnFailure: оnFailure)
        }
    }
    
    public func getNumberOfMeasurementsArterialPressure(completion: @escaping GetNumberOfMeasurementsInDeviceMemoryCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.getNumberOfMeasurementsArterialPressureInDeviceMemory(completion: completion, оnFailure: оnFailure)
        }
    }
    
    public func getNumberOfMeasurements(completion: @escaping GetNumberOfMeasurementsInDeviceMemoryCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.getNumberOfMeasurementsInDeviceMemory(completion: completion, оnFailure: оnFailure)
        }
    }
    
    public func getEcgMeasurementHeader(measurementNumber: UInt8, completion: @escaping GetMeasurementHeaderCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.getMeasurementHeader(measurementNumber: measurementNumber, completion: completion, оnFailure: оnFailure)
        }
    }
    
    public func getMeasurementArterialPressure(measurementNumber: UInt16, completion: @escaping GetResultsNumberOfPreviousMeasurementCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.getMeasurementArterialPressure(measurementNumber: measurementNumber, completion: completion, оnFailure: оnFailure)
        }
    }
    
    public func getECG(ECGnumber: UInt8, completion: @escaping GetECGCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.getECG(ECGnumber: ECGnumber, completion: completion, оnFailure: оnFailure)
        }
    }
    
    // MARK: - Gemocard Controls: Set Commands
    
    public func eraseMemory(completion: @escaping CommandDoneCompletion, оnFailure: @escaping OnFailure) {
        checkIfPeripheralReady() {
            gemocardDeviceController.eraseMemory(completion: completion, оnFailure: оnFailure)
        }
    }
    
    // MARK: - private functions for ``GeamocardDeviceController usage
    
    private func sendData(_ data: Data) {
//        print("SEND DATA (UInt8): \(data.bytes)")
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    // MARK: - Central Manager Callbacks
    
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            completion(.bluetoothIsOff)
        } else {
            completion(.bluetoothIsOn)
            isCentralManagerReady = true
            centralManager!.scanForPeripherals(withServices: [GemocardUUIDs.service], options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        }
    }
    
    internal func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        onDiscoverCallback(peripheral, advertisementData, RSSI)
    }
    
    internal func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == self.peripheral {
            peripheral.discoverServices([GemocardUUIDs.service])
        } else {
            completion(.periferalIsNotFromThisQueue)
        }
    }
    
    internal func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        isPeriferalReady = false
        
        completion(.disconnected)
        
        guard error == nil else {
            print("Failed to disconnect from peripheral \(peripheral), error: \(error?.localizedDescription ?? "no error description")")
            return
        }
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Failed to discover services, error: \(error?.localizedDescription ?? "failed to obtain error description")")
            completion(.failedToDiscoverServiceError)
            return
        }
        
        if let services = peripheral.services {
            for service in services {
                if service.uuid == GemocardUUIDs.service {
                    peripheral.discoverCharacteristics([GemocardUUIDs.characteristic], for: service)
                }
            }
        }
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Failed to discover characteristics for service \(service.uuid), error: \(error?.localizedDescription ?? "no error description")")
            return
        }
        
        guard let discoveredCharacteristics = service.characteristics else {
            print("peripheralDidDiscoverCharacteristics called for empty characteristics for service \(service.uuid)")
            return
        }
        
        for characteristic in discoveredCharacteristics {
            if characteristic.uuid == GemocardUUIDs.characteristic {
                
                self.characteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.gemocardDeviceController.getDeviceStatus { deviceStatus, deviceOperatingMode, cuffPressure in
                        
                        self.deviceStatus = deviceStatus
                        self.deviceOperatingMode = deviceOperatingMode
                        self.cuffPressure = cuffPressure
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.gemocardDeviceController.setDate { _ in
                                self.gemocardDeviceController.setTime { _ in
                                    self.isPeriferalReady = true
                                    self.completion(.connected)
                                } оnFailure: { _ in
                                    self.completion(.failedToConnect)
                                    self.disconnect()
                                }
                            } оnFailure: { _ in
                                self.completion(.failedToConnect)
                                self.disconnect()
                            }
                        }
                    } оnFailure: { failureCode in
                        self.completion(.failedToConnect)
                        self.disconnect()
                    }
                }
                break
                
            }
        }
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            print("didUpdateValueFor characteristic with emty data")
            return
        }
        let bytes = data.bytes
//        print("RECEIVED DATA (UInt8): \(bytes)")
        gemocardDeviceController.onDataReceived(bytes: bytes)
    }
}
