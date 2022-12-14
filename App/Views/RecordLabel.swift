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
            Spacer()
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
                if measurement.ecgData != nil {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .foregroundColor(.pink)
                }
            }
            if !isEcgMeasurement {
                Spacer()
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("\(measurement.heartRate) bpm")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            Spacer()
            HStack {
                Image(systemName: "clock")
                Text("\(measurement.date!, formatter: dateFormatter)")
                Spacer()
            }
            .font(.caption)
            Spacer()
            
        }
        .frame(height: 23)
        .padding()
    }
    
    private var measurementHeader: String {
        let changeSeriesEndFlag = ChangeSeriesEndFlag(rawValue: UInt8(measurement.changeSeriesEndFlag))
        if changeSeriesEndFlag == .seriesCanceled {
            return LocalizedStringKey("Series Canceled").stringValue()
        } else if isEcgMeasurement {
            return LocalizedStringKey("ECG measurement").stringValue()
        } else {
            return "\(measurement.bloodPressureDiastolic) / \(measurement.bloodPressureSystolic)"
        }
    }
    
    private var isEcgMeasurement: Bool {
        let deviceOperatingMode = DeviceOperatingMode(rawValue: UInt8(measurement.deviceOperatingMode))
        return deviceOperatingMode == .Electrocardiogram
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
