//
//  GemocardController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 06.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

enum FailureCodes {
    case timeout
    case invalidCrc
}

private class CompletionStorage {
    public var getDeviceStatus: GetDeviceStatusCompletion!
    public var getDateAndTimeFromDevice: GetDateAndTimeFromDeviceCompletion!
    public var getNumberOfMeasurementsInDeviceMemory: GetNumberOfMeasurementsInDeviceMemoryCompletion!
    public var getHeaderResultsNumberOfPreviousMeasurement: GetMeasurementHeaderCompletion!
    public var getResultsNumberOfPreviousMeasurement: GetResultsNumberOfPreviousMeasurementCompletion!
    public var getECG: GetECGCompletion!
    public var requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG: RequestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGCompletion!
    public var commandDone: CommandDoneCompletion!
    
    public var onFailure: OnFailure!
}

private enum GemocardDeviceControllerStatus {
    case unknown
    case getDeviceStatus
    case getDateAndTimeFromDevice
    case getNumberOfMeasurementsInDeviceMemory
    case getHeaderResultsNumberOfPreviousMeasurement
    case getResultsNumberOfPreviousMeasurement
    case getECG
    case requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG
    case setTime
    case setDate
    case eraseMemory
    case cancelMeasurement
    case startMeasurementForUser
}

/// Implements steps and methods to communicate with Gemocard
class GemocardDeviceController {
    
    // MARK: - private vars
    
    private let writeValueCallback: WriteValueCallback
    
    private var status: GemocardDeviceControllerStatus = .unknown
    
    /// Flag for timer
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
    
    /// Start timer that calls ``OnFailure`` callback in fire
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
    
    private func validateCRC(_ bytes: [UInt8]) -> Bool {
        return DataSerializer.crc(bytes) == bytes[bytes.count - 1]
    }
    
    private func writeValueForGetECGDataController(_ data: Data) {
        status = .getECG
        writeValueCallback(data)
    }
    
    /// Completion for handling status of set command for ex. ``setTime(completion:оnFailure:)``
    /// - Parameter bytes: incoming status bytes data packet
    private func processCommandDoneCompletion(_ bytes: [UInt8]) {
        stopTimer()
        if !validateCRC(bytes) {
            status = .unknown
            completionStorage.onFailure(.invalidCrc)
            return
        }
        completionStorage.commandDone(bytes[2] == 0xC0)
    }
    
    /// Reset exchange from ``GetECGController``
    private func resetExchange() {
        status = .unknown
        stopTimer()
    }
    
    // MARK: - Public Functions
    
    public func onDataReceived(bytes: [UInt8]) {
        switch status {
        case .unknown:
            print("onDataReceived: status unknown")
        case .getDeviceStatus:
            stopTimer()
            if !validateCRC(bytes) {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let result = DataSerializer.deviceStatusDeserializer(bytes: bytes)
            status = .unknown
            completionStorage.getDeviceStatus(result.deviceStatus, result.deviceOperatingMode, result.cuffPressure)
        case .getDateAndTimeFromDevice:
            stopTimer()
            if !validateCRC(bytes) {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let date = DataSerializer.dateAndTimeFromDeviceDeserializer(bytes: bytes)
            status = .unknown
            completionStorage.getDateAndTimeFromDevice(date)
        case .getNumberOfMeasurementsInDeviceMemory:
            stopTimer()
            if !validateCRC(bytes) {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let measurementsCount = DataSerializer.numberOfMeasurementsInDeviceMemoryDeserializer(bytes: bytes)
            status = .unknown
            completionStorage.getNumberOfMeasurementsInDeviceMemory(Int(measurementsCount))
        case .getHeaderResultsNumberOfPreviousMeasurement:
            stopTimer()
            if !validateCRC(bytes) {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let measurementHeaderResult = DataSerializer.resultsHeaderNumberOfPreviousMeasurementDeserializer(bytes: bytes)
            status = .unknown
            completionStorage.getHeaderResultsNumberOfPreviousMeasurement(measurementHeaderResult)
        case .getResultsNumberOfPreviousMeasurement:
            guard let getDataStorage = dataStorage else {
                dataStorage = bytes
                startTimer()
                return
            }
            let finalData = getDataStorage + bytes
            stopTimer()
            if !validateCRC(finalData) {
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
            getECGController?.onDataReceived(bytes: bytes)
        case .requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG:
            stopTimer()
            if !validateCRC(bytes) {
                status = .unknown
                completionStorage.onFailure(.invalidCrc)
                return
            }
            let packetCount = DataSerializer.responseForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGDeserializer(bytes: bytes)
            status = .unknown
            completionStorage.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG(packetCount)
        case .setTime:
            processCommandDoneCompletion(bytes)
        case .setDate:
            processCommandDoneCompletion(bytes)
        case .eraseMemory:
            processCommandDoneCompletion(bytes)
        case .cancelMeasurement:
            processCommandDoneCompletion(bytes)
        case .startMeasurementForUser:
            processCommandDoneCompletion(bytes)
        }
    }
    
    // MARK: - Set Commands
    
    public func eraseMemory(completion: @escaping CommandDoneCompletion, оnFailure: @escaping OnFailure) {
        status = .eraseMemory
        completionStorage.commandDone = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.eraseMemory())
        startTimer()
    }
    
    public func cancelMeasurement(completion: @escaping CommandDoneCompletion, оnFailure: @escaping OnFailure) {
        status = .cancelMeasurement
        completionStorage.commandDone = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.cancelMeasurement())
        startTimer()
    }
    
    public func setDate(completion: @escaping CommandDoneCompletion, оnFailure: @escaping OnFailure) {
        status = .setDate
        completionStorage.commandDone = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.setDate())
        startTimer()
    }
    
    public func setTime(completion: @escaping CommandDoneCompletion, оnFailure: @escaping OnFailure) {
        status = .setTime
        completionStorage.commandDone = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.setTime())
        startTimer()
    }
    
    public func startMeasurementForUser(user: UInt8, completion: @escaping CommandDoneCompletion, оnFailure: @escaping OnFailure) {
        status = .startMeasurementForUser
        completionStorage.commandDone = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.startMeasurementForUser(user: user))
        startTimer()
    }
    
