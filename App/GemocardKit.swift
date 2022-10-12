//
//  GemocardKit.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 05.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI
import CoreData
import Foundation
import CoreBluetooth

/// Main controller for applicatin and Gemocard connection
final class GemocardKit: ObservableObject {
    
    // MARK: - private vars
    
    /// Delay between requests in seconds
    private let delay = 0.3
    private let persistenceController = PersistenceController.shared
    
    private var gemocardSDK: GemocardSDK!
    private var measurementsCount = 0
    private var currentMeasurement: UInt8 = 1
    private var maxDateWhileFetching: Date? = UserDefaults.lastSyncedDateKey
    private var healthKitAvailible = false
    
    // MARK: - published vars
    
    @Published var isConnected = false
    @Published var isBluetoothOn = true
    @Published var fetchingDataWithGemocard = false
    @Published var showBluetoothIsOffWarning = false
    @Published var showSelectDevicesInfo = false
    @Published var presentUploadToMedsenger = UserDefaults.medsengerAgentToken != nil && UserDefaults.medsengerContractId != nil
    @Published var sendingToMedsengerStatus: Int = 0
    
    @Published var progress: Float = 0.0
    
    @Published var devices: [CBPeripheral] = []
    @Published var connectingPeripheral: CBPeripheral?
    
    @Published var error: ErrorInfo?
    
    @Published var navigationBarTitleStatus = LocalizedStringKey("Fetched data").stringValue()
    
    @Published var debugMeasurementNumber = "0"
    
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
    
    private func startHealthKit() {
        HealthKitController.authorizeHealthKit { (authorized, error) in
            guard authorized else {
                if let error = error {
                    print("HealthKit Authorization Failed. Reason: \(error.localizedDescription)")
                } else {
                    print("HealthKit Authorization Failed")
                }
                self.healthKitAvailible = false
                return
            }
            self.healthKitAvailible = true
            print("HealthKit Successfully Authorized.")
        }
    }
    
    private func onRequestFail(_ failureCode: FailureCodes) {
        DispatchQueue.main.async {
            print("Error: \(failureCode)")
            self.fetchingDataWithGemocard = false
            self.throwAlert(ErrorAlerts.failedToFetchDataError, .error)
            self.finishMeasurementFetch()
        }
    }
    
    private func finishMeasurementFetch() {
        self.progress = 1
        self.navigationBarTitleStatus = LocalizedStringKey("Fetched data").stringValue()
        self.fetchingDataWithGemocard = false
        if let maxDateWhileFetching = self.maxDateWhileFetching {
            UserDefaults.lastSyncedDateKey = maxDateWhileFetching
        }
    }
    
