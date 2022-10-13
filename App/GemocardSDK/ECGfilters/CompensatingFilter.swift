//
//  CompensatingFilter.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 13.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

class CompensatingFilter: Filter {
    
    /// 2 sec
    private let TIME_FILTER: Double = 2
    
    /// 5 mv
    private let RESET_MV: Double = 25
    private let frequency: Double
    
    private var offset: Double = 0;
    
    
    init(frequency: Double) {
        self.frequency = frequency
    }
    
    public func filterBuf(inputArray: [Double]) -> [Double] {
        var outputArray = [Double](repeating: 0, count: inputArray.count)
        offset = inputArray[0];
        for i in 0..<inputArray.count {
            if (abs(inputArray[i] - offset) > RESET_MV) { // reset offset
                offset = inputArray[i];
            } else {
                offset = offset - ((offset - inputArray[i]) / (TIME_FILTER * frequency))
            }
            outputArray[i] = inputArray[i] - offset;
        }
        return outputArray;
    }
}
