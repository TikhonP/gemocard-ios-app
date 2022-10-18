//
//  ECGfilter.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 13.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

struct FilterMode {
    let compFilter: Bool
    let hp1Filter:  Bool
    let lp35Filter: Bool
    let bs50Filter: Bool
    let lp75Filter: Bool
}

class ECGfilter {
    
    public static func getFilterFactory(_ sampleRate: SampleRate) -> FilterFactory? {
        switch sampleRate {
        case .sr417_5:
            return FilterFactory418()
        case .sr500:
            return FilterFactory500()
        case .sr1000:
            return FilterFactory1000()
        case .unknown:
            return nil
        }
    }
    
    public static func getReportDafultPdfFilters() -> FilterMode {
        let filterMode = FilterMode(
            compFilter: true,
            hp1Filter: true,
            lp35Filter: true,
            bs50Filter: true,
            lp75Filter: true
        )
        return filterMode
    }
    
    public static func getMyCustomFilters() -> FilterMode {
        let filterMode = FilterMode(
            compFilter: false,
            hp1Filter: true,
            lp35Filter: true,
            bs50Filter: false,
            lp75Filter: false
        )
        return filterMode
    }
    
    public static func getFilterComposition(filterFactory: FilterFactory, filterMode: FilterMode) -> [Filter] {
        var filters: [Filter] = []
        if filterMode.compFilter {
            filters.append(filterFactory.getCompFilter())
        }
        if filterMode.hp1Filter {
            filters.append(filterFactory.getFIR_HP_1Hz())
        }
        if filterMode.lp35Filter {
            filters.append(filterFactory.getFIR_LP_35Hz())
        }
        if filterMode.bs50Filter {
            filters.append(filterFactory.getFIR_BS_50Hz())
        }
        if filterMode.lp75Filter {
            filters.append(filterFactory.getFIR_LP_75Hz())
        }
        return filters
    }
    
    public static func applyFilters(bytes: [Double], filters: [Filter]) -> [Double] {
        var inputBytes = bytes
        var outputBytes = bytes
        for filter in filters {
            outputBytes = filter.filterBuf(inputArray: inputBytes)
            inputBytes = outputBytes
        }
        return outputBytes
    }
    
    public static func processEcgDataWithZeros(bytes: [UInt32], sampleRate: SampleRate) -> [Double] {
        
        var ecgSplittedData: [([UInt32], Int)] = []
        
        var currentArray: [UInt32] = []
        var currentZerosCount = 0
        
        for b in bytes {
            if b == 0 {
                if !currentArray.isEmpty {
                    currentZerosCount += 1
                }
            } else {
                if currentZerosCount == 0 {
                    currentArray.append(b)
                } else {
                    ecgSplittedData.append((currentArray, currentZerosCount))
                    currentArray = []
                    currentZerosCount = 0
                }
            }
        }
    
        guard let filterFactory = ECGfilter.getFilterFactory(sampleRate) else {
            print("Unknown Sample Rate!")
            return []
        }
        
        let filtersSet = ECGfilter.getReportDafultPdfFilters()
        let filters = ECGfilter.getFilterComposition(filterFactory: filterFactory, filterMode: filtersSet)
        
        var outputData: [Double] = []
        for sample in ecgSplittedData {
            
            let sampleData = sample.0.map { Double($0) * 0.000745 }
            let processedSample = ECGfilter.applyFilters(bytes: sampleData, filters: filters)
            outputData = outputData + processedSample + [Double](repeating: 0, count: sample.1)
        }
        
        return outputData
    }
    
    public static func processEcgDataWithoutZeros(bytes: [UInt32], sampleRate: SampleRate) -> [Double] {
        guard let filterFactory = ECGfilter.getFilterFactory(sampleRate) else {
            print("Unknown Sample Rate!")
            return []
        }
        let filtersSet = ECGfilter.getReportDafultPdfFilters()
        let filters = ECGfilter.getFilterComposition(filterFactory: filterFactory, filterMode: filtersSet)
        
        let filteredBytes = bytes.filter { return $0 != 0}
        let doubleFilteredBytes = filteredBytes.map { Double($0) * 0.000745 }
        
        return ECGfilter.applyFilters(bytes: doubleFilteredBytes, filters: filters)
    }
}
