//
//  RecordView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI
import Charts

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

struct RecordView: View {
    let measurement: Measurement
    let dateFormatter: DateFormatter
    
    init(measurement: Measurement) {
        self.measurement = measurement
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
                
                if #available(iOS 16.0, *) {
                    if measurement.ecgData != nil  {
                        Section(header: Text("Volumes")) {
//                            ScrollView(.horizontal) {
                                Chart(Array(zip(data().indices, data())), id: \.0) { index, item in
                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("ECG value", item)
                                    )
                                }
                                .frame(height: 200)
//                            }
                        }
                    }
                }
                
            }
            .navigationBarTitle("Measurement")
        }
    }
     
    func data() -> [Double] {
        guard let ecgData = measurement.ecgData else { return [] }
        let sampleRate = SampleRate(rawValue: UInt8(measurement.sampleRate)) ?? .unknown
        let filterFactory = ECGfilter.getFilterFactory(sampleRate)!
        let filtersSet = ECGfilter.getReportDafultPdfFilters()
        let filters = ECGfilter.getFilterComposition(filterFactory: filterFactory, filterMode: filtersSet)
        let data = ECGfilter.applyFilters(bytes: ecgData, filters: filters)
        return Array(data[1000..<1200])
    }
}

//struct RecordView_Previews: PreviewProvider {
//    static var previews: some View {
//        RecordView()
//    }
//}
