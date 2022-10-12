//
//  GetDataController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 07.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

/// Controller for managing incoming data in exchange mode
class GetECGController {
    
    private let resetExchangeCallback: () -> Void
    private let comletion: GetECGCompletion
    private let оnFailure: OnFailure
    private let ECGnumber: UInt8
    private let writeValueCallback: WriteValueCallback
    
    /// All incoming data stores here
    private var incomingDataQueue = AsyncQueue<UInt8>()
    
    /// Buffer for holding specific data pieces from ``incomingDataQueue`` and process it
    private var dataStorage = [UInt8](repeating: 0, count: 256)
    
    private var packet: [UInt8] = []
    
    private var ECGdata: [UInt32] = []
    private var ECGStatusData: [UInt8] = []
    
    init(
        ECGnumber: UInt8,
        resetExchangeCallback: @escaping () -> Void,
        writeValueCallback: @escaping WriteValueCallback,
        comletion: @escaping GetECGCompletion,
        оnFailure: @escaping OnFailure
    ) {
        self.ECGnumber = ECGnumber
        self.resetExchangeCallback = resetExchangeCallback
        self.writeValueCallback = writeValueCallback
        self.comletion = comletion
        self.оnFailure = оnFailure
        Task { mainTask() }
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
    
    private func decodeFirstPacket(data: [UInt8]) -> UInt16 {
        let packetsCount = DataSerializer.twoBytesToInt(MSBs: data[2], LSBs: data[3])
//        let lastPacketSize = DataSerializer.twoBytesToInt(MSBs: data[4], LSBs: data[5])
        return packetsCount
    }
    
    private func threeBytesToInt(MSBs: UInt8, MidBs: UInt8, LSBs: UInt8) -> UInt32 {
        return (UInt32(MSBs) << (8 * 2)) | (UInt32(MidBs) << 8) | UInt32(LSBs)
    }
    
    private func process98bytePacket(bytes: [UInt8]) {
        for b in bytes {
            packet.append(b)
            if packet.count == 4 {
                let value = threeBytesToInt(MSBs: packet[0], MidBs: packet[1], LSBs: packet[2])
//                let status = BrokenElectrodesAndPacemaker(rawValue: packet[3])
                ECGdata.append(value)
                ECGStatusData.append(packet[3])
                packet = []
            }
        }
    }
    
    private func mainTask() {
        incomingDataQueue.clear()
        writeValueCallback(DataSerializer.getResultsNumberOfPreviousECG(numberOfPreviousECG: ECGnumber, packetNumber: 65535))
        copyDataToDataStorage(copyTo: &dataStorage, from: 0, length: 13)
        let data = Array(dataStorage.prefix(13))
        
        if DataSerializer.crc(data) != data[data.count - 1] {
            оnFailure(.invalidCrc)
            resetExchangeCallback()
            return
        }
        let packetsCount = decodeFirstPacket(data: data)
        if packetsCount < 1 {
            comletion(nil, nil)
            resetExchangeCallback()
            return
        }
        for i: UInt16 in 1...packetsCount {
            writeValueCallback(DataSerializer.getResultsNumberOfPreviousECG(numberOfPreviousECG: ECGnumber, packetNumber: i))
            copyDataToDataStorage(copyTo: &dataStorage, from: 0, length: 101)
            let data = Array(dataStorage.prefix(101))
            if DataSerializer.crc(data) != data[data.count - 1] {
                оnFailure(.invalidCrc)
                resetExchangeCallback()
                return
            }
            process98bytePacket(bytes: Array(data[2 ..< 100]))
        }
        comletion(ECGdata, ECGStatusData)
        resetExchangeCallback()
    }
    
    public func onDataReceived(bytes: [UInt8]) {
        for b in bytes {
            incomingDataQueue.enqueue(b)
        }
    }
}
