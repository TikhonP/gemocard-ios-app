//
//  RecordView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
enum ChartInterpolationMethod: Identifiable, CaseIterable {
    case linear
    case monotone
    case catmullRom
    case cardinal
    case stepStart
    case stepCenter
    case stepEnd
    
    var id: String { mode.description }
    
    var mode: InterpolationMethod {
        switch self {
        case .linear:
            return .linear
        case .monotone:
            return .monotone
        case .stepStart:
            return .stepStart
        case .stepCenter:
            return .stepCenter
        case .stepEnd:
            return .stepEnd
        case .catmullRom:
            return .catmullRom
        case .cardinal:
            return .cardinal
        }
    }
}

struct ValueRowView: View {
    let key: String
    let value: Text
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(key)
                .font(.subheadline)
                .foregroundColor(.gray)
            value
        }
    }
}

@available(iOS 16.0, *)
struct RecordView: View {
    let measurement: Measurement
    let dateFormatter: DateFormatter
    let data: [Double]
    
    @State private var lineWidth = 1.0
    @State private var interpolationMethod: ChartInterpolationMethod = .cardinal
    @State private var chartColor: Color = .pink
    
    init(measurement: Measurement) {
        self.measurement = measurement
        self.data = RecordView.getData(measurement: measurement)
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Details")) {
                    ValueRowView(key: "Measurement time", value: Text(measurement.date!, formatter: dateFormatter))
                }
                
                Section(header: Text("Blood Pressure")) {
                    ValueRowView(key: "Diastolic Blood Pressure", value: Text("\(measurement.diastolicBloodPressure)"))
                    ValueRowView(key: "Systoluc Blood Pressure", value: Text("\(measurement.systolicBloodPressure)"))
                    ValueRowView(key: "Pulse", value: Text("\(measurement.pulse)"))
                }
                
                Section {
                    if (!data.isEmpty) {
                        chartAndLabels
                    } else {
                        Text("No ECG")
                    }
                }
            }
            .navigationBarTitle("Measurement")
        }
    }
    
    private var chartAndLabels: some View {
        VStack(alignment: .leading) {
            Text("Sinus Rhythm")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            Group {
                Text(measurement.date!, style: .date) +
                Text(" at ") +
                Text(measurement.date!, style: .time)
            }
            .foregroundColor(.secondary)
            ScrollView(.horizontal) {
                chart
            }
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                Text("\(measurement.pulse) BPM Average")
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 400)
    }
    
    private var chart: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.element) { index, element in
                LineMark(
                    x: .value("Seconds", Double(index)/sampleRate()),
                    y: .value("Unit", element)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.0))
                .foregroundStyle(chartColor)
                .interpolationMethod(interpolationMethod.mode)
                .accessibilityLabel("\(Double(index)/sampleRate()) s")
                .accessibilityValue("\(element) mV")
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 12)) { value in
                if let doubleValue = value.as(Double.self),
                   let intValue = value.as(Int.self) {
                    if doubleValue - Double(intValue) == 0 {
                        AxisTick(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                        AxisValueLabel() {
                            Text("\(intValue)s")
                        }
                        AxisGridLine(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                    } else {
                        AxisGridLine(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray.opacity(0.25))
                    }
                }
            }
        }
        .chartYScale(domain: (data.min()! - 1)...(data.max()! + 1))
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 14)) { value in
                if let doubleValue = value.as(Double.self),
                   let intValue = value.as(Int.self) {
                    if doubleValue - Double(intValue) == 0 {
                        AxisTick(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                        AxisValueLabel() {
                            Text("\(intValue) mV")
                        }
                    }
                    AxisGridLine(stroke: .init(lineWidth: 1))
                        .foregroundStyle(.gray.opacity(0.25))
                }
            }
        }
        .chartPlotStyle {
            $0.border(Color.gray)
        }
        .frame(width: 1500)
//        .accessibilityChartDescriptor(self)
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
    
    private func printECGdata() {
        guard let ecgData = measurement.ecgData else { return }
        let sampleRate = SampleRate(rawValue: UInt8(measurement.sampleRate)) ?? .unknown
        let data = ECGfilter.processEcgDataWithoutZeros(bytes: ecgData, sampleRate: sampleRate)
        print("ECG length: \(ecgData.count), processed length: \(data.count), sample rate: \(sampleRate)")
        print(ecgData)
        print(data)
    }
}

//struct RecordView_Previews: PreviewProvider {
//    static var previews: some View {
//        RecordView()
//    }
//}
