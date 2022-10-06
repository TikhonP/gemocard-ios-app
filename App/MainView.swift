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
    
    var body: some View {
        VStack {
            if gemocardKit.isBluetoothOn && !gemocardKit.isConnected {
                Text("Searching...")
            }
            if gemocardKit.isConnected {
                Text("Connected")
            }
            
            List(gemocardKit.devices, id: \.self) { device in
                if ((device.name) != nil) {
                    HStack {
                        Text(device.name!)
                        if gemocardKit.connectingPeripheral == device {
                            Spacer()
                            if gemocardKit.isConnected {
                                Image(systemName: "checkmark.circle")
                            } else {
                                ProgressView()
                            }
                        }
                    }
                    .onTapGesture {
                        self.gemocardKit.connect(peripheral: device)
                    }
                }
            }
            Button(action: gemocardKit.action) {
                Text("lolkek")
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.gemocardKit.discover()
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
