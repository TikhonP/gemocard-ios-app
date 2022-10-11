//
//  Alerts.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation
import SwiftUI

struct ErrorInfo: Identifiable {
    var id = UUID()
    let title: String
    let description: String
}

class ErrorAlerts: NSObject {
    static let error = ErrorInfo(
        title: LocalizedStringKey("Ops! Something bad happened!").stringValue(),
        description: LocalizedStringKey("Detailed information about this error has automaticly been recordedand we have been notified.").stringValue())
    static let invalidPeriferal = ErrorInfo(
        title: LocalizedStringKey("Ops! Invalid peripheral found!").stringValue(),
        description: LocalizedStringKey("Detailed information about this error has automaticly been recordedand we have been notified.").stringValue())
    static let serviceNotFound = ErrorInfo(
        title: LocalizedStringKey("Ops! Bluetooth service on peripheral device not found!").stringValue(),
        description: LocalizedStringKey("Detailed information about this error has automaticly been recordedand we have been notified.").stringValue())
    static let deviceIsNotReady = ErrorInfo(
        title: LocalizedStringKey("Device is not ready").stringValue(),
        description: LocalizedStringKey("Try to reload application.").stringValue())
    static let disconnected = ErrorInfo(
        title: LocalizedStringKey("Device disconnected").stringValue(), description: "")
}
