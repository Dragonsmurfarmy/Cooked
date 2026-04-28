//
//  CookedApp.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI

@main
struct CookedApp: App {
    @State private var timerViewModel = TimerViewModel()

    var body: some Scene {
        WindowGroup {
            MainPageView()
                .environment(timerViewModel)
        }
    }
    
   
}
