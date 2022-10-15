//
//  Filter.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 13.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

protocol Filter {
    func filterBuf(inputArray: [Double]) -> [Double];
}
