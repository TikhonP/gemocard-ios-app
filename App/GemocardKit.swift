//
//  GemocardKit.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 05.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Main controller for applicatin and Gemocard connection
final class GemocardKit: ObservableObject {
    
    // MARK: - private vars
    
    private var gemocardSDK: GemocardSDK!
    
    private var measurementsCount = 0
    private var currentMeasurement: UInt16 = 1
    
    // MARK: - published vars
    
    @Published var isConnected = false
    @Published var isBluetoothOn = true
    
    @Published var progress: Float = 0.0
    
    @Published var devices: [CBPeripheral] = []
    @Published var connectingPeripheral: CBPeripheral?
    
    // MARK: - private functions
    
    private func startGemocardSDK() {
        gemocardSDK = GemocardSDK(completion: gemocardSDKcompletion, onDiscoverCallback: onDiscoverCallback)
    }
    
    // MARK: - callbacks for Gemocard SDK usage
    
    func onProgressUpdate(_ progress: Float) {
        DispatchQueue.main.async {
            self.progress = progress
        }
    }
    
    func gemocardSDKcompletion(code: CompletionCodes) {
        DispatchQueue.main.async {
            print("Updated status code: \(code)")
            
            switch code {
                
            case .bluetoothIsOff:
                break;
            case .bluetoothIsOn:
                break;
            case .periferalIsNotFromThisQueue:
                break;
            case .disconnected:
                self.isConnected = false
                self.connectingPeripheral = nil
            case .failedToDiscoverServiceError:
                break;
            case .periferalIsNotReady:
                break;
            case .connected:
                self.isConnected = true
            case .invalidCrc:
                break;
            }
        }
    }
    
    func onDiscoverCallback(peripheral: CBPeripheral, _: [String : Any], _ RSSI: NSNumber) {
        if (!devices.contains(peripheral)) {
            devices.append(peripheral)
        }
        
        guard let savedGemocardUUID = UserDefaults.savedGemocardUUID else { return }
        
        if peripheral.identifier.uuidString == savedGemocardUUID {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.connect(peripheral: peripheral)
            }
        }
    }
    
    // MARK: - public functions controlls BLE connections
    
    /// Call on app appear
    func initilizeGemocard() {
        startGemocardSDK()
    }
    
    func discover() {
        gemocardSDK.discover()
    }
    
    func connect(peripheral: CBPeripheral) {
        if UserDefaults.saveUUID {
            UserDefaults.savedGemocardUUID = peripheral.identifier.uuidString
        }
        connectingPeripheral = peripheral
        gemocardSDK.connect(peripheral)
    }
    
    func disconnect() {
        gemocardSDK.disconnect()
    }
    
    func action() {
        gemocardSDK.testAction()
    }
    
    func getDeviceStatus() {
        self.gemocardSDK.getDeviceStatus() { deviceStatus, deviceOperatingMode, cuffPressure in
            print("Device status: \(deviceStatus), device operating mode: \(deviceOperatingMode), ciff pressure: \(cuffPressure)")
        } оnFailure: { failureCode in
            print("Error: \(failureCode)")
        }
    }
    
    func startMeasurement() {
        gemocardSDK.startMeasurementForUser(user: 1)
    }
    
    func setDateTime() {
        gemocardSDK.setDateTime()
    }
    
    func getDateTime() {
        gemocardSDK.getDateTime() { date in
            print("Date: \(String(describing: date))")
        } оnFailure: { failureCode in
            print("Error: \(failureCode)")
        }
    }
    
    func getNumberOfMeasurements() {
        gemocardSDK.getNumberOfMeasurements() { measurementsCount in
            print("Number of measurements: \(measurementsCount)")
        } оnFailure: { failureCode in
            print("Error: \(failureCode)")
        }
    }
    
    func getData() {
        DispatchQueue.main.async {
            self.gemocardSDK.getNumberOfMeasurements { measurementsCount in
                self.measurementsCount = measurementsCount
                self.currentMeasurement = 1
                print("Measurement count: \(measurementsCount)")
                self.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: self.currentMeasurement)
            } оnFailure: { failureCode in
                print("Error: \(failureCode)")
            }
        }
    }
    
    func getHeaderResultsNumberOfPreviousMeasurement() {
        gemocardSDK.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: 1) { measurementResult in
            print("Mesuremnt result: \(measurementResult)")
        } оnFailure: { failureCode in
            print("Error: \(failureCode)")
        }
    }
    
    func getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt16) {
        DispatchQueue.main.async {
            self.gemocardSDK.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: numberOfPreviousMeasurement) { measurementResult in
                print("Mesuremnt result: \(measurementResult)")
                self.currentMeasurement += 1
                if self.currentMeasurement <= self.measurementsCount {
                    self.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: self.currentMeasurement)
                }
            } оnFailure: { failureCode in
                print("Error: \(failureCode)")
            }
        }
    }
}
