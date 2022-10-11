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
    
    private let persistenceController = PersistenceController.shared
    
    private var gemocardSDK: GemocardSDK!
    
    private var measurementsCount = 0
    private var currentMeasurement: UInt8 = 1
    
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
    
    private func onRequestFail(_ failureCode: FailureCodes) {
        print("Error: \(failureCode)")
    }
    
    private func getMeasurentHeader() {
        if currentMeasurement <= measurementsCount {
            print("Getting measurement: \(currentMeasurement)")
            gemocardSDK.getHeaderResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: self.currentMeasurement, completion: processMeasurementHeaderResult, оnFailure: onRequestFail)
        }
        currentMeasurement += 1
    }
    
    private func processMeasurementHeaderResult(_ measurementHeaderResult: MeasurementHeaderResult) {
        let context = persistenceController.container.viewContext
        let fetchRequest = Measurement.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "objectHash == %ld", measurementHeaderResult.objectHash, #keyPath(Measurement.objectHash))
        
        guard let objects = try? context.fetch(fetchRequest) else {
            print("Core Data failed to fetch hash")
            //            guard let error = error as? Error else {
            //                print("Core Data failed to fetch hash")
            //                return
            //            }
            //            print("Core Data failed to fetch: \(error.localizedDescription)")
            // TODO: add sentry
            // SentrySDK.capture(error: error)
            return
        }
        
        if objects.isEmpty {
            gemocardSDK.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt16(self.currentMeasurement), completion: { measurementResult in
                self.persistenceController.createMeasurementFromStruct(measurement: measurementResult, objectHash: measurementHeaderResult.objectHash, context: context)
                print("SavingMeasurement")
                self.getMeasurentHeader()
            }, оnFailure: onRequestFail)
        } else {
            getMeasurentHeader()
            print("Skipping already synchronized objects")
        }
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
                self.getDeviceStatus()
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
    
    func getData() {
        DispatchQueue.main.async {
            self.gemocardSDK.getNumberOfMeasurements(completion:  { measurementsCount in
                self.measurementsCount = measurementsCount
                self.currentMeasurement = 1
                print("Measurement count: \(measurementsCount)")
                self.getMeasurentHeader()
            }, оnFailure: self.onRequestFail)
        }
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
    
    
    
    func getHeaderResultsNumberOfPreviousMeasurement() {
        gemocardSDK.getHeaderResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: 1) { measurementResult in
            print("Mesuremnt result: \(measurementResult)")
        } оnFailure: { failureCode in
            print("Error: \(failureCode)")
        }
    }
    
    func getResultsNumberOfPreviousECG() {
        gemocardSDK.getResultsNumberOfPreviousECG(numberOfPreviousMeasurement: 7) { data in
            print("\(data)")
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
                    self.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt16(self.currentMeasurement))
                }
            } оnFailure: { failureCode in
                print("Error: \(failureCode)")
            }
        }
    }
}
