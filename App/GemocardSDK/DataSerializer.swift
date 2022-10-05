//
//  DataSerializer.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 05.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

/// All data in bytes to send to Gemocard
class DataSerializer {
    
    /// CRC-8 Maxim/Dallas Algorithm
    /// - Parameter byteArray: input byte array
    /// - Returns: int8 hash
    class func crc(_ byteArray: [UInt8]) -> UInt8 {
        var check: UInt8 = byteArray[0]
        for var byte in byteArray.prefix(byteArray.count - 1) {
            for _ in 0...7 {
                let odd = ((byte^check) & 1) == 1
                check >>= 1
                byte >>= 1
                if (odd) {
                    check ^= 0x8C
                }
            }
        }
        return check
    }
    
    class func deviceStatusQuery() -> Data {
        var bytes: [UInt8] = [0xAA, 0x03, 0x01, 0]
        bytes[3] = DataSerializer.crc(bytes)
        return Data(bytes)
    }
}
