//
//  SettingsView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var gemocardKit: GemocardKit
    
    @Binding var isPresented: Bool
    @State private var saveUUID = UserDefaults.saveUUID
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connected device")) {
                    Text(gemocardKit.connectingPeripheral?.name ?? LocalizedStringKey("Unknown name").stringValue())
                    
                    if getDeviceOperatingMode() != .unknown {
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
                    }
                    
                    if getDeviceStatus() != .unknown {
                        VStack(alignment: .leading) {
                            Text("Device Status")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            switch getDeviceStatus() {
                            case .readyWaiting:
                                Text("Ready, waiting")
                            case .measurement:
                                Text("Measurement")
                            case .testMode:
                                Text("Test mode")
                            case .readyWaitingSeries:
                                Text("Ready, waiting, series measurement")
                            case .seriesMeasurement:
                                Text("Series measurement")
                            case .waitingNextSeriesMeasurement:
                                Text("Waiting for next series measurement")
                            case .unknown:
                                Text("Reading data error")
                            }
                        }
                    }
                    
//                    Button("Erase Device Memory", action: gemocardKit.eraseMemory)
                    
                    if UserDefaults.saveUUID {
                        Button("Forget device", action: forgetDevice)
                    } else {
                        Button("Disconnect device", action: forgetDevice)
                    }
                }
                
                Section(footer: Text("Automatically connect to saved device after reboot")) {
                    Toggle("Keep Connected", isOn: $saveUUID)
                        .onChange(of: saveUUID) { value in
                            UserDefaults.saveUUID = value
                            
                            if value {
                                guard let peripheral = gemocardKit.connectingPeripheral else {
                                    UserDefaults.savedGemocardUUID = nil
                                    return
                                }
                                UserDefaults.savedGemocardUUID = peripheral.identifier.uuidString
                            } else {
                                UserDefaults.savedGemocardUUID = nil
                            }
                        }
                }
                
                if UserDefaults.medsengerContractId != nil && UserDefaults.medsengerAgentToken != nil {
                    Section(footer: Text("Delete Medsenger authorization details, you will not be able to send data to the service until you authorize again")) {
                        Button("Reset Medsenger credentials", action: gemocardKit.resetMedsengerCredentials)
                    }
                }
                
                Section(header: Text("About"), footer: Text("(С) Medsenger Sync 2022")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion ?? LocalizedStringKey("Version not found").stringValue())
                    }
                }
            }
            .navigationBarTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Close", action: { isPresented.toggle() })
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func getDeviceOperatingMode() -> DeviceOperatingMode {
        return gemocardKit.getDeviceStatusData().deviceOperatingMode ?? .unknown
    }
    
    private func getDeviceStatus() -> DeviceStatus {
        return gemocardKit.getDeviceStatusData().deviceStatus ?? .unknown
    }
    
    private func forgetDevice() {
        UserDefaults.savedGemocardUUID = nil
        gemocardKit.disconnect()
        isPresented = false
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//    }
//}
