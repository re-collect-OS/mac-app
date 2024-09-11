//
//  RootView.swift
//  Recollect macOS Dev
//
//  Created by Mansidak Singh on 3/1/24.
//

import Foundation
import SwiftUI
import Sparkle


struct RootView: View {
    @StateObject var authManager = AuthenticationManager()
    @EnvironmentObject var appStateManager: AppStateManager
    var updater: SPUUpdater
    
    var body: some View {
        Group{
            if authManager.isLoggedIn {
                HomeView(updater: updater) // Ensure HomeView receives the updater
                    .environmentObject(authManager)
                    .environmentObject(appStateManager)
            } else {
                ContentView().environmentObject(authManager)
            }
            
        }
        
    }
}


