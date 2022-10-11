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
    private let numberOfPreviousECG: UInt8
    private let writeValueCallback: WriteValueCallback
    
    private var timer: Timer?
    
    /// All incoming data stores here
    private var incomingDataQueue = AsyncQueue<UInt8>()
    
    /// Buffer for holding specific data pieces from ``incomingDataQueue`` and process it
    private var dataStorage = [UInt8](repeating: 0, count: 256)
    
    private var isProcessing = false
    private var exit = false
    
    private var packet: [UInt8] = []
    private var packetCount: Int = 0
    
    init(
        numberOfPreviousECG: UInt8,
        resetExchangeCallback: @escaping () -> Void,
        writeValueCallback: @escaping WriteValueCallback,
        comletion: @escaping GetECGCompletion,
        оnFailure: @escaping OnFailure
    ) {
        self.numberOfPreviousECG = numberOfPreviousECG
        self.resetExchangeCallback = resetExchangeCallback
        self.writeValueCallback = writeValueCallback
        self.comletion = comletion
        self.оnFailure = оnFailure
        Task {
            mainTask()
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
    
    private func decodeFirstPacket(data: [UInt8]) -> UInt16 {
        let packetsCount = DataSerializer.twoBytesToInt(MSBs: data[2], LSBs: data[3])
        let lastPacketSize = DataSerializer.twoBytesToInt(MSBs: data[4], LSBs: data[5])
        print("Packet count: \(packetsCount), last packet size: \(lastPacketSize)")
        return packetsCount
    }
    
    private func threeBytesToInt(MSBs: UInt8, MidBs: UInt8, LSBs: UInt8) -> UInt32 {
        return (UInt32(MSBs) << (8 * 2)) | (UInt32(MidBs) << 8) | UInt32(LSBs)
    }
    
    private func process98bytePacket(data: [UInt8]) -> [UInt32] {
        var values: [UInt32] = []
        for b in data {
            packet.append(b)
            if packet.count == 4 {
                packetCount += 1
                let value = threeBytesToInt(MSBs: packet[0], MidBs: packet[1], LSBs: packet[2])
                let status = BrokenElectrodesAndPacemaker(rawValue: packet[3])
                print("Value: \(value), status: \(status)")
                values.append(value)
                packet = []
            }
        }
        return values
    }
    
    private func mainTask() {
        
        
        // Get first packet
        writeValueCallback(DataSerializer.getResultsNumberOfPreviousECG(numberOfPreviousECG: numberOfPreviousECG, packetNumber: 65535))
//        while incomingDataQueue.getlength() != 13 { }
//        let data = incomingDataQueue.getElementsAndClear()
        copyDataToDataStorage(copyTo: &dataStorage, from: 0, length: 13)
        let data = Array(dataStorage.prefix(13))
        
        print("First packet: \(data)")
        if DataSerializer.crc(data) != data[data.count - 1] {
            оnFailure(.invalidCrc)
            resetExchangeCallback()
            return
        }
        let packetsCount = decodeFirstPacket(data: data)
        
        for i: UInt16 in 1...packetsCount {
            writeValueCallback(DataSerializer.getResultsNumberOfPreviousECG(numberOfPreviousECG: numberOfPreviousECG, packetNumber: i))
            copyDataToDataStorage(copyTo: &dataStorage, from: 0, length: 101)
            let data = Array(dataStorage.prefix(101))
//            print("Packet: \(i), Data: \(data), Data count: \(data.count)")
            
//            print("Packet \(i)")
//            writeValueCallback(DataSerializer.getResultsNumberOfPreviousECG(numberOfPreviousECG: numberOfPreviousECG, packetNumber: i))
//            while incomingDataQueue.getlength() < 2 { }
//            let length = Int(incomingDataQueue.getElements[1]) + 1
//            while incomingDataQueue.getlength() != length { }
//            let data = incomingDataQueue.getElementsAndClear()
            
            //            print("Packet: \(i), Data: \(data), Data count: \(data.count)")
            if DataSerializer.crc(data) != data[data.count - 1] {
                оnFailure(.invalidCrc)
                resetExchangeCallback()
                return
            }
            process98bytePacket(data: Array(data[2 ..< 100]))
//            print(process98bytePacket(data: Array(data[2 ..< 100])), packetCount)
        }
        comletion([1, 2, 3])
    }
    
    public func onDataReceived(data: [UInt8]) {
        for b in data {
            incomingDataQueue.enqueue(b)
        }
    }
}
