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
                    
                    if UserDefaults.saveUUID {
                        Button("Forget device", action: forgetDevice)
                    } else {
                        Button("Disconnect device", action: forgetDevice)
                    }
                }
                
                Section(footer: Text("Automatically connect to saved device after reboot")) {
                    Toggle("Save connection", isOn: $saveUUID)
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
    
    func forgetDevice() {
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
