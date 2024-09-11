
import SwiftUI
import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import HotKey
import Combine
import AppKit
import Sparkle
import Sentry

@main
struct Recollect_macOS_DevApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let authManager = AuthenticationManager()
    @Environment(\.colorScheme) var colorScheme
    let appStateManager = AppStateManager() // Add this line
    @State private var showNewWindow = false
    private let updaterController: SPUStandardUpdaterController
    public init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        Amplify.Logging.logLevel = .verbose
        configureAmplify()
        WindowManager.shared.setup(authManager: authManager)
        appDelegate.appStateManager = appStateManager
    }
    

    func configureAmplify() {
        Amplify.Logging.logLevel = .verbose // Set Amplify log level to verbose
        
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin()) // Ensure API plugin is added
            try Amplify.configure()
            print("Amplify configured with auth and API plugins")
        } catch {
            print("Failed to initialize Amplify: \(error)")
            SentrySDK.capture(error: error)
        }
    }
    
    
    var body: some Scene {
        WindowGroup {
            RootView(updater: updaterController.updater)
            
                .environmentObject(authManager)
                .environmentObject(appStateManager) // Add this line
                .frame(width:845, height:445)
                .background(backgroundColor)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                                   print("Opened URL: \(url)")
                               }
            
            
            
            
        } 
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
       

        
        .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    }
    
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "060606") : Color(hex: "F0F0F0")
    }
}

