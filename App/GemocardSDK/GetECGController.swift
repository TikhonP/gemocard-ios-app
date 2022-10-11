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
class GetECGController {
    
    private let resetExchangeCallback: () -> Void
    private let comletion: GetECGCompletion
    private let оnFailure: OnFailure
    
    private var timer: Timer?
    
    /// All incoming data stores here
    private var incomingDataQueue = AsyncQueue<UInt8>()
    
    /// Buffer for holding specific data pieces from ``incomingDataQueue`` and process it
    private var dataStorage = [UInt8](repeating: 0, count: 128)
    
    private var isProcessing = false
    private var exit = false
    
    init(
        resetExchangeCallback: @escaping () -> Void,
        comletion: @escaping GetECGCompletion,
        оnFailure: @escaping OnFailure
    ) {
        self.resetExchangeCallback = resetExchangeCallback
        self.comletion = comletion
        self.оnFailure = оnFailure
        Task {
            decodeTask()
        }
    }
    
    private func startTimer() {
        DispatchQueue.main.async {
            self.isProcessing = true
            if let timer = self.timer {
                timer.invalidate()
                self.timer = nil
            }
            self.timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { timer in
                DispatchQueue.main.async {
                    if self.isProcessing {
                        self.exit = true
                        self.оnFailure(.timeout)
                        self.resetExchangeCallback()
                    }
                }
            })
        }
    }
    
    private func stopTimer() {
        self.isProcessing = false
    }
    
    /// Copy data from ``incomingDataQueue`` to array from specific index and with given length
    /// - Parameters:
    ///   - copyTo: array copy data to
    ///   - from: store data from this index in array
    ///   - length: length to store data from ``incomingDataQueue``
    private func copyDataToDataStorage(copyTo: inout [UInt8], from: Int, length: Int) {
        var from = from, length = length, i = from
        
        while (i < (from + length) && !exit) {
            if (!incomingDataQueue.isEmpty) {
                guard let value = incomingDataQueue.dequeue() else { continue }
                copyTo[i] = value
                i += 1
            }
        }
    }
    
    private func decodeFirstPacket(data: [UInt8]) -> Int {
        let packetsCount = (UInt64(data[2]) << (8 * 5)) | (UInt64(data[3]) << (8 * 4)) | (UInt64(data[4]) << (8 * 3)) | (UInt64(data[5]) << (8 * 2)) | (UInt64(data[6]) << (8 * 1)) | UInt64(data[7])
        print("Packet count: \(packetsCount)")
        return Int(packetsCount)
    }
    
    private func decodeTask() {
        copyDataToDataStorage(copyTo: &dataStorage, from: 0, length: 13)
        let data = Array(dataStorage.prefix(13))
        print("First packet: \(data)")
        if DataSerializer.crc(data) != data[data.count - 1] {
//            stopTimer()
            оnFailure(.invalidCrc)
            resetExchangeCallback()
            return
        }
        let packetsCount = decodeFirstPacket(data: data)
        for i in 0...packetsCount {
//            startTimer()
            copyDataToDataStorage(copyTo: &dataStorage, from: 0, length: 101)
            let data = Array(dataStorage.prefix(101))
            print("Packet: \(i), Data: \(data), Data count: \(data.count)")
            if DataSerializer.crc(data) != data[data.count - 1] {
//                stopTimer()
                оnFailure(.invalidCrc)
                resetExchangeCallback()
                return
            }
        }
    }
    
    public func onDataReceived(data: [UInt8]) {
        for b in data {
            incomingDataQueue.enqueue(b)
        }
    }
}
