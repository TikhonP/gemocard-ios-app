//
//  RecordLabel.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI

struct RecordLabel: View {
    @EnvironmentObject private var gemocardKit: GemocardKit
    
    let measurement: Measurement
    let dateFormatter: DateFormatter
    
    init(measurement: Measurement) {
        self.measurement = measurement
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(measurementHeader)
                    .font(.headline)
                    .padding(.trailing, 1)
                if gemocardKit.presentUploadToMedsenger {
                    if recordUploaded {
                        Image(systemName: "checkmark.icloud")
                    } else {
                        Image(systemName: "icloud.slash")
                    }
                }
            }
            Spacer()
            HStack {
                Image(systemName: "clock")
                Text("\(measurement.date!, formatter: dateFormatter)")
                Spacer()
            }
            .font(.caption)
        }
        .frame(height: 10)
        .padding()
    }
    
    var measurementHeader: String {
        let changeSeriesEndFlag = ChangeSeriesEndFlag(rawValue: UInt8(measurement.changeSeriesEndFlag))
        if changeSeriesEndFlag == .seriesCanceled {
            return "Series Canceled"
        } else {
            return "\(measurement.diastolicBloodPressure) / \(measurement.systolicBloodPressure)"
        }
    }
    
    private var recordUploaded: Bool {
        guard let lastUploadedDate = UserDefaults.lastMedsengerUploadedDate, let recordDate = measurement.date else {
            return false
        }
        return recordDate < lastUploadedDate
    }
}

//struct RecordLabel_Previews: PreviewProvider {
//    static var previews: some View {
//        RecordLabel()
//    }
//}
