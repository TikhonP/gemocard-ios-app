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
    private let delay = 0.1
    private let persistenceController = PersistenceController.shared
    
    private var gemocardSDK: GemocardSDK!
    private var healthKitAvailible = false
    private var getDataController: GetDataController?
    
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
    
    @Published var deviceOperatingMode = DeviceOperatingMode.unknown
    @Published var deviceStatus = DeviceStatus.unknown
    @Published var cuffPressure: UInt16 = 0
    
    // MARK: - private functions
    
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
    
    /// For ``GetDataController``
    private func progressUpdate(_ progress: Float) {
        DispatchQueue.main.async {
            self.progress = progress
        }
    }
    
    // MARK: - callbacks for Gemocard SDK usage
    
    private func gemocardSDKcompletion(code: CompletionCodes) {
        DispatchQueue.main.async {
            print("Updated status code: \(code)")
            switch code {
            case .bluetoothIsOff:
                self.navigationBarTitleStatus = LocalizedStringKey("Bluetooth Waiting...").stringValue()
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
            DispatchQueue.main.async {
                self.devices.append(peripheral)
            }
        }
        
        guard let savedGemocardUUID = UserDefaults.savedGemocardUUID else { return }
        
        if peripheral.identifier.uuidString == savedGemocardUUID {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.connect(peripheral: peripheral)
            }
        }
    }
    
    private func updateSendingToMedsengerStatus(_ status: Int) {
        DispatchQueue.main.async {
            self.sendingToMedsengerStatus = status
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
        DispatchQueue.main.async {
            self.navigationBarTitleStatus = LocalizedStringKey("Fetching data...").stringValue()
            self.fetchingDataWithGemocard = true
        }
        
        if getDataController == nil {
            getDataController = GetDataController(gemocardSDK: gemocardSDK, healthKitAvailible: healthKitAvailible, throwAlert: throwAlert, progressUpdate: progressUpdate, delay: delay)
        }
        getDataController?.getData { status in
            DispatchQueue.main.async {
                self.fetchingDataWithGemocard = false
                self.navigationBarTitleStatus = LocalizedStringKey("Fetched data").stringValue()
                
                switch status {
                case .timeout:
                    print("Get data: timeout")
                    self.throwAlert(ErrorAlerts.failedToFetchDataError, .error)
                case .invalidCrc:
                    print("Get data: invalid CRC")
                    self.throwAlert(ErrorAlerts.failedToFetchDataError, .error)
                case .done:
                    break
                }
            }
        }
    }
    
    func getDeviceStatusData() {
        if !fetchingDataWithGemocard {
            gemocardSDK.getDeviceStatus(completion: { deviceStatus, deviceOperatingMode, cuffPressure in
                DispatchQueue.main.async {
                    self.deviceStatus = deviceStatus
                    self.deviceOperatingMode = deviceOperatingMode
                    self.cuffPressure = cuffPressure
                }
            }, оnFailure: { _ in })
        }
    }
    
    func eraseMemory() {
        gemocardSDK.eraseMemory { flag in
            print("Done")
            if !flag {
                self.throwAlert(ErrorAlerts.failedToCompleteOperation, .error)
            }
        } оnFailure: { _ in }
    }
    
    // MARK: - Public functions to use in views
    
    func sendDataToMedsenger() {
        updateSendingToMedsengerStatus(1)
        
        let objects: [Measurement]? = {
            let context = persistenceController.container.viewContext
            if let recentFetchDate = UserDefaults.lastMedsengerUploadedDate {
                let fetchRequest: NSFetchRequest<Measurement> = Measurement.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "%@ <= %K", recentFetchDate as NSDate, #keyPath(Measurement.date))
                
                do {
                    return try context.fetch(fetchRequest)
                } catch {
                    updateSendingToMedsengerStatus(0)
                    print("Core Data failed to fetch: \(error.localizedDescription)")
                    //                        SentrySDK.capture(error: error)
                    return nil
                }
            } else {
                let fetchRequest: NSFetchRequest<Measurement> = Measurement.fetchRequest()
                
                do {
                    return try context.fetch(fetchRequest)
                } catch {
                    updateSendingToMedsengerStatus(0)
                    print("Core Data failed to fetch: \(error.localizedDescription)")
                    //                        SentrySDK.capture(error: error)
                    return nil
                }
            }
        }()
        
        guard let records = objects else {
            updateSendingToMedsengerStatus(0)
            print("Failed to fetch data, objects are nil!")
            return
        }
        
        if records.isEmpty {
            updateSendingToMedsengerStatus(0)
            throwAlert(ErrorAlerts.emptyDataToUploadToMedsenger)
            return
        }
        
        guard let medsengerContractId = UserDefaults.medsengerContractId, let medsengerAgentToken = UserDefaults.medsengerAgentToken else {
            updateSendingToMedsengerStatus(0)
            throwAlert(ErrorAlerts.medsengerTokenIsEmptyOrInvalid)
            return
        }
        
        for record in records {
            let data = [
                "contract_id": medsengerContractId,
                "agent_token": medsengerAgentToken,
                "timestamp": record.date!.timeIntervalSince1970,
                "measurement": [
                    "heartRate": record.heartRate,
                    "systolic_pressure": record.bloodPressureSystolic,
                    "diastolic_pressure": record.bloodPressureDiastolic,
                ]
            ] as [String : Any]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                updateSendingToMedsengerStatus(0)
                print("Failed to serialize data with JSON")
                return
            }
            
            guard let url = URL(string: "https://gemocard.medsenger.ru/api/receive") else {
                updateSendingToMedsengerStatus(0)
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
                        self.updateSendingToMedsengerStatus(0)
                        if (error as! URLError).code == URLError.notConnectedToInternet {
                            self.throwAlert(ErrorAlerts.failedToConnectToNetwork)
                        } else {
                            print("Failed to make HTTP reuest to medsenger: \(error!.localizedDescription)")
                            //                                SentrySDK.capture(error: error!)
                            self.throwAlert(ErrorAlerts.failedToUploadToMedsengerError, .error)
                        }
                        self.updateSendingToMedsengerStatus(0)
                        return
                    }
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 422 {
                            guard let data = data else {
                                self.throwAlert(ErrorAlerts.failedToUploadToMedsengerError, .error)
                                self.updateSendingToMedsengerStatus(0)
                                print("Response data is empty")
                                return
                            }
                            let dataString = String(decoding: data, as: UTF8.self)
                            if dataString.contains("Incorrect token") {
                                self.throwAlert(ErrorAlerts.medsengerTokenIsEmptyOrInvalid)
                            } else {
                                self.throwAlert(ErrorAlerts.failedToUploadToMedsengerError, .error)
                                print("Error sending to medsenger: \(dataString)")
                            }
                            self.updateSendingToMedsengerStatus(0)
                            return
                        }
                    }
                    if self.sendingToMedsengerStatus == records.count {
                        UserDefaults.lastMedsengerUploadedDate = Date()
                        self.throwAlert(ErrorAlerts.dataSuccessfullyUploadedToMedsenger)
                        self.updateSendingToMedsengerStatus(0)
                    } else {
                        self.updateSendingToMedsengerStatus(self.sendingToMedsengerStatus + 1)
                    }
                }
            }).resume()
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
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        guard let queryItems = urlComponents.queryItems else { return }
        
        for queryItem in queryItems {
            DispatchQueue.main.async {
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
