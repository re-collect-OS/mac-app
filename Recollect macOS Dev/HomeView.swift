import SwiftUI
import HotKey
import SQLite
import Foundation
import AVFoundation
import AVKit
import Sparkle
import Sentry

struct URLVisit {
    let timestamp: String
    let url: String
    let title: String
    let transitionType: String
}
struct AVPlayerControllerRepresented: NSViewRepresentable {
    var player: AVPlayer
    var loopVideo: Bool

    func makeNSView(context: Context) -> NSView {
        let view = AVPlayerViewAVF(player: player)
        player.isMuted = true
        player.play()

        if loopVideo {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero) // Rewind to the start
                player?.play() // Play again
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Handle updates to the NSView if needed
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        // Remove the observer if the view is being dismantled
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: (nsView as? AVPlayerViewAVF)?.playerLayer.player?.currentItem)
    }
}

class AVPlayerViewAVF: NSView {
    var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }

    override var acceptsFirstResponder: Bool {
        return false
    }
   
    init(player:AVPlayer){
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer = AVPlayerLayer(player: player)
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
enum ActiveView {
    case home
    case settings
}



struct NotificationPopoverView: SwiftUI.View {
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add your integrations here")
                .font(.title3)
//            Text("Some integrations require your attention. Please check your settings.")
//                .font(.body)
        }
        .padding()
        .frame(width: 250)
        .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
        .cornerRadius(16)
        .shadow(radius: 5)
    }
}



struct HomeView: SwiftUI.View {
    @Environment(\.colorScheme) var colorScheme
    private var hotKey: HotKey?
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isParsingHistory = false
    @State private var urlVisitParseCompleted = false
    @State private var urlVisits: [URLVisit] = []
    @State private var parsingErrorMessage: String?
    @State private var useMenuBarForToggle = PreferenceManager.shared.useMenuBarForToggle
    @EnvironmentObject var appStateManager: AppStateManager
    @State private var notes: [Note] = []
    @State private var showingSettingsWindow = false
    let player = AVPlayer(url: URL(fileURLWithPath: Bundle.main.path(forResource: "Area", ofType: "mp4")!))
    @State private var activeView: ActiveView = .home
    let updater: SPUUpdater
    @State private var showNotificationPopover = false
    @State private var enableAutomaticChecks: Bool = false

