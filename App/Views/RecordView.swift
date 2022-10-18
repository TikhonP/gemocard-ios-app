//
//  RecordView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI
import QuickLook

//struct PreviewController: UIViewControllerRepresentable {
//    typealias UIViewControllerType = UINavigationController
//
//    let url: URL
//    @Binding var isPresented: Bool
//
//    func makeUIViewController(context: Context) -> UINavigationController {
//        let controller = QLPreviewController()
//        controller.dataSource = context.coordinator
//        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
//            barButtonSystemItem: .done, target: context.coordinator,
//            action: #selector(context.coordinator.dismiss)
//        )
//
//        let navigationController = UINavigationController(
//            rootViewController: controller
//        )
//        return navigationController
//    }
//
//    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
//
//    class Coordinator: QLPreviewControllerDataSource {
//        let parent: PreviewController
//
//        init(parent: PreviewController) {
//            self.parent = parent
//        }
//
//        func numberOfPreviewItems(
//            in controller: QLPreviewController
//        ) -> Int {
//            return 1
//        }
//
//        func previewController(
//            _ controller: QLPreviewController,
//            previewItemAt index: Int
//        ) -> QLPreviewItem {
//            return parent.url as NSURL
//        }
//
//        @objc func dismiss() {
//            parent.isPresented = false
//        }
//    }
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(parent: self)
//    }
//}

struct RecordView: View {
    let measurement: Measurement
    let dateFormatter: DateFormatter
    let data: [Double]
    
    @State private var fileURL: URL?
    
    @State private var showingPreview = false
    
    init(measurement: Measurement) {
        self.measurement = measurement
        self.data = RecordView.getData(measurement: measurement)
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        List {
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
                        Text("Standard measurement")
                    }
                }
            }
            
            if getDeviceOperatingMode() != .Electrocardiogram {
                Section(header: Text("Blood Pressure")) {
                    VStack(alignment: .leading) {
                        Text("Diastolic Blood Pressure")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.pink)
                            Text("\(measurement.bloodPressureDiastolic) mmHg")
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Systolic Blood Pressure")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.pink)
                            Text("\(measurement.bloodPressureSystolic) mmHg")
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Heart Rate")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                            Text("\(measurement.heartRate) bpm")
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
            }
            
            if getDeviceOperatingMode() != .arterialPressure {
                Section(header: Text("ECG waveform")) {
                    if (!data.isEmpty) {
                        ScrollView(.horizontal) {
                            if #available(iOS 16.0, *) {
                                EcgWaveformView(data: data, sampleRate: sampleRate())
                                    .frame(width: 1500, height: 300)
                            } else {
                                Text("To view ECG waveform update your device up to iOS 16")
                            }
                        }
                    } else {
                        Text("No ECG data")
                    }
                }
            }
        }
        .navigationBarTitle("Measurement")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if #available(iOS 16.0, *) {
                    Button(action: {
                        self.fileURL = exportPDF()
                        if let fileURL = self.fileURL {
                            let _ = share(items: [fileURL])
                        }
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                            if self.fileURL != nil {
//                                self.showingPreview = true
//                            }
//                        }
                    }, label: { Image(systemName: "square.and.arrow.up") })
//                    .sheet(isPresented: $showingPreview) {
//                        if self.fileURL != nil {
//                            PreviewController(
//                                url: self.fileURL!,
//                                isPresented: self.$showingPreview
//                            )
//                        }
//                    }
                    
                }
            }
        }
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
    
    private func printECGdata() {
        guard let ecgData = measurement.ecgData else { return }
        let sampleRate = SampleRate(rawValue: UInt8(measurement.sampleRate)) ?? .unknown
        let data = ECGfilter.processEcgDataWithoutZeros(bytes: ecgData, sampleRate: sampleRate)
        print("ECG length: \(ecgData.count), processed length: \(data.count), sample rate: \(sampleRate)")
        print(ecgData)
        print(data)
    }
    
    @available(iOS 16.0, *)
    @MainActor
    private func exportPDF() -> URL? {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let renderedUrl = documentDirectory.appending(path: "Heart Rate Waveform ECG.pdf")
        guard let consumer = CGDataConsumer(url: renderedUrl as CFURL),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return nil
        }
        let renderer = ImageRenderer(content: HeartRateEcgWaveformPdfView(measurement: measurement))
        renderer.render { size, renderer in
            let options: [CFString: Any] = [
                kCGPDFContextMediaBox: CGRect(origin: .zero, size: size)
            ]
            
            pdfContext.beginPDFPage(options as CFDictionary)
            
            renderer(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }
        print("Saving PDF to \(renderedUrl.path())")
        
        return  renderedUrl
    }
    
    private func share(items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) -> Bool {
        guard let source = UIApplication.shared.windows.last?.rootViewController else {
            return false
        }
        let vc = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        vc.excludedActivityTypes = excludedActivityTypes
        vc.popoverPresentationController?.sourceView = source.view
        source.present(vc, animated: true)
        return true
    }
}

//struct RecordView_Previews: PreviewProvider {
//    static var previews: some View {
//        RecordView()
//    }
//}
