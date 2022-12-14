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
            .alert(item: $gemocardKit.error, content: { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.description),
                    dismissButton: .default(Text("Close"))
                )
            })
            .onAppear(perform: { gemocardKit.initilizeGemocard() })
            .environmentObject(gemocardKit)
            .onOpenURL { url in
                gemocardKit.updatePropertiesFromDeeplink(url: url)
            }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
