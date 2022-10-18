//
//  EcgWaveformView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 15.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct EcgWaveformView: View {
    let data: [Double]
    let sampleRate: Double
    
    @State private var chartColor: Color = .pink
    @State private var interpolationMethod: InterpolationMethod = .cardinal
    
    var body: some View {
        Chart(Array(data.enumerated()), id: \.element) {  index, element in
            LineMark(
                x: .value("Seconds", Double(index)/sampleRate),
                y: .value("mV", element)
            )
            .lineStyle(StrokeStyle(lineWidth: 1.0))
            .foregroundStyle(chartColor)
            .interpolationMethod(interpolationMethod)
            .accessibilityLabel("\(Double(index)/sampleRate) s")
            .accessibilityValue("\(element) mV")
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 12)) { value in
                if let doubleValue = value.as(Double.self),
                   let intValue = value.as(Int.self) {
                    if doubleValue - Double(intValue) == 0 {
                        AxisTick(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                        AxisValueLabel() {
                            Text("\(intValue) s")
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
        //        .accessibilityChartDescriptor(self)
    }
}

@available(iOS 16.0, *)
struct ecgWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        EcgWaveformView(data: [1, 2, 3, 4, 5, 6, 7, 15, 2, 3, 4], sampleRate: 5)
            .frame(width: 1600, height: 400)
    }
}
