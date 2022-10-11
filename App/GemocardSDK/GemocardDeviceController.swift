//
//  GemocardController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 06.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

class CompletionStorage {
    public var getDeviceStatus: GetDeviceStatusCompletion!
    public var getDateAndTimeFromDevice: GetDateAndTimeFromDeviceCompletion!
    public var getNumberOfMeasurementsInDeviceMemory: GetNumberOfMeasurementsInDeviceMemoryCompletion!
    public var getHeaderResultsNumberOfPreviousMeasurement: GetHeaderResultsNumberOfPreviousMeasurementCompletion!
    public var getResultsNumberOfPreviousMeasurement: GetResultsNumberOfPreviousMeasurementCompletion!
    public var getECG: GetECGCompletion!
    public var requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG: RequestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGCompletion!
    
    public var onFailure: OnFailure!
}

enum FailureCodes {
    case timeout
    case invalidCrc
}

enum GemocardDeviceControllerStatus {
    case unknown
    case getDeviceStatus
    case getDateAndTimeFromDevice
    case getNumberOfMeasurementsInDeviceMemory
    case getHeaderResultsNumberOfPreviousMeasurement
    case getResultsNumberOfPreviousMeasurement
    case getECG
    case requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG
}

/// Implements steps and methods to communicate with Gemocard
class GemocardDeviceController {

    // MARK: - private vars
    
    private let writeValueCallback: WriteValueCallback
    
    private var status: GemocardDeviceControllerStatus = .unknown
    private var isProcessing = false
    
    private var timer: Timer?
    
    private var completionStorage = CompletionStorage()
    
    private var getECGController: GetECGController?
    
    private var dataStorage: [UInt8]?
    
    /// Initilize ``GemocardDeviceController`` store all callbacks
    /// - Parameters:
    ///   - writeValueCallback: function gets `Data` object and sends it to spirometer
    init(writeValueCallback: @escaping WriteValueCallback) {
        self.writeValueCallback = writeValueCallback
    }
    
    // MARK: - Private functions
    
    private func startTimer() {
        isProcessing = true
        if let timer = self.timer {
            timer.invalidate()
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { timer in
            if self.isProcessing {
                self.status = .unknown
                self.completionStorage.onFailure(.timeout)
                self.getECGController = nil
            }
        })
    }
    
    private func stopTimer() {
        isProcessing = false
    }
    
    private func validateCRC(_ data: [UInt8]) -> Bool {
        return DataSerializer.crc(data) == data[data.count - 1]
    }
    
    private func writeValueForGetECGDataController(_ data: Data) {
        status = .getECG
        writeValueCallback(data)
    }
    
    // MARK: - Public functions
    
