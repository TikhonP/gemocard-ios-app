//
//  GetDataController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 07.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

struct BrokenElectrodesAndPacemaker: OptionSet {
    let rawValue: UInt8
    
    static let brokenR = Self(rawValue: 1 << 0)
    static let brokenF = Self(rawValue: 1 << 1)
    static let brokenC1 = Self(rawValue: 1 << 2)
    static let brokenL = Self(rawValue: 1 << 3)
    static let pacemakerDetection = Self(rawValue: 1 << 4)
}

struct GetDataModel {
    let exchangeMode: ExchangeMode
    
    let ECG1: Int
    let ECG2: Int
    let ECG4: Int
    
    let brokenElectrodesAndPacemaker: BrokenElectrodesAndPacemaker
    
    let ECGpressureWaveforms: Int
    let ECGphotoplethysmogram: Int
    
    let packetNumber: Int
}

/// Controller for managing incoming data in exchange mode
class GetDataController {
    
    private let resetExchangeCallback: () -> Void
    private let comletion: GetDataCompletion
    private let оnFailure: OnFailure
    
    private var timer: Timer?
    
    /// All incoming data stores here
    private var incomingDataQueue = AsyncQueue<UInt8>()
    
    /// Buffer for holding specific data pieces from ``incomingDataQueue`` and process it
    private var dataStorage = [UInt8](repeating: 0, count: 128)
    
    init(
        resetExchangeCallback: @escaping () -> Void,
        comletion: @escaping GetDataCompletion,
        оnFailure: @escaping OnFailure
    ) {
        self.resetExchangeCallback = resetExchangeCallback
        self.comletion = comletion
        self.оnFailure = оnFailure
        startTimer()
        Task {
            decodeTask()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { _ in
            self.оnFailure(.timeout)
            self.resetExchangeCallback()
        })
    }
    
    private func stopTimer() {
        timer?.invalidate()
    }
    
    /// Copy data from ``incomingDataQueue`` to array from specific index and with given length
    /// - Parameters:
    ///   - copyTo: array copy data to
    ///   - from: store data from this index in array
    ///   - length: length to store data from ``incomingDataQueue``
    private func copyDataToDataStorage(copyTo: inout [UInt8], from: Int, length: Int) {
        var from = from, length = length, i = from
        
        while (i < (from + length)) {
            if (!incomingDataQueue.isEmpty) {
                guard let value = incomingDataQueue.dequeue() else { continue }
                copyTo[i] = value
                i += 1
            }
        }
    }
    
    private func decodeTask() {
        while true {
            copyDataToDataStorage(copyTo: &dataStorage, from: 0, length: 2)
            let responselength = Int(dataStorage[1] - 2)
            print(responselength)
            copyDataToDataStorage(copyTo: &dataStorage, from: 2, length: responselength)
            let data = Array(dataStorage.prefix(responselength + 1))
            print(data)
            if DataSerializer.crc(data) != data[data.count - 1] {
                оnFailure(.invalidCrc)
                break
            }
        }
    }
    
    public func onDataReceived(data: [UInt8]) {
        for b in data {
            incomingDataQueue.enqueue(b)
        }
    }
}
