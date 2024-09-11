//
//  SettingsView.swift
//  re-collect
//
//  Created by Mansidak Singh on 3/14/24.
//

import Foundation
import SwiftUI
import LaunchAtLogin
import Sentry


struct SettingsView: View {
    @State private var selection: String? = "Safari"
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @State private var connections: [Connection] = []
    
    
    private func iconForAppName(_ appName: String) -> String {
        switch appName {
        case "Notes":
            return "BIGNotes"
        case "Safari":
            return "safari"
        default:
            return "gear" // A default icon for other integrations
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                List(selection: $selection) {
                    Section(header: Text("System")) {
                        NavigationLink(value: "Notifications") {
                            Label("Notifications", systemImage: "bell")
                        }
                        NavigationLink(value: "Account") {
                            Label("Account", systemImage: "person.circle")
                        }
                    }
                    
                    Section(header: Text("Integrations")) {
                        ForEach(connections) { connection in
                            NavigationLink(value: connection.appName) {
                                HStack {
                                    Circle()
                                        .fill(colorForSyncState(connection.syncState))
                                        .frame(width: 10, height: 10)
                                    
                                    // Ensure you're using the correct image names as per the assets added to your project
                                    Image(connection.imageName) // Adjust this line if necessary
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 15, height: 15)
                                    
                                    Text(connection.appName)
                                }
                            }
                        }
                    }
                    
                }
                
                .onAppear {
                    loadConnections()
                }
                .accentColor(.gray)
                .navigationTitle("Settings")
                .toolbar {
                    
                    
                }
                
                Spacer()
                HStack{
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.body)
                        .foregroundStyle(.gray)
                        .onTapGesture {
                            loadConnections()
                        }
                        .padding(.vertical,20)
                        .padding(.horizontal,20)
                    
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appStateManager.activeView = .home
                        }
                    }
                }
                
            }
            .padding(.top, 20)
        } detail: {
            Group {
                switch selection {
                case "Notifications":
                    MyNotificationsView()
                case "Account":
                    MyAccountView()
                case "Safari":
                    SafariView()
                        .environmentObject(appStateManager)
                        .environmentObject(authenticationManager)
                case "Notes":
                    NotesView()
                        .environmentObject(appStateManager)
                        .environmentObject(authenticationManager)
                default:
                    detailViewForConnection()
                }
            }
        }
        .background(Color.black)
        .sheet(isPresented: $appStateManager.shouldPresentSheet) {
            NotesSyncView()
                .frame(minWidth: 600, maxWidth: 600, minHeight: 300, maxHeight: 300)
                .background(Color.black)
                .onDisappear {
                    // Refresh the states of the integrations when the sheet disappears
                    loadConnections()
                    
                }
        }
        
        .sheet(isPresented: $appStateManager.shouldPresentSafariSheet) {
            SafariHistorySyncView()
                .frame(minWidth: 600, maxWidth: 600, minHeight: 300, maxHeight: 300)
                .background(Color.black)
                .onDisappear {
                    loadConnections()
                    
                }
        }
        
        
        .frame(width: 845, height: 445) // Overall frame size for the NavigationSplitView
    }
    private func isServiceEnabled(_ serviceName: String) -> Bool {
        guard let connection = connections.first(where: { $0.appName == serviceName }) else { return false }
        switch connection.syncState {
        case .enabled:
            return true
        default:
            return false
        }
    }
    
    // Updated SwiftUI view builder function
    @ViewBuilder
    private func detailViewForConnection() -> some View {
        if let connection = connections.first(where: { $0.appName == selection }) {
            Text("Details for \(connection.appName)")
                .font(.title)
                .foregroundColor(.gray)
        } else {
            Text("Select an option")
                .font(.title)
                .foregroundColor(.gray)
        }
    }
    
    private func colorForSyncState(_ state: SyncState) -> Color {
        switch state {
        case .enabled:
            return Color.green
        case .disabled:
            return Color.gray // Use gray for the "exists but is paused" state.
        case .notEnabled:
            return Color.red
        }
    }
    
    private func loadConnections() {
        // Initial state for Safari - assume not enabled
        var safariState: SyncState = .notEnabled
        
        // Check if SafariHistory.json exists
        if doesSavedLinksExist() {
            safariState = .enabled // Change to enabled if file exists
        }
        
        // Set up connections with dynamic Safari state
        connections = [
            Connection(appName: "Safari", imageName: "safari", syncState: safariState, action: {}),
            Connection(appName: "Notes", imageName: "BIGNotes", syncState: .enabled, action: {}) // Assuming Notes is always enabled for demonstration
        ]
        // Additional logic as needed, e.g., for Notes
        refreshNotesSyncStatus()
    }
    
    private func doesSavedLinksExist() -> Bool {
        do {
            // Get the URL for the Application Support directory
            let applicationSupportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            
            // Append your specific file's name to the directory path
            let savedLinksUrl = applicationSupportURL.appendingPathComponent("SafariHistory.json")
            
            // Check if the file exists at the specified path
            return FileManager.default.fileExists(atPath: savedLinksUrl.path)
        } catch {
            print("Error accessing Application Support directory: \(error)")
            SentrySDK.capture(error: error)
            return false
        }
    }
    
    
    private func refreshNotesSyncStatus() {
        Task {
            if let isNotesIntegrationEnabled = await authenticationManager.fetchNotesIntegrationEnabledState() {
                // If integration exists but is disabled, it should be grey (disabled).
                let state: SyncState = isNotesIntegrationEnabled ? .enabled : .disabled
                updateNotesConnectionState(with: state)
            } else {
                // If you couldn't fetch the integration status at all, it's "not enabled" (red).
                updateNotesConnectionState(with: .notEnabled)
            }
        }
    }
    
    private func updateNotesConnectionState(with newState: SyncState) {
        if let index = connections.firstIndex(where: { $0.appName == "Notes" }) {
            connections[index].syncState = newState
        } else {
            let notesConnection = Connection(appName: "Notes", imageName: "BIGNotes", syncState: newState, action: {
                self.appStateManager.shouldPresentSheet = true
            }) // Specify the image name here
            connections.append(notesConnection)
        }
    }
    
    
    private func determineNotesSyncState(isEnabled: Bool) -> String {
        // Here, implement the logic to determine if Notes is syncing or paused.
        // This is a placeholder; you'll need to replace it with your actual logic.
        // For example:
        return isEnabled ? "Enabled; Syncing" : "Enabled; Paused"
    }
    
    
}

