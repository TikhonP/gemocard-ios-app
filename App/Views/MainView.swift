//
//  MainView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 05.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI

struct MainView: View {
    
    // MARK: - View varibles
    
    @EnvironmentObject private var gemocardKit: GemocardKit
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)], animation: .default)
    private var measurements: FetchedResults<Measurement>
    
    @State private var showSettingsModal: Bool = false
    @State private var isPresentedDeviceList: Bool = false
    
    // MARK: - View body
    
    var body: some View {
        NavigationView {
            VStack {
                inlineAlerts
//                testFormButtons
                if measurements.isEmpty {
                    noMeasurements
                } else {
                    measurementsList
                }
            }
            .transition(.slide)
            .animation(.easeInOut(duration: 0.3), value: gemocardKit.showBluetoothIsOffWarning)
            .animation(.easeInOut(duration: 0.3), value: gemocardKit.fetchingDataWithGemocard)
            .animation(.easeInOut(duration: 0.3), value: gemocardKit.showSelectDevicesInfo)
            .navigationBarTitle { navigationBarTitle }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if gemocardKit.isBluetoothOn {
                        if !gemocardKit.isConnected {
                            Button {
                                isPresentedDeviceList.toggle()
                            } label: {
                                HStack {
                                    if #available(iOS 15.0, *) {
                                        Text("Devices")
                                            .badge(gemocardKit.devices.count)
                                            .id(UUID())
                                    } else {
                                        Text("Devices")
                                            .id(UUID())
                                        // TODO: Add badge on earlier versions
                                    }
                                }
                            }
                        } else {
                            Button(action: { showSettingsModal.toggle() }, label: {
                                Image(systemName: "gearshape") })
                            .id(UUID())
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showSettingsModal, content: { SettingsView(isPresented: $showSettingsModal) })
        .sheet(isPresented: $isPresentedDeviceList, content: { ConnectView(isPresented: $isPresentedDeviceList) })
        .onReceive(gemocardKit.$isConnected) { flag in
            if flag { isPresentedDeviceList = false }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.gemocardKit.discover()
            }
        }
    }
    
    // MARK: - Additional Views
    
    private var navigationBarTitle: some View {
        HStack {
            if !gemocardKit.isConnected || !gemocardKit.isBluetoothOn || gemocardKit.fetchingDataWithGemocard {
                ProgressView()
                    .padding(.trailing, 1)
            }
            Text(gemocardKit.navigationBarTitleStatus)
        }
    }
    
    private var inlineAlerts: some View {
        ZStack {
            if gemocardKit.showBluetoothIsOffWarning {
                Text("To connect the spirometer, turn on the bluetooth and give the app permission to use it.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            if gemocardKit.showSelectDevicesInfo {
                HStack(alignment: .top) {
                    Spacer()
                    Text("Click here and select the spirometer to connect.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Text("👆")
                }
                .padding()
            }
        }
    }
    
    private var noMeasurements: some View {
        VStack(alignment: .center) {
            Spacer()
            Text("No measurements recorded")
                .font(.title2)
                .fontWeight(.bold)
            Text("Take measurements with a spirometer so they appear here.")
                .font(.body)
                .foregroundColor(Color.gray)
                .multilineTextAlignment(.center)
                .padding(.leading, 40)
                .padding(.trailing, 40)
            Spacer()
        }
    }
    
    private var measurementsList: some View {
        List {
            Section(header: Text("Measurements")) {
                ForEach(measurements) { measurement in
                    NavigationLink {
                        RecordView(measurement: measurement)
                    } label: {
                        RecordLabel(measurement: measurement)
                    }
                }
                .onDelete(perform: deleteMeasurements)
            }
        }
    }
    
    private var testFormButtons: some View {
        ZStack {
            Form {
                Section {
                    Button(action: gemocardKit.action) {
                        Text("lolkek")
                    }
                }
                
                Section {
                    Button(action: gemocardKit.getDeviceStatus) { Text("Получить статус") }
                    Button(action: gemocardKit.startMeasurement) { Text("Начать измерение") }
                    Button(action: gemocardKit.setDateTime) { Text("Настроить время") }
                    Button(action: gemocardKit.getDateTime) { Text("Получить время устройства") }
                    Button(action: gemocardKit.getNumberOfMeasurements) { Text("Получть количество измерений") }
                    Button(action: gemocardKit.getData) { Text("Загрузить данные") }
                    Button(action: gemocardKit.getHeaderResultsNumberOfPreviousMeasurement) { Text("Загрузить N хедер измерение") }
                    Button(action: {
                        gemocardKit.getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: 1)
                    }) {
                        Text("Загрузить N измерение")
                    }
                    Button(action: gemocardKit.getResultsNumberOfPreviousECG) { Text("Загрузить N ЭКГ") }
                    Button(action: gemocardKit.requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG) { Text("Узнать устанорвленное количество пакетов по 98 байт") }
                }
            }
        }
    }
    
    // MARK: - private functions
    
    private func deleteMeasurements(offsets: IndexSet) {
        withAnimation {
            offsets.map { measurements[$0] }.forEach(viewContext.delete)
            saveCoreData()
        }
    }

    private func saveCoreData() {
        do {
            try viewContext.save()
        } catch {
            print("Core Data failed to save model: \(error.localizedDescription)")
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
