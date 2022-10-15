//
//  FilterFIR.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 13.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

class FilterFIR: Filter {
    private var a: [Double]
    private var y: Double = 0
    private var x: [Double]
    private let Ntap: Int
    
    /// сколько точек нужно пропустить
    private var skip_points_need: Int
    
    /// сколько точек осталось пропустить
    private var skip_points_cur: Int
    
    init(processorArray: [Double], pSkipPoints: Int) {
        self.Ntap = processorArray.count
        self.a = processorArray
        self.x = [Double](repeating: 0, count: processorArray.count)
        self.skip_points_need = pSkipPoints
        self.skip_points_cur = pSkipPoints
    }
    
    func filterBuf(inputArray: [Double]) -> [Double] {
        var outputArray = [Double](repeating: 0, count: inputArray.count)
        
        for i in 0..<inputArray.count {
            for n in (1..<Ntap).reversed() {
                x[n] = x[n - 1]
            }
            
            x[0] = inputArray[i]
            y = 0
            
            for n in 0..<Ntap {
                y += a[n] * x[n]
            }
            outputArray[i] = y
        }
        
        if (skip_points_cur > 0) {
            let doSkipPoints = min(skip_points_cur, outputArray.count)
            
            let outArrSliced = Array(outputArray[doSkipPoints...])
            return outArrSliced;
        } else {
            return outputArray;
        }
    }
}