enum SyncState {
    case enabled
    case disabled
    case notEnabled // This can represent both "doesn't exist" and "exists but is paused", based on your context.
}

struct Connection: Identifiable {
    var id = UUID()
    let appName: String
    let imageName: String // Add this if you want a separate property for the image name
    var syncState: SyncState
    let action: () -> Void
}




struct MyAccountView: View {
    @EnvironmentObject var authenticationManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Account Settings")
                .font(.title)
                .padding(.bottom)

            List {
                Section(header: Text("General").font(.headline)) {
                    HStack {
                        Text("Launch at Login")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LaunchAtLogin.Toggle("Launch at login 🦄")
                            .labelsHidden()
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    HStack {
                        Text("Account")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Sign out") {
                            Task {
                                await authenticationManager.signOut()
                            }
                        }
                        .foregroundColor(.red)

                    }
                    
                    
                }

    
            }
        }
        .padding()
    }
}


import SwiftUI

struct MyNotificationsView: View {
    @AppStorage("showSafariNotifications") private var showSafariNotifications: Bool = true
    @AppStorage("enableNotesNotifications") private var enableNotesNotifications: Bool = true
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Notifications Settings")
                .font(.title)
            Text("Turn off reminders about setting up the integrations if you haven't already")
                .font(.subheadline)
                .padding(.bottom)
            
            
            List {
                Section(header: Text("Apps").font(.headline)) {
                    HStack {
                        Image(systemName: "safari.fill") // Safari icon
                            .foregroundColor(.blue)
                            .frame(width: 30, height: 30)
                        Text("Safari")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $showSafariNotifications)
                            .labelsHidden() // Hides the label for a cleaner look
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    
                    HStack {
                        Image(systemName: "note.text") // Notes app icon
                            .foregroundColor(.yellow)
                            .frame(width: 30, height: 30)
                        Text("Notes")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $enableNotesNotifications)
                            .labelsHidden() // Hides the label for a cleaner look
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
        }
        .padding()
    }
}

struct MyNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        MyNotificationsView()
    }
}



struct PrivacySettings: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Privacy Settings")
                .font(.largeTitle)
            // Your account details here
        }
        .padding()
    }
}
struct Preferences: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Preferences")
                .font(.largeTitle)
            // Your account details here
        }
        .padding()
    }
}