    // Assuming CheckForUpdatesViewModel needs to be initialized with the updater
    @ObservedObject var checkForUpdatesViewModel: CheckForUpdatesViewModel
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
        self._enableAutomaticChecks = State(initialValue: updater.automaticallyChecksForUpdates)
    }
    
    func doesSavedNotesExist() -> Bool {
        do {
            let applicationSupportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let savedNotesUrl = applicationSupportURL.appendingPathComponent("SavedNotes_1.json")
            return FileManager.default.fileExists(atPath: savedNotesUrl.path)
        } catch {
            print("Error accessing Application Support directory: \(error)")
            SentrySDK.capture(error: error)
            return false
        }
    }
    
    func doesSavedLinksExist() -> Bool {
       do {
           let applicationSupportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
           
           let savedLinksUrl = applicationSupportURL.appendingPathComponent("SafariHistory.json")
           
           return FileManager.default.fileExists(atPath: savedLinksUrl.path)
       } catch {
           print("Error accessing Application Support directory: \(error)")
           SentrySDK.capture(error: error)
           return false
       }
   }
    
    func checkAndShowPopoverIfNeeded() {
           let enableNotesNotifications = UserDefaults.standard.bool(forKey: "enableNotesNotifications")
           let showSafariNotifications = UserDefaults.standard.bool(forKey: "showSafariNotifications")
           let safariLinksExist = doesSavedLinksExist()
           let notesLinksExist = doesSavedNotesExist()

           if !safariLinksExist && !notesLinksExist {
               showNotificationPopover = true
           } else {
               showNotificationPopover = false
           }
       }
    
    var body: some SwiftUI.View {
        Group {
            switch appStateManager.activeView {
            case .home:
                homeViewContent
                    .transition(.opacity) // Apply the transition here
            case .settings:
                SettingsView()
                    .environmentObject(appStateManager)
                    .transition(.slide) // Apply a different transition here, if desired
                    .environmentObject(appStateManager)
                

            }
            
            
        }
        .onAppear {
            updater.automaticallyChecksForUpdates = true
        }

    }
    
    
    
    var homeViewContent: some SwiftUI.View {
        VStack {
            HStack {
                Image(colorScheme == .dark ? "onboardingicondark" : "onboardingiconlight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 90) // Smaller logo
                    .padding(.top, 10) // Add padding to ensure it's at the top
                    .padding(.leading, 10) // Align to the left
                
                Spacer()
            }        .padding(.leading,25)
            
            
            Spacer()
            HStack{
                VStack(alignment: .leading, spacing: 20) {
                    
                    
//                    Text("Dev")
//                        .font(.system(size: 12))
//                        .padding(.vertical, 5)
//                        .padding(.horizontal, 10)
//                        .background(Color.red)
//                        .foregroundColor(.white)
//                        .clipShape(Capsule())
                    
                    Text("re:collect has shutdown")
                        .font(.largeTitle) // Make this text larger
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    
                  
                    Spacer()
//                    HStack {
//                        if #available(macOS 13, *) {
//                            Button("Dismiss") {
//                                NSApplication.shared.keyWindow?.close()
//                            }
//                            .controlSize(.large)
//                            .buttonStyle(.borderedProminent)
//                            .tint(Color(hex: "4240B9"))
//                            
//                        }
//                        
//                        
//                        Spacer().frame(width: 42)
//                        
//                        
//                        CustomNSButtonWithImage(icon: "books.vertical", text: "Library") {
//                            withAnimation(.easeInOut(duration: 0.5)) {
//                                if let url = URL(string: "https://app.re-collect.ai/library"){
//                                    NSWorkspace.shared.open(url)
//                                }
//                            }
//                        }
//                        
//                        
//                        
//                        Spacer().frame(width: 50)
//                        
//                        if authManager.isSigningOut {
//                            ProgressView()
//                        } else {
//                            
//                            CustomNSButtonWithImage(icon: "gear", text: "Settings") {
//                                           withAnimation(.easeInOut(duration: 0.5)) {
//                                               self.appStateManager.activeView = .settings
//                                           }
//                                           self.checkAndShowPopoverIfNeeded()
//                                       }
//                                       .popover(isPresented: $showNotificationPopover) {
//                                           NotificationPopoverView()
//                                       }
//                            
//                            
//                        }
//                    }
                    
                    let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

//                    VStack(alignment: .leading) {
//                        HStack {
//                            Text("Updates:")
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundStyle(.gray)
//                                .onTapGesture {
//                                    updater.checkForUpdates()
//                                }
//                            Text("Check Now")
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundStyle(Color(hex: "807ef7"))
//                                .onTapGesture {
//                                    updater.checkForUpdates()
//                                }
//                                .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
//                            
//                            
//                            
//                            Spacer()
//                        }
//                        Text("Current Version: \(appVersion)") // appVersion is now guaranteed not to be optional
//                            .font(.footnote)
//                            .foregroundStyle(.gray)
//                            .onTapGesture {
//                                updater.checkForUpdates()
//                            }
//                    
//                    }
                    Spacer()
                    
                    
                }
                .padding(.leading,25)
                
                .padding()
                Spacer()
//                VStack{
//                    AVPlayerControllerRepresented(player: player, loopVideo: true)
//                        .frame(width: 500, height: 400)
//                        .padding(.top,-100)
//                    Spacer()
//                }
            }
            .onAppear {
                        self.checkAndShowPopoverIfNeeded()
                    }
            
        }
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading,30)
        .background(backgroundColor)

        .sheet(isPresented: $appStateManager.shouldPresentSheet) {
            NotesSyncView()
                .frame(minWidth: 600, maxWidth: 600, minHeight: 300, maxHeight: 300)
                .background(Color.black)
        }
        
        .sheet(isPresented: $appStateManager.shouldPresentSafariSheet) {
            SafariHistorySyncView()
                .frame(minWidth: 600, maxWidth: 600, minHeight: 300, maxHeight: 300)
                .background(Color.black)
        }
        
        
        
      

        
        
    }
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color(hex: "F0F0F0")
    }
    

    
    func openSecurityPreferences() { /* Your function to open preferences */ }
}
