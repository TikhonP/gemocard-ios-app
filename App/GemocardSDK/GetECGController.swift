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
    
    /// ECG/measurement number in device memory
    private let ecgNumber: UInt8
    
    private let resetExchangeCallback: () -> Void
    private let writeValueCallback: WriteValueCallback
    private let comletion: GetECGCompletion
    private let оnFailure: OnFailure

    /// All incoming data stores here
    private var incomingDataQueue = AsyncQueue<UInt8>()
    
    /// 24 bytes packet holder
    ///
    /// The 24 bytes packet,evry point 3 bytes, It's 8 point:
    /// 1. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// 2. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// 3. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// 4. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// 5. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// 6. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// 7. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// 8. [8MSBs, 8MidBs, 8LSBs] - 3 bytes
    /// - And 25th byte is status with ``DeviceStatus``
    private var packet: [UInt8] = []
    
    /// Electrocardiogram points
    private var ecgData: [UInt32] = []
    
    /// Status points of ``DeviceStatus``
    private var ecgStatusData: [UInt8] = []
    
    init(
        ECGnumber: UInt8,
        resetExchangeCallback: @escaping () -> Void,
        writeValueCallback: @escaping WriteValueCallback,
        comletion: @escaping GetECGCompletion,
        оnFailure: @escaping OnFailure
    ) {
        self.ecgNumber = ECGnumber
        self.resetExchangeCallback = resetExchangeCallback
        self.writeValueCallback = writeValueCallback
        self.comletion = comletion
        self.оnFailure = оnFailure
        Task { mainTask() }
    }
    
    private func threeBytesToInt(MSBs: UInt8, MidBs: UInt8, LSBs: UInt8) -> UInt32 {
        return (UInt32(MSBs) << (8 * 2)) | (UInt32(MidBs) << 8) | UInt32(LSBs)
    }
    
    private func decodeFirstPacket(data: [UInt8]) -> UInt16 {
        let packetsCount = DataSerializer.twoBytesToInt(MSBs: data[2], LSBs: data[3])
//        let lastPacketSize = DataSerializer.twoBytesToInt(MSBs: data[4], LSBs: data[5])
        return packetsCount
    }
    
    private func process25bytesPacket(bytes: [UInt8]) {
        ecgStatusData.append(bytes[0])
        var singleDot: [UInt8] = []
        for b in bytes[1...] {
            singleDot.append(b)
            if singleDot.count == 3 {
                let value = threeBytesToInt(MSBs: singleDot[0], MidBs: singleDot[1], LSBs: singleDot[2])
                ecgData.append(UInt32(value))
                singleDot = []
            }
        }
    }
    
    private func process98bytePacket(bytes: [UInt8]) {
        for b in bytes {
            packet.append(b)
            if packet.count == 25 {
                process25bytesPacket(bytes: packet)
                packet = []
            }
        }
    }
    
    private func waitForDataInQueueAndGet(_ length: Int) -> [UInt8] {
        while incomingDataQueue.getlength() != length { }
        return incomingDataQueue.getElementsAndClear()
    }
    
    private func mainTask() {
        incomingDataQueue.clear()
        writeValueCallback(DataSerializer.getResultsNumberOfPreviousECG(numberOfPreviousECG: ecgNumber, packetNumber: 65535))
        let data = waitForDataInQueueAndGet(13)
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
        for currentPacketNumber: UInt16 in 1...packetsCount {
            writeValueCallback(DataSerializer.getResultsNumberOfPreviousECG(numberOfPreviousECG: ecgNumber, packetNumber: currentPacketNumber))
            let data = waitForDataInQueueAndGet(101)
            if DataSerializer.crc(data) != data[data.count - 1] {
                оnFailure(.invalidCrc)
                resetExchangeCallback()
                return
            }
            process98bytePacket(bytes: Array(data[2 ..< 100]))
        }
        comletion(ecgData, ecgStatusData)
        resetExchangeCallback()
    }
    
    public func onDataReceived(bytes: [UInt8]) {
        incomingDataQueue.enqueueArray(bytes)
    }
}