struct NotesView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var authenticationManager: AuthenticationManager
    
    // State properties for UI representation
    @State private var integrationStatus: String = "Checking..."
    
    var body: some View {
        VStack(alignment: .leading) {
            Image("BIGNotes")
                .resizable()
                .scaledToFit()
                .frame(width: 50)
            HStack {
                VStack(alignment: .leading) {
                    Text("Notes")
                        .font(.largeTitle)
                    Text(integrationStatus)
                        .foregroundColor(integrationStatus.contains("Enabled") ? .green : (integrationStatus.contains("Paused") ? .gray : .red))
                }
                Spacer()
                // Conditional button based on integration status
                if integrationStatus == "Not Integrated" {
                    Button("Integrate") {
                        // Trigger the integration process
                        appStateManager.shouldPresentSheet = true
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "4240B9"))
                    .padding(.top)
                    
                } else {
                    Button("Manage Integrations") {
                        // Direct to the management page
                        if let url = URL(string: "https://app.re-collect.ai/integrations") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "4240B9"))
                    .padding(.top)
                }
                
            }
            Spacer()
        }
        .padding(.horizontal, 30)
        .onAppear {
            fetchNotesIntegrationStatus()
        }
    }
    
    private func fetchNotesIntegrationStatus() {
        Task {
            guard let isEnabled = await authenticationManager.fetchNotesIntegrationEnabledState() else {
                integrationStatus = "Not Integrated"
                return
            }
            integrationStatus = isEnabled ? "Integrated; Enabled (Syncing)" : "Integrated; Paused"
        }
    }
}

struct SafariView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var authenticationManager: AuthenticationManager
    
    // Assume doesSavedLinksExist has been implemented here or somewhere accessible
    @State private var showingFullDiskAccessAlert = false // State to control alert visibility
    
    // State properties for UI representation
    @State private var integrationStatus: String = "Checking..."
    
    var body: some View {
        VStack(alignment: .leading) {
            Image("Onboarding_Safari")
                .resizable()
                .scaledToFit()
                .frame(width: 50)
            HStack {
                VStack(alignment: .leading) {
                    Text("Safari")
                        .font(.largeTitle)
                    Text(integrationStatus)
                        .foregroundColor(integrationStatus.contains("Enabled") ? .green : .red)
                }
                Spacer()
                if integrationStatus == "Not Integrated" {
                    Button("Integrate") {
                        checkFullDiskAccessAndIntegrate()
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "4240B9"))
                    .padding(.top)
                    .alert(isPresented: $showingFullDiskAccessAlert) {
                        Alert(
                            title: Text("Full Disk Access Required"),
                            message: Text("Please grant Full Disk Access to this app in System Preferences to continue."),
                            primaryButton: .default(Text("Open System Preferences")) {
                                openFullDiskAccessPreferences()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                } else {
                    Button("Manage Integrations") {
                        // Redirect to manage integrations
                        if let url = URL(string: "https://app.re-collect.ai/integrations") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "4240B9"))
                    .padding(.top)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 30)
        .onAppear {
            fetchSafariIntegrationStatus()
        }
    }
    
    private func fetchSafariIntegrationStatus() {
        integrationStatus = doesSavedLinksExist() ? "Integrated; Enabled (Syncing)" : "Not Integrated"
    }
    
    // Existing doesSavedLinksExist method...
    
    private func performDummyFullDiskAccessCheck() {
        let safariHistoryDBPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/History.db").path
        
        // Attempt to open the Safari history database file just to trigger the FDA prompt.
        // This doesn't need to succeed; it's just to ensure macOS recognizes the intent.
        let _ = FileManager.default.contents(atPath: safariHistoryDBPath)
        
        // Note: This action alone won't grant your app Full Disk Access or make the file readable.
        // It's intended to ensure your app is listed in the Full Disk Access panel in System Preferences.
    }
    
    private func checkFullDiskAccessAndIntegrate() {
        let testFilePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari/History.db").path
        performDummyFullDiskAccessCheck()
        if FileManager.default.isReadableFile(atPath: testFilePath) {
            // Proceed with integration
            appStateManager.shouldPresentSafariSheet = true
        } else {
            // Show alert indicating the need for Full Disk Access
            showingFullDiskAccessAlert = true
        }
    }
    
    private func openFullDiskAccessPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    
    private func doesSavedLinksExist() -> Bool {
        do {
            // Get the URL for the Application Support directory
            let applicationSupportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            
            // Append your specific file's name to the directory path
            let savedLinksUrl = applicationSupportURL.appendingPathComponent("SafariHistory.json")
            
            // Check if the file exists at the specified path
            return FileManager.default.fileExists(atPath: savedLinksUrl.path)
        } catch {
            print("Error accessing Application Support directory: \(error)")
            SentrySDK.capture(error: error)
            return false
        }
    }
    
}



extension NSTableView {
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        backgroundColor = NSColor.clear
        if let esv = enclosingScrollView {
            esv.drawsBackground = false
        }
    }
}
enum NotesIntegrationState {
    case integratedSyncing
    case integratedPaused
    case notIntegrated
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotesView()
            .environmentObject(AppStateManager())
            .environmentObject(AuthenticationManager())
    }
}

