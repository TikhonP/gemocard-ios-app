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
            Text("\(measurement.diastolicBloodPressure) / \(measurement.systolicBloodPressure)")
                .font(.headline)
                .padding(.trailing, 1)
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
}

//struct RecordLabel_Previews: PreviewProvider {
//    static var previews: some View {
//        RecordLabel()
//    }
//}
