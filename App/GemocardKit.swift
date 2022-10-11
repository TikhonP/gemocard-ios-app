//
//  GemocardKit.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 05.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI
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
    @Published var fetchingDataWithGemocard = false
    @Published var showBluetoothIsOffWarning = false
    @Published var showSelectDevicesInfo = false
    
    @Published var progress: Float = 0.0
    
    @Published var devices: [CBPeripheral] = []
    @Published var connectingPeripheral: CBPeripheral?
    
    @Published var error: ErrorInfo?
    
    @Published var navigationBarTitleStatus = LocalizedStringKey("Fetched data").stringValue()
    
    // MARK: - private functions
    
    /// Throw alert from ``ErrorAlerts`` class
    /// - Parameters:
    ///   - errorInfo: ``ErrorInfo`` instance
    ///   - feedbackType: optional feedback type if you need haptic feedback
    private func throwAlert(_ errorInfo: ErrorInfo, _ feedbackType: UINotificationFeedbackGenerator.FeedbackType? = nil) {
        DispatchQueue.main.async {
            if let feedbackType = feedbackType {
                HapticFeedbackController.shared.prepareNotify()
                HapticFeedbackController.shared.notify(feedbackType)
            }
            self.error = errorInfo
        }
    }
    
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
        fetchRequest.predicate = NSPredicate(format: "headerHash == %ld", measurementHeaderResult.hashValue, #keyPath(Measurement.headerHash))
        
        guard let objects = try? context.fetch(fetchRequest) else {
            print("Core Data failed to fetch hash")
            guard let error = error as? Error else {
                print("Core Data failed to fetch hash")
                return
            }
            print("Core Data failed to fetch: \(error.localizedDescription)")
            // TODO: add sentry
            // SentrySDK.capture(error: error)
            return
        }
        
        if objects.isEmpty {
            gemocardSDK.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt16(self.currentMeasurement), completion: { measurementResult in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.gemocardSDK.getResultsNumberOfPreviousECG(numberOfPreviousECG: self.currentMeasurement, completion: { ECGdata, ECGStatusData in
                        self.persistenceController.createMeasurementFromStruct(measurement: measurementResult, measurementHeader: measurementHeaderResult, ecgData: ECGdata, ecgStatusData: ECGStatusData, context: context)
                        print("SavingMeasurement")
                        self.getMeasurentHeader()
                    }, оnFailure: self.onRequestFail)
                }
            }, оnFailure: onRequestFail)
        } else {
            getMeasurentHeader()
            print("Skipping already synchronized objects")
        }
    }
    
    // MARK: - callbacks for Gemocard SDK usage
    
    func gemocardSDKcompletion(code: CompletionCodes) {
        DispatchQueue.main.async {
            print("Updated status code: \(code)")
            switch code {
            case .bluetoothIsOff:
                self.navigationBarTitleStatus = LocalizedStringKey("Waiting Bluetooth...").stringValue()
                self.isBluetoothOn = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if !self.isBluetoothOn {
                        self.showBluetoothIsOffWarning = true
                    }
                }
            case .bluetoothIsOn:
                self.showBluetoothIsOffWarning = false
                if !self.isBluetoothOn {
                    self.isBluetoothOn = true
                    self.discover()
                }
            case .periferalIsNotFromThisQueue:
                self.throwAlert(ErrorAlerts.invalidPeriferal, .error)
            case .disconnected:
                self.fetchingDataWithGemocard = false
                self.isConnected = false
                self.connectingPeripheral = nil
                self.devices = []
                self.throwAlert(ErrorAlerts.disconnected, .warning)
                self.discover()
            case .failedToDiscoverServiceError:
                self.throwAlert(ErrorAlerts.serviceNotFound, .error)
            case .periferalIsNotReady:
                self.throwAlert(ErrorAlerts.deviceIsNotReady, .error)
            case .connected:
                HapticFeedbackController.shared.play(.light)
                self.showSelectDevicesInfo = false
                self.isConnected = true
                self.getDeviceStatus()
                self.navigationBarTitleStatus = LocalizedStringKey("Fetched data").stringValue()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if !self.isConnected {
                self.showSelectDevicesInfo = true
            }
        }
        navigationBarTitleStatus = LocalizedStringKey("Search...").stringValue()
        gemocardSDK.discover()
    }
    
    func connect(peripheral: CBPeripheral) {
        navigationBarTitleStatus = LocalizedStringKey("Connecting...").stringValue()
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
        gemocardSDK.getResultsNumberOfPreviousECG(numberOfPreviousECG: 1) { ECGData, ECGStatusData  in
            print("Got data: \(ECGData.count)")
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
    
    func requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG() {
        gemocardSDK.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG() { packetCount in
            print("Packet count: \(packetCount)")
        } onFailure: { failureCode in
            print("Error: \(failureCode)")
        }
    }
}