    private func getMeasurentHeader() {
        DispatchQueue.main.async {
            self.currentMeasurement += 1
            if self.currentMeasurement <= self.measurementsCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                    print("Getting measurement: \(self.currentMeasurement)")
                    self.gemocardSDK.getMeasurementHeader(measurementNumber: self.currentMeasurement, completion: self.processMeasurementHeaderResult, оnFailure: self.onRequestFail)
                }
            } else {
                self.finishMeasurementFetch()
            }
        }
    }
    
    private func processMeasurementHeaderResult(_ measurementHeaderResult: MeasurementHeaderResult) {
        DispatchQueue.main.async {
            self.progress = 0.1 + ((Float(self.currentMeasurement + 1) - 0.5) / Float(self.measurementsCount + 1)) * 0.9
            let context = self.persistenceController.container.viewContext
            
            let isObjectNew = {
                guard let savedDate = UserDefaults.lastSyncedDateKey else { return true }
                print("Saved date: \(savedDate), measurement header result date: \(measurementHeaderResult.date), is new: \(savedDate < measurementHeaderResult.date)")
                return savedDate < measurementHeaderResult.date
            }()
            
            if isObjectNew {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                    self.progress = 0.1 + (Float(self.currentMeasurement + 1) / Float(self.measurementsCount + 1)) * 0.9
                    self.gemocardSDK.getMeasurement(measurementNumber: UInt16(self.currentMeasurement), completion: { measurementResult in
                        
                        if measurementResult.changeSeriesEndFlag != .seriesCanceled {
                            if let maxDateWhileFetching = self.maxDateWhileFetching {
                                if maxDateWhileFetching < measurementResult.date {
                                    self.maxDateWhileFetching = measurementResult.date
                                }
                            } else {
                                self.maxDateWhileFetching = measurementResult.date
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                                self.gemocardSDK.getECG(ECGnumber: self.currentMeasurement, completion: { ECGdata, ECGStatusData in
                                    self.persistenceController.createMeasurementFromStruct(measurement: measurementResult, measurementHeader: measurementHeaderResult, ecgData: ECGdata, ecgStatusData: ECGStatusData, context: context)
                                    if self.healthKitAvailible {
                                        HealthKitController.saveRecord(
                                            heartRate: Double(measurementResult.pulse),
                                            bloodPressureSystolic: Double(measurementResult.systolicBloodPressure),
                                            bloodPressureDiastolic: Double(measurementResult.diastolicBloodPressure),
                                            date: measurementResult.date)
                                    }
                                    print("Saved measurement: \(measurementResult)")
                                    print("Measurement header: \(measurementHeaderResult)")
                                    self.getMeasurentHeader()
                                }, оnFailure: self.onRequestFail)
                            }
                        } else {
                            print("Not Saved measurement: \(measurementResult)")
                            print("Not Measurement header: \(measurementHeaderResult)")
                            self.getMeasurentHeader()
                        }
                    }, оnFailure: self.onRequestFail)
                }
            } else {
                self.getMeasurentHeader()
                print("Skipping already synchronized objects")
            }
        }
    }
    
    // MARK: - callbacks for Gemocard SDK usage
    
    private func gemocardSDKcompletion(code: CompletionCodes) {
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
                self.navigationBarTitleStatus = LocalizedStringKey("Fetched data").stringValue()
                self.getData()
            case .failedToConnect:
                self.throwAlert(ErrorAlerts.failedToConnect, .error)
            }
        }
    }
    
    private func onDiscoverCallback(peripheral: CBPeripheral, _: [String : Any], _ RSSI: NSNumber) {
        if (!devices.contains(peripheral)) {
            devices.append(peripheral)
        }
        
        guard let savedGemocardUUID = UserDefaults.savedGemocardUUID else { return }
        
        if peripheral.identifier.uuidString == savedGemocardUUID {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.connect(peripheral: peripheral)
            }
        }
    }
    
    // MARK: - public functions controlls BLE connections
    
    /// Call on app appear
    func initilizeGemocard() {
        startGemocardSDK()
        startHealthKit()
    }
    
    func discover() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
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
    
    func getData() {
        self.navigationBarTitleStatus = LocalizedStringKey("Fetching data...").stringValue()
        self.fetchingDataWithGemocard = true
        self.progress = 0.05
        DispatchQueue.main.async {
            self.gemocardSDK.getNumberOfMeasurements(completion:  { measurementsCount in
                self.measurementsCount = measurementsCount
                self.progress = 0.1
                self.currentMeasurement = 0
                print("Measurement count: \(measurementsCount), current measurement: \(self.currentMeasurement)")
                if measurementsCount == 0 {
                    self.finishMeasurementFetch()
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                    print("Getting measurement: \(self.currentMeasurement)")
                    self.gemocardSDK.getMeasurementHeader(measurementNumber: self.currentMeasurement, completion: self.processMeasurementHeaderResult, оnFailure: self.onRequestFail)
                }
            }, оnFailure: self.onRequestFail)
        }
    }
    
    func eraseMemory() {
        gemocardSDK.eraseMemory { flag in
            print("Done")
            if !flag {
                self.throwAlert(ErrorAlerts.failedToCompleteOperation, .error)
            }
        } оnFailure: { failureCode in
            self.throwAlert(ErrorAlerts.failedToCompleteOperation, .error)
        }
    }
    
    // MARK: - Public functions to use in views
    
    func sendDataToMedsenger() {
        DispatchQueue.main.async {
            self.sendingToMedsengerStatus = 1
            
            let objects: [Measurement]? = {
                let context = self.persistenceController.container.viewContext
                if let recentFetchDate = UserDefaults.lastMedsengerUploadedDate {
                    let fetchRequest: NSFetchRequest<Measurement> = Measurement.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "%@ <= %K", recentFetchDate as NSDate, #keyPath(Measurement.date))
                    
                    do {
                        return try context.fetch(fetchRequest)
                    } catch {
                        self.sendingToMedsengerStatus = 0
                        print("Core Data failed to fetch: \(error.localizedDescription)")
//                        SentrySDK.capture(error: error)
                        return nil
                    }
                } else {
                    let fetchRequest: NSFetchRequest<Measurement> = Measurement.fetchRequest()
                    
                    do {
                        return try context.fetch(fetchRequest)
                    } catch {
                        self.sendingToMedsengerStatus = 0
                        print("Core Data failed to fetch: \(error.localizedDescription)")
//                        SentrySDK.capture(error: error)
                        return nil
                    }
                }
            }()
 
            guard let records = objects else {
                self.sendingToMedsengerStatus = 0
                print("Failed to fetch data, objects are nil!")
                return
            }
            
            if records.isEmpty {
                self.sendingToMedsengerStatus = 0
                self.throwAlert(ErrorAlerts.emptyDataToUploadToMedsenger)
                return
            }
            
            guard let medsengerContractId = UserDefaults.medsengerContractId, let medsengerAgentToken = UserDefaults.medsengerAgentToken else {
                self.sendingToMedsengerStatus = 0
                self.throwAlert(ErrorAlerts.medsengerTokenIsEmpty)
                return
            }
            
            for record in records {
                let data = [
                    "contract_id": medsengerContractId,
                    "agent_token": medsengerAgentToken,
                    "timestamp": record.date!.timeIntervalSince1970,
                    "measurement": [
//                        "FVC": record.fvc,
//                        "FEV1": record.fev1,
//                        "FEV1%": record.fev1_fvc,
                    ]
                ] as [String : Any]
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                    self.sendingToMedsengerStatus = 0
                    print("Failed to serialize data with JSON")
                    return
                }
                
                guard let url = URL(string: "https://gemocard.medsenger.ru/api/receive") else {
                    self.sendingToMedsengerStatus = 0
                    print("Invalid medsenger url!")
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("\(String(describing: jsonData.count))", forHTTPHeaderField: "Content-Length")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                
                URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
                    DispatchQueue.main.async {
                        guard error == nil else {
                            self.sendingToMedsengerStatus = 0
                            if (error as! URLError).code == URLError.notConnectedToInternet {
                                self.throwAlert(ErrorAlerts.failedToConnectToNetwork)
                            } else {
                                print("Failed to make HTTP reuest to medsenger: \(error!.localizedDescription)")
//                                SentrySDK.capture(error: error!)
                            }
                            return
                        }
                        if self.sendingToMedsengerStatus == records.count {
                            UserDefaults.lastMedsengerUploadedDate = Date()
                            self.throwAlert(ErrorAlerts.dataSuccessfullyUploadedToMedsenger)
                            self.sendingToMedsengerStatus = 0
                        } else {
                            self.sendingToMedsengerStatus += 1
                        }
                    }
                }).resume()
            }
        }
    }
    
    func resetMedsengerCredentials() {
        DispatchQueue.main.async {
            UserDefaults.medsengerAgentToken = nil
            UserDefaults.medsengerContractId = nil
            self.presentUploadToMedsenger = false
        }
    }
    
    func updatePropertiesFromDeeplink(url: URL) {
        DispatchQueue.main.async {
            guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            guard let queryItems = urlComponents.queryItems else { return }
            
            for queryItem in queryItems {
                switch queryItem.name {
                case "contract_id":
                    guard let medsengerContractIdValue = queryItem.value else {
                        print("Empty medsenger contract id")
                        return
                    }
                    UserDefaults.medsengerContractId = Int(medsengerContractIdValue)
                case "agent_token":
                    UserDefaults.medsengerAgentToken = queryItem.value
                default:
                    print("Deeplink url query item \(queryItem.name): \(queryItem.value ?? "Nil value")")
                }
                self.presentUploadToMedsenger = true
            }
        }
    }
}