    public func onDataReceived(data: [UInt8]) {
        switch status {
        case .unknown:
            print("onDataReceived: status unknown")
        case .getDeviceStatus:
            stopTimer()
            guard validateCRC(data) else {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let result = DataSerializer.deviceStatusDeserializer(bytes: data)
            status = .unknown
            completionStorage.getDeviceStatus(result.deviceStatus, result.deviceOperatingMode, result.cuffPressure)
        case .getDateAndTimeFromDevice:
            stopTimer()
            guard validateCRC(data) else {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let date = DataSerializer.dateAndTimeFromDeviceDeserializer(bytes: data)
            status = .unknown
            completionStorage.getDateAndTimeFromDevice(date)
        case .getNumberOfMeasurementsInDeviceMemory:
            stopTimer()
            guard validateCRC(data) else {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let measurementsCount = DataSerializer.numberOfMeasurementsInDeviceMemoryDeserializer(bytes: data)
            status = .unknown
            completionStorage.getNumberOfMeasurementsInDeviceMemory(Int(measurementsCount))
        case .getHeaderResultsNumberOfPreviousMeasurement:
            stopTimer()
            guard validateCRC(data) else {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let measurementHeaderResult = DataSerializer.resultsHeaderNumberOfPreviousMeasurementDeserializer(bytes: data)
            status = .unknown
            completionStorage.getHeaderResultsNumberOfPreviousMeasurement(measurementHeaderResult)
        case .getResultsNumberOfPreviousMeasurement:
            guard let getDataStorage = dataStorage else {
                dataStorage = data
                startTimer()
                return
            }
            let finalData = getDataStorage + data
            stopTimer()
            guard validateCRC(finalData) else {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let measurementResult = DataSerializer.resultsNumberOfPreviousMeasurementDeserializer(bytes: finalData)
            status = .unknown
            dataStorage = nil
            completionStorage.getResultsNumberOfPreviousMeasurement(measurementResult)
        case .getECG:
            startTimer()
            getECGController?.onDataReceived(data: data)
        case .requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG:
            stopTimer()
            guard validateCRC(data) else {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let packetCount = DataSerializer.responseForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGDeserializer(bytes: data)
            status = .unknown
            completionStorage.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG(packetCount)
        }
    }
    
    public func getDeviceStatus(completion: @escaping GetDeviceStatusCompletion, оnFailure: @escaping OnFailure) {
        status = .getDeviceStatus
        completionStorage.getDeviceStatus = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.deviceStatusQuery())
        startTimer()
    }
    
    public func cancelMeasurement() {
        writeValueCallback(DataSerializer.cancelMeasurement())
    }
    
    public func setDateTime() {
        writeValueCallback(DataSerializer.setDate())
        writeValueCallback(DataSerializer.setTime())
    }
    
    public func getDateAndTimeFromDevice(completion: @escaping GetDateAndTimeFromDeviceCompletion, оnFailure: @escaping OnFailure) {
        status = .getDateAndTimeFromDevice
        completionStorage.getDateAndTimeFromDevice = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.requestDateAndTimeFromDevice())
        startTimer()
    }
    
    public func startMeasurementForUser(user: UInt8) {
        writeValueCallback(DataSerializer.startMeasurementForUser(user: user))
    }
    
    public func getNumberOfMeasurementsInDeviceMemory(completion: @escaping GetNumberOfMeasurementsInDeviceMemoryCompletion, оnFailure: @escaping OnFailure) {
        status = .getNumberOfMeasurementsInDeviceMemory
        completionStorage.getNumberOfMeasurementsInDeviceMemory = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.getNumberOfMeasurementsInDeviceMemory())
        startTimer()
    }
    
    public func getHeaderResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt8, completion: @escaping GetHeaderResultsNumberOfPreviousMeasurementCompletion, оnFailure: @escaping OnFailure) {
        status = .getHeaderResultsNumberOfPreviousMeasurement
        completionStorage.getHeaderResultsNumberOfPreviousMeasurement = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.getHeaderResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: numberOfPreviousMeasurement))
        startTimer()
    }
    
    public func getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt16, completion: @escaping GetResultsNumberOfPreviousMeasurementCompletion, оnFailure: @escaping OnFailure) {
        status = .getResultsNumberOfPreviousMeasurement
        completionStorage.getResultsNumberOfPreviousMeasurement = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: numberOfPreviousMeasurement))
        startTimer()
    }
    
    public func getResultsNumberOfPreviousECG(numberOfPreviousECG: UInt8, completion: @escaping GetECGCompletion, оnFailure: @escaping OnFailure) {
        status = .getECG
        getECGController = GetECGController(numberOfPreviousECG: numberOfPreviousECG,resetExchangeCallback: resetExchange, writeValueCallback: writeValueForGetECGDataController, comletion: completion, оnFailure: оnFailure)
        startTimer()
    }
    
    public func requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG(completion: @escaping RequestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGCompletion, onFailure: @escaping OnFailure) {
        status = .requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG
        completionStorage.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG = completion
        completionStorage.onFailure = onFailure
        writeValueCallback(DataSerializer.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG())
        startTimer()
    }
    
    /// Use for invalid crc
    public func resetExchange() {
        status = .unknown
        stopTimer()
    }
}
