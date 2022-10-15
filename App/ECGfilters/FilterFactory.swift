//
//  FilterFactory.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 13.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

protocol FilterFactory {
    func getCompFilter() -> Filter;
    
    func getFIR_HP_1Hz() -> Filter;
    
    func getFIR_LP_35Hz() -> Filter;
    
    func getFIR_BS_50Hz() -> Filter;
    
    func getFIR_LP_75Hz() -> Filter;
}
