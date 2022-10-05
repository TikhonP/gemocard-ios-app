//
//  RootView.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 04.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI

struct RootView: View {
    @StateObject var gemocardKit = GemocardKit()
    
    var body: some View {
        MainView()
            .onAppear(perform: { gemocardKit.initilizeGemocard() })
            .environmentObject(gemocardKit)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
