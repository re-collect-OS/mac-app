
//
//  WindowManager.swift
//  Recollect macOS Dev
//
//  Created by Mansidak Singh on 2/22/24.
//

import Foundation
import SwiftUI

class AppStateManager: ObservableObject {
    @Published var showingSettingsWindow: Bool = false
    @Published var shouldPresentSheet: Bool = false
    @Published var shouldPresentSafariSheet: Bool = false
    @Published var activeView: ActiveView = .home
}

class SharedStateManager: ObservableObject {
    static let shared = SharedStateManager()
    @Published var isPinned: Bool = false
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    @Published var authManager: AuthenticationManager?
    private var hideOverlayTimer: Timer?
    
    func showCustomViewWindow() {
        let customView = SettingsView()
        let hostingController = NSHostingController(rootView: customView)
        let window = NSPanel(contentViewController: hostingController)
        window.makeKeyAndOrderFront(nil)
        window.center()
    }
    
    
    func dismissPopupIfNeeded() {
        if recallWindowPanel.isVisible {
            recallWindowPanel.orderOut(nil) // Hide the window if it's visible
        } else {
            // If the window is not visible, do nothing.
            // This allows the escape key to act normally in other applications.
        }
    }
    
    
    func setup(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    
    func showMainWindow() {
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    lazy var recallWindowPanel: DraggablePanel = {
        // Calculate center position
        let screenRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 0, height: 0)
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 700
        let windowX = (screenRect.width - windowWidth) / 2
        let windowY = (screenRect.height - windowHeight) / 2
        
        return DraggablePanel(CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), showCloseButton: false, onClose: {}) {
            VStack {
                HStack{
                    EmptyView()
                        .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
                }
                
                SearchView()
                    .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
            }
            .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
            .cornerRadius(15)
        }
    }()
    
}


class DraggablePanel: NSPanel {
    init<Content: View>(_ contentRect: NSRect, showCloseButton: Bool, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        super.init(contentRect: contentRect, styleMask: [  .borderless,
                                                           .fullSizeContentView,
                                                           .nonactivatingPanel,], backing: .buffered, defer: false)
        
        // Configure panel properties
        self.onClose = onClose
        
        self.isFloatingPanel = true
        self.level = .statusBar
        self.backgroundColor = .clear
        
        self.collectionBehavior = [ .fullScreenAuxiliary]
        
        // Configure the close button
        if !showCloseButton {
            self.styleMask.remove(.closable)
        }
        
        // Set the content view
        self.contentView = NSHostingView(
            rootView: AnyView(
                ZStack(alignment: .topTrailing) {
                    content()
                    if showCloseButton {
                        Button(action: {
                            self.close() // Close the window here
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.gray)
                                .padding(10)
                        }
                        .buttonStyle(BorderlessButtonStyle())                         }
                }
            ).ignoresSafeArea()
        )
        
        
    }
    
    var onClose: () -> Void = {}
    
    override func close() {
        onClose()
        super.close()
    }
    
    // Ensure it can become key to interact with subviews
    override var canBecomeKey: Bool {
        return true
    }
    
    // Implement dragging
    override func mouseDown(with event: NSEvent) {
        self.performDrag(with: event)
    }
}

class FlatWindow: NSPanel {
    var onClose: (() -> Void)?
    
    // Using 'windowID' instead of 'identifier' to avoid conflicts
    let windowID: UUID
    
    init(
        windowID: UUID,
        _ contentRect: NSRect,
        showCloseButton: Bool = true,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.windowID = windowID
        self.onClose = onClose
        super.init(contentRect: contentRect, styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        commonInit(showCloseButton: showCloseButton, content: content)
    }
    
    private func commonInit(showCloseButton: Bool, content: @escaping () -> some View) {
        self.level = .mainMenu + 1
        self.collectionBehavior.insert(.fullScreenAuxiliary)
        self.isMovable = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.hasShadow = true
        self.backgroundColor = .clear
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.minSize = CGSize(width: 300, height: 150)
        
        self.contentView = NSHostingView(
            rootView: AnyView(
                ZStack(alignment: .topTrailing) {
                    content()
                        .cornerRadius(15)
                    
                    if showCloseButton {
                        Button(action: {
                            self.close()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.gray)
                                .padding(10)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            ).ignoresSafeArea()
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeKey: Bool { true }
    override func mouseDown(with event: NSEvent) {
        self.performDrag(with: event)
    }
    
    override func close() {
        onClose?()
        super.close()
    }
}
