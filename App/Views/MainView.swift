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
                progressView
                inlineAlerts
//                testFormButtons
                if measurements.isEmpty {
                    noMeasurements
                } else {
                    measurementsList
                }
            }
            .transition(.slide)
            .animation(.easeInOut(duration: 0.3), value: gemocardKit.progress)
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
                
                ToolbarItemGroup(placement: .bottomBar) {
                    if !measurements.isEmpty && gemocardKit.presentUploadToMedsenger {
                        HStack {
                            if gemocardKit.sendingToMedsengerStatus != 0 {
                                ProgressView()
                            }
                            Button("Upload to Medsenger", action: {
                                HapticFeedbackController.shared.play(.heavy)
                                gemocardKit.sendDataToMedsenger()
                            })
                        }
                    }
                    Spacer()
                    if gemocardKit.isConnected && !gemocardKit.fetchingDataWithGemocard {
                        Button(action: {
                            HapticFeedbackController.shared.play(.medium)
                            gemocardKit.getData()
                        }, label: { Image(systemName: "arrow.clockwise.circle") })
                    }
                    if !(!measurements.isEmpty && gemocardKit.presentUploadToMedsenger) {
                        Spacer()
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
    
    private var progressView: some View {
        ZStack {
            if gemocardKit.fetchingDataWithGemocard {
                ProgressView(value: gemocardKit.progress, total: 1)
                    .padding()
                Spacer()
            }
        }
    }
    
    private var inlineAlerts: some View {
        ZStack {
            if gemocardKit.showBluetoothIsOffWarning {
                Text("To connect the tonometer, turn on the bluetooth and give the app permission to use it.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            if gemocardKit.showSelectDevicesInfo {
                HStack(alignment: .top) {
                    Spacer()
                    Text("Click here and select the tonometer to connect.")
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
            Text("Take measurements with a tonometer so they appear here.")
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
