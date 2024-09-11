
import Cocoa
import HotKey
import SwiftUI
import AmplitudeSwift
import UserNotifications
import Sentry

import Carbon
class PreferenceManager {
    static let shared = PreferenceManager()
    
    var useMenuBarForToggle: Bool = true {
        didSet {
            onPreferenceChange?()
        }
    }
    
    var onPreferenceChange: (() -> Void)?
    
    private init() {}
}



class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    var mouseEventMonitor: Any?
    var keyEventMonitor: Any?
    var hotKey1: HotKey?
    var hotKey2: HotKey?
    var statusItem: NSStatusItem!
    var appStateManager: AppStateManager?
    var notesAppTimer: Timer?
    //    var mediaKeyTap: MediaKeyTap?
    
    var hotKeyRef: EventHotKeyRef?
    @ObservedObject var noteManager = NoteManager.shared
    var lastSafariNotificationTime: Date?
    func setUserIdtoAmplitude() async {
        do {
            let email = try await WindowManager.shared.authManager?.fetchEmail()
            print("User email: \(email)")
            amplitude.setUserId(userId: email)
        } catch {
            print("Error fetching user email: \(error)")
            SentrySDK.capture(error: error)
            // Handle the error, e.g., show an error message
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        showMainWindow()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.appStateManager?.activeView = response.notification.request.content.userInfo["destinationView"] as? String == "Notes" ? .settings : .settings
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.mainWindow {
                window.makeKeyAndOrderFront(self)
            }
            if response.notification.request.content.userInfo["destinationView"] as? String == "Safari" {
                //                   self.appStateManager?.shouldPresentSafariSheet = true
            } else {
                self.appStateManager?.shouldPresentSheet = true
            }
        }
        completionHandler()
    }
    
    
    
    
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let targetName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        print(targetName)
        print("TargetName")
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 845, height: 446)) // Set the window size to 1000x800
            window.styleMask.remove(.resizable) // Make the window non-resizable
        }
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("Permissions granted: \(granted)")
        }
        setupMenuBarItem()
        setupGlobalEventListeners()
        startMonitoringActiveApplications()
        registerHotKey()
        UNUserNotificationCenter.current().delegate = self
        
        PreferenceManager.shared.onPreferenceChange = { [weak self] in
            DispatchQueue.main.async {
                self?.setupMenuBarItem()
            }
        }
        SentrySDK.start { options in
                options.dsn = "https://74e78535611fe3857d9f0f6ea480f03f@o1335587.ingest.us.sentry.io/4507527254114304"
//                options.debug = true // Enabling debug when first installing is always helpful

                // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
                // We recommend adjusting this value in production.
                options.tracesSampleRate = 1.0

                // Sample rate for profiling, applied on top of TracesSampleRate.
                // We recommend adjusting this value in production.
                options.profilesSampleRate = 1.0
            }

        Task {
            await setUserIdtoAmplitude()
        }
        if let mainWindow = NSApplication.shared.windows.first {
            mainWindow.delegate = self
        }
        
        
        
    }
    
    
    
    
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    func showMainWindow() {
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
        }
    }
    
    func setupMenuBarItem() {
//        if let button = self.statusItem.button {
//            if let image = NSImage(named: "recollectsearchdark") { // Replace "YourCustomImageName" with the actual name of your image asset
//                image.size = NSSize(width: image.size.width * (23 / image.size.height), height: 23) // Replace desiredHeight with your desired image height
//                button.image = image
//            }
//            button.action = #selector(toggleWindowVisibility(_:))
//            
//        }
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
    
    func startMonitoringActiveApplications() {
//        let observedApps = ["Notes", "Safari"]
//        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: OperationQueue.main) { [weak self] notification in
//            guard let self = self,
//                  let appInfo = notification.userInfo,
//                  let app = appInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
//                  let appName = app.localizedName,
//                  observedApps.contains(appName) else { return }
//            
//            if appName == "Safari" {
//                
//                if let authManager = WindowManager.shared.authManager {
//                    SafariHistoryManager.shared.configure(with: authManager)
//                    
//                    Task {
//                        SafariHistoryManager.shared.attemptSync()
//                    }
//                } else {
//                    print("AuthenticationManager is not available.")
//                }
//                
//                if !SyncStateManager.shared.isFetchingSafariHistory && !self.doesSavedLinksExist() {
//                    self.sendDetectionNotification(for: appName)
//                }
//            } else if appName == "Notes" {
//                if self.doesSavedNotesExist() {
//                    print("YES IT DOES")
//                    
//                    self.noteManager.loadNotes() // Call loadNotes if SavedNotes.json exists
//                } else {
//                    print("NO IT DOESNT")
//                    self.sendDetectionNotification(for: appName) // Show notification for Notes
//                }
//            }
//        }
    }
    
    
    func doesSavedLinksExist() -> Bool {
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
    
    
    
    
    
    func sendDetectionNotification(for appName: String) {
        let now = Date()
        
        // Handle Safari notifications preference
        if appName == "Safari" {
            let showSafariNotifications = UserDefaults.standard.bool(forKey: "showSafariNotifications")
            if !showSafariNotifications {
                return
            }
            
            if let lastNotificationTime = lastSafariNotificationTime,
               now.timeIntervalSince(lastNotificationTime) < 1800 {
                return
            }
            lastSafariNotificationTime = now
        }
        
        // Handle Notes notifications preference
        if appName == "Notes" {
            let enableNotesNotifications = UserDefaults.standard.bool(forKey: "enableNotesNotifications")
            if !enableNotesNotifications {
                return // Exit if the user has opted out of Notes notifications
            }
            
            // Optional: Implement timing logic similar to Safari if desired
        }
        
        let content = UNMutableNotificationContent()
        
        if appName == "Safari" && !doesSavedLinksExist() {
            content.title = "Sync your Safari history"
            content.body = "Tap to set it up."
            content.userInfo = ["destinationView": "Safari"]
        } else if appName == "Notes" && !doesSavedNotesExist() {
            content.title = "re:collect can recall from Notes"
            content.body = "Tap to set it up"
            content.userInfo = ["destinationView": "Notes"]
        } else {
            return
        }
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    
    
    
    
    
    func registerHotKey() {
        var hotKeyID = EventHotKeyID(signature: FourCharCode(bitPattern: Int32("swft".fourCharCodeValue)), id: 1)
        let hotKeyModifiers = UInt32(cmdKey) // Adjust modifiers as needed
        let hotKeyCode = UInt32(kVK_F4) // F4 key code
        
        let status = RegisterEventHotKey(hotKeyCode, hotKeyModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hot key: \(status)")
            return
        }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            var eventID = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &eventID)
            
            // Perform your action here
            print("Hotkey ⌘ + F4 pressed!")
            
            return noErr
        }, 1, &eventType, nil, nil)
    }
    
    
    @objc func toggleWindowVisibility(_ sender: AnyObject?) {
        if WindowManager.shared.recallWindowPanel.isVisible {
            WindowManager.shared.recallWindowPanel.orderOut(nil)
            disableEscapeHotKey() // Disable escape hotkey when window is hidden
            amplitude.track(eventType: "Recall: disappeared")
        } else {
            WindowManager.shared.recallWindowPanel.makeKeyAndOrderFront(nil)
            enableEscapeHotKey() // Enable escape hotkey when window is shown
            amplitude.track(eventType: "Recall: appeared")
            
            // Simulate tab keypress
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x30, keyDown: true)
            event?.post(tap: .cghidEventTap)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            }
            
        }
    }
    
    
    func enableEscapeHotKey() {
        hotKey2 = HotKey(key: .escape, modifiers: [])
        hotKey2?.keyDownHandler = { [weak self] in
            if !SharedStateManager.shared.isPinned && WindowManager.shared.recallWindowPanel.isVisible {
                WindowManager.shared.recallWindowPanel.orderOut(nil)
                self?.disableEscapeHotKey() // Optional: Disable escape hotkey if you want
            }
            self?.disableEscapeHotKey()
        }
    }
    
    
    
    
    func disableEscapeHotKey() {
        hotKey2 = nil
    }
    
    
    
    func setupGlobalEventListeners() {
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissPopupIfNeeded()
        }
        keyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.dismissPopupIfNeeded()
        }
    }
    
    func dismissPopupIfNeeded() {
        if !SharedStateManager.shared.isPinned && WindowManager.shared.recallWindowPanel.isVisible {
            WindowManager.shared.recallWindowPanel.orderOut(nil)
        }
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: String.Encoding.macOSRoman) {
            for i in 0..<min(data.count, 4) {
                result |= FourCharCode(data[i]) << (8 * (3 - i))
            }
        }
        return result
    }
}
