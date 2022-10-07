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
    public var getResultsNumberOfPreviousMeasurement: GetResultsNumberOfPreviousMeasurementCompletion!
    
    public var оnFailure: OnFailure!
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
    case exchangeMode
    case getResultsNumberOfPreviousMeasurement
}

/// Implements steps and methods to communicate with Gemocard
class GemocardDeviceController {

    // MARK: - private vars
    
    private let writeValueCallback: WriteValueCallback
    
    private var status: GemocardDeviceControllerStatus = .unknown
    private var isProcessing = false
    
    private var timer: Timer?
    
    private var completionStorage = CompletionStorage()
    
    private var getDataController: GetDataController?
    
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
                self.completionStorage.оnFailure(.timeout)
            }
        })
    }
    
    private func stopTimer() {
        isProcessing = false
    }
    
    private func validateCRC(_ data: [UInt8]) -> Bool {
        return DataSerializer.crc(data) == data[data.count - 1]
    }
    
    // MARK: - Public functions
    
    public func onDataReceived(data: [UInt8]) {
        switch status {
        case .unknown:
            break;
        case .getDeviceStatus:
            stopTimer()
            guard validateCRC(data) else {
                completionStorage.оnFailure(.invalidCrc)
                status = .unknown
                return
            }
            let result = DataSerializer.deviceStatusDeserializer(bytes: data)
            completionStorage.getDeviceStatus(result.deviceStatus, result.deviceOperatingMode, result.cuffPressure)
            status = .unknown
        case .getDateAndTimeFromDevice:
            stopTimer()
            guard validateCRC(data) else {
                completionStorage.оnFailure(.invalidCrc)
                status = .unknown
                return
            }
            let date = DataSerializer.dateAndTimeFromDeviceDeserializer(bytes: data)
            completionStorage.getDateAndTimeFromDevice(date)
            status = .unknown
        case .getNumberOfMeasurementsInDeviceMemory:
            stopTimer()
            guard validateCRC(data) else {
                completionStorage.оnFailure(.invalidCrc)
                status = .unknown
                return
            }
            let measurementsCount = DataSerializer.numberOfMeasurementsInDeviceMemoryDeserializer(bytes: data)
            completionStorage.getNumberOfMeasurementsInDeviceMemory(Int(measurementsCount))
            status = .unknown
        case .exchangeMode:
            getDataController?.onDataReceived(data: data)
        case .getResultsNumberOfPreviousMeasurement:
            stopTimer()
            guard validateCRC(data) else {
                completionStorage.оnFailure(.invalidCrc)
                status = .unknown
                return
            }
            let measurementResult = DataSerializer.resultsNumberOfPreviousMeasurementDeserializer(bytes: data)
            completionStorage.getResultsNumberOfPreviousMeasurement(measurementResult)
            status = .unknown
        }
    }
    
    public func getDeviceStatus(completion: @escaping GetDeviceStatusCompletion, оnFailure: @escaping OnFailure) {
        status = .getDeviceStatus
        completionStorage.getDeviceStatus = completion
        completionStorage.оnFailure = оnFailure
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
        completionStorage.оnFailure = оnFailure
        writeValueCallback(DataSerializer.requestDateAndTimeFromDevice())
        startTimer()
    }
    
    public func startMeasurementForUser(user: UInt8) {
        writeValueCallback(DataSerializer.startMeasurementForUser(user: user))
    }
    
    public func getNumberOfMeasurementsInDeviceMemory(completion: @escaping GetNumberOfMeasurementsInDeviceMemoryCompletion, оnFailure: @escaping OnFailure) {
        status = .getNumberOfMeasurementsInDeviceMemory
        completionStorage.getNumberOfMeasurementsInDeviceMemory = completion
        completionStorage.оnFailure = оnFailure
        writeValueCallback(DataSerializer.getNumberOfMeasurementsInDeviceMemory())
        startTimer()
    }
    
    public func startingExchange(
        ECG1: Bool = false,
        ECG2: Bool = false,
        ECG4: Bool = false,
        pressureWaveforms: Bool = false,
        completion: @escaping GetDataCompletion,
        оnFailure: @escaping OnFailure
    ) {
        status = .exchangeMode
        writeValueCallback(DataSerializer.startingExchange(ECG1: ECG1, ECG2: ECG2, ECG4: ECG4, pressureWaveforms: pressureWaveforms))
        getDataController = GetDataController(resetExchangeCallback: resetExchange, comletion: completion, оnFailure: оnFailure)
    }
    
    public func getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt8, completion: @escaping GetResultsNumberOfPreviousMeasurementCompletion, оnFailure: @escaping OnFailure) {
        status = .getResultsNumberOfPreviousMeasurement
        completionStorage.getResultsNumberOfPreviousMeasurement = completion
        completionStorage.оnFailure = оnFailure
        writeValueCallback(DataSerializer.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: numberOfPreviousMeasurement))
        startTimer()
    }
    
    /// Use for invalid crc
    public func resetExchange() {
        status = .unknown
    }
}
