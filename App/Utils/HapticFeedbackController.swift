//
//  HapticFeedbackController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation
import UIKit

class HapticFeedbackController {
    static let shared = HapticFeedbackController()
    
    func preparePlay() {
        UIImpactFeedbackGenerator().prepare()
    }
    
    func prepareNotify() {
        UINotificationFeedbackGenerator().prepare()
    }
    
    func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }
    
    func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
    }
    
    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
