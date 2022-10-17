//
//  HeartRateEcgWaveformPdfView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 15.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI

struct HeartRateEcgWaveformPdfView: View {
    let measurement: Measurement
    let dateFormatter: DateFormatter
    let data: [Double]
    
    init(measurement: Measurement) {
        self.measurement = measurement
        self.data = HeartRateEcgWaveformPdfView.getData(measurement: measurement)
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Section(header: Text("Details")) {
                VStack(alignment: .leading) {
                    Text("Measurement time")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(measurement.date!, formatter: dateFormatter)
                }
                
                VStack(alignment: .leading) {
                    Text("Operating Mode")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    switch getDeviceOperatingMode() {
                    case .Electrocardiogram:
                        Text("Electrocardiogram")
                    case .arterialPressure:
                        Text("Arterial pressure")
                    case .arterialPressureAndElectrocardiogram:
                        Text("Arterial pressure and electrocardiogram")
                    case .unknown:
                        Text("Reading data error")
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Series status")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    if measurement.measMode {
                        Text("Series measurement")
                    } else {
                        Text("Usual measurement")
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading) {
                    Text("Diastolic Blood Pressure")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.pink)
                        Text("\(measurement.diastolicBloodPressure) mmHg")
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Systoluc Blood Pressure")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.pink)
                        Text("\(measurement.systolicBloodPressure) mmHg")
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Heart Rate")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                        Text("\(measurement.pulse) BPM")
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Arrhythmia")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.pink)
                        switch getArrhythmiaStatus() {
                        case .noRhythmDisturbances:
                            Text("No rhythm disturbances")
                        case .singleRhythmDisorder:
                            Text("Single rhythm disorder (\(measurement.rhythmDisturbances) times)")
                        case .repeatedRhythmDisturbances:
                            Text("Repeated rhythm disturbances (\(measurement.rhythmDisturbances) times)")
                        case .prolongedArrhythmia:
                            Text("Prolonged arrhythmia (\(measurement.rhythmDisturbances)%)")
                        case .unknown:
                            Text("Reading data error")
                        }
                    }
                }
            }
            
            Spacer()
            
            Section {
                if (!data.isEmpty) {
                    if #available(iOS 16.0, *) {
                        EcgWaveformView(data: Array(data[Int(data.count/2)...]), sampleRate: sampleRate())
                            .frame(width: 580, height: 200)
                        EcgWaveformView(data: Array(data[...Int(data.count/2)]), sampleRate: sampleRate())
                            .frame(width: 580, height: 200)
                    } else {
                        Text("Not availible ECG waveform")
                    }
                    
                } else {
                    Text("Reading ECG error")
                }
            }
        }
        .padding()
    }
    
    private func getArrhythmiaStatus() -> ArrhythmiaStatus {
        return ArrhythmiaStatus(rawValue: UInt8(measurement.arrhythmiaStatus)) ?? .unknown
    }
    
    private func getDeviceOperatingMode() -> DeviceOperatingMode {
        return DeviceOperatingMode(rawValue: UInt8(measurement.deviceOperatingMode)) ?? .unknown
    }
    
    private func sampleRate() -> Double {
        let sampleRate = SampleRate(rawValue: UInt8(measurement.sampleRate)) ?? .unknown
        switch sampleRate {
        case .sr417_5:
            return 418
        case .sr500:
            return 500
        case .sr1000:
            return 1000
        case .unknown:
            return 1
        }
    }
    
    private static func getData(measurement: Measurement) -> [Double] {
        guard let ecgData = measurement.ecgData else { return [] }
        let sampleRate = SampleRate(rawValue: UInt8(measurement.sampleRate)) ?? .unknown
        let data = ECGfilter.processEcgDataWithoutZeros(bytes: ecgData, sampleRate: sampleRate)
        return data
    }
}

//struct heartRateEcgWaveformPdfView_Previews: PreviewProvider {
//    static var previews: some View {
//        HeartRateEcgWaveformPdfView()
//    }
//}
