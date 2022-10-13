//
//  ConnectView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 11.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI

struct ConnectView: View {
    
    @EnvironmentObject private var gemocardKit: GemocardKit
    
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            HStack {
                Button("Close", action: { isPresented.toggle() })
                    .padding()
                Spacer()
            }
            HStack {
                if gemocardKit.connectingPeripheral == nil {
                    ProgressView()
                        .padding(.trailing, 1)
                    Text("Device search...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.trailing)
                } else {
                    Text("Connecting...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.trailing)
                }
            }
            .padding(.bottom, 5)
            Text("Select your Acsma Gemocard from the list below, the saved devices will be connected automatically.")
                .font(.body)
                .foregroundColor(Color.gray)
                .multilineTextAlignment(.center)
                .padding(.leading, 40)
                .padding(.trailing, 40)
            List{
                ForEach(self.gemocardKit.devices, id: \.self) { device in
                    if ((device.name) != nil) {
                        HStack {
                            Text(device.name!)
                            if gemocardKit.connectingPeripheral == device {
                                Spacer()
                                ProgressView()
                            }
                        }
                        .onTapGesture {
                            HapticFeedbackController.shared.play(.rigid)
                            self.gemocardKit.connect(peripheral: device)
                        }
                    }
                }
            }
        }
    }
}

//struct ConnectView_Previews: PreviewProvider {
//    static var previews: some View {
//        ConnectView()
//    }
//}
