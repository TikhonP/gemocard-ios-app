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
    
    public static func applyFilters(bytes: [UInt32], filters: [Filter]) -> [Double] {
        var inputBytes = bytes.map { Double($0) }
        var outputBytes = bytes.map { Double($0) }
        for filter in filters {
            outputBytes = filter.filterBuf(inputArray: inputBytes)
            inputBytes = outputBytes
        }
        return outputBytes
    }
}
