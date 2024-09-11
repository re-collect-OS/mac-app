//
//  Sparkle.swift
//  re-collect
//
//  Created by Mansidak Singh on 3/15/24.
//

import Foundation
import SwiftUI
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}



struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    @State private var enableAutomaticChecks: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
        // Initialize the enableAutomaticChecks state with Sparkle's current setting
        self._enableAutomaticChecks = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    var body: some View {
        VStack {
            Button("Check for Updates…", action: updater.checkForUpdates)
                .disabled(!checkForUpdatesViewModel.canCheckForUpdates)

            // Checkbox to toggle automatic update checks
            Toggle(isOn: $enableAutomaticChecks) {
                Text("Automatically Check for Updates")
            }
            .onChange(of: enableAutomaticChecks) { newValue in
                updater.automaticallyChecksForUpdates = newValue
            }
        }
        .padding()
    }
}
