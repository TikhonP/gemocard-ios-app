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
    case invalidCrc
}

/// Main Gemocard controller class
class GemocardSDK: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    
    /// Gemocard UUIDs for using with GATT services and
    private struct GemocardUUIDs {
        static let service = CBUUID.init(string: "ffe0")
        static let characteristic = CBUUID.init(string: "ffe1")
    }
    
    private let completion: GemocardStatusUpdateCallback
    
    private let onDiscoverCallback: OnDiscoverCallback
    
    private let onProgressUpdate: OnProgressUpdate
    
    private var centralManager: CBCentralManager?
    private var isCentralManagerReady: Bool = false
    
    private var peripheral: CBPeripheral!
    private var isPeriferalReady: Bool = false
    
    private var characteristic: CBCharacteristic?
    
    private var gemocardDeviceController: GemocardDeviceController?
    
    /// Initialization of ``GemocardSDK`` class
    /// - Parameters:
    ///   - completion: update status callback for differrent events
    ///   - onDiscoverCallback: on device discover push to display it in view list
    ///   - onProgressUpdate: update progress number
    init (
        completion: @escaping GemocardStatusUpdateCallback,
        onDiscoverCallback: @escaping OnDiscoverCallback,
        onProgressUpdate: @escaping OnProgressUpdate
    ) {
        self.completion = completion
        self.onDiscoverCallback = onDiscoverCallback
        self.onProgressUpdate = onProgressUpdate
    }
    
    // MARK: - public methods
    
    /// Start BLE devices discovering
    ///
    /// Discovered devices with type `CBPeripheral` will be go
    /// to `onDiscoverCallback` mentioned in `init(onSuccessCallback:onDiscoverCallback:onFailCallback:)`
    public func discover() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /// Stop BLE devices discovering
    public func stopDiscover() {
        if isCentralManagerReady {
            centralManager!.stopScan()
        } else {
            completion(.bluetoothIsOff)
        }
    }
    
    /// Connect to suggested peripheral
    /// - Parameter peripheral: BLE devices from discovered device callback
    public func connect(_ peripheral: CBPeripheral) {
        if isCentralManagerReady {
            centralManager!.stopScan()
            self.peripheral = peripheral
            self.peripheral.delegate = self
            centralManager!.connect(self.peripheral, options: nil)
            gemocardDeviceController = GemocardDeviceController(writeValueCallback: sendData, onProgressUpdate: onProgressUpdate)
        } else {
            completion(.bluetoothIsOff)
        }
    }
    
    /// Disconnect peripheral
    public func disconnect() {
        if isPeriferalReady {
            if isCentralManagerReady {
                centralManager!.cancelPeripheralConnection(peripheral)
            } else {
                completion(.bluetoothIsOff)
            }
        } else {
            completion(.periferalIsNotReady)
        }
    }
    
    public func getDeviceStatus(completion: @escaping GetDeviceStatus) {
        if isPeriferalReady {
            gemocardDeviceController?.getDeviceStatus(completion: completion)
        } else {
            self.completion(.periferalIsNotReady)
        }
    }
    
    // MARK: - private functions for ``ContecDevice`` usage
    
    private func sendData(_ data: Data) {
        peripheral.writeValue(data, for: characteristic!, type: .withResponse)
    }
    
    private func onContecDeviceupdateStatusCallback(_ completionCode: CompletionCodes) {
        completion(completionCode)
    }
    
    // MARK: - central manager callbacks
    
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
                isPeriferalReady = true
                completion(.connected)
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
        print("Reciving...", bytes)
        
        gemocardDeviceController!.onDataReceived(data: bytes)
        
//        if DataSerializer.crc(bytes) != bytes[bytes.count - 1] {
//            completion(.invalidCrc)
//        }

    }
}