    // MARK: - Get Commands
    
    public func getDeviceStatus(completion: @escaping GetDeviceStatusCompletion, оnFailure: @escaping OnFailure) {
        status = .getDeviceStatus
        completionStorage.getDeviceStatus = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.deviceStatusQuery())
        startTimer()
    }
    
    public func getDeviceDateTime(completion: @escaping GetDateAndTimeFromDeviceCompletion, оnFailure: @escaping OnFailure) {
        status = .getDateAndTimeFromDevice
        completionStorage.getDateAndTimeFromDevice = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.requestDateAndTimeFromDevice())
        startTimer()
    }
    
    public func getNumberOfMeasurementsInDeviceMemory(completion: @escaping GetNumberOfMeasurementsInDeviceMemoryCompletion, оnFailure: @escaping OnFailure) {
        status = .getNumberOfMeasurementsInDeviceMemory
        completionStorage.getNumberOfMeasurementsInDeviceMemory = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.getNumberOfMeasurementsInDeviceMemory())
        startTimer()
    }
    
    public func getMeasurementHeader(measurementNumber: UInt8, completion: @escaping GetMeasurementHeaderCompletion, оnFailure: @escaping OnFailure) {
        status = .getHeaderResultsNumberOfPreviousMeasurement
        completionStorage.getHeaderResultsNumberOfPreviousMeasurement = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.getMeasurementHeader(measurementNumber: measurementNumber))
        startTimer()
    }
    
    public func getMeasurement(measurementNumber: UInt16, completion: @escaping GetResultsNumberOfPreviousMeasurementCompletion, оnFailure: @escaping OnFailure) {
        status = .getResultsNumberOfPreviousMeasurement
        completionStorage.getResultsNumberOfPreviousMeasurement = completion
        completionStorage.onFailure = оnFailure
        writeValueCallback(DataSerializer.getMeasurement(measurementNumber: measurementNumber))
        startTimer()
    }
    
    public func getECG(ECGnumber: UInt8, completion: @escaping GetECGCompletion, оnFailure: @escaping OnFailure) {
        status = .getECG
        getECGController = GetECGController(ECGnumber: ECGnumber, resetExchangeCallback: resetExchange, writeValueCallback: writeValueForGetECGDataController, comletion: completion, оnFailure: оnFailure)
        startTimer()
    }
    
    public func getSettedNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG(completion: @escaping RequestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGCompletion, onFailure: @escaping OnFailure) {
        status = .requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG
        completionStorage.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG = completion
        completionStorage.onFailure = onFailure
        writeValueCallback(DataSerializer.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG())
        startTimer()
    }
}
