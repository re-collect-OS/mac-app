//
//  CustomStyles.swift
//  re-collect
//
//  Created by Mansidak Singh on 3/15/24.
//

import Foundation

import SwiftUI
import AppKit

struct CustomButton: NSViewRepresentable {
    var title: String
    var action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.title = title
        button.setButtonType(.momentaryPushIn)
        button.isBordered = true // Required to show the border
        button.showsBorderOnlyWhileMouseInside = true
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = title
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}



struct CustomNSButtonWithImage: NSViewRepresentable {
    var icon: String
    var text: String
    var action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.setButtonType(.momentaryPushIn)
        button.isBordered = true
        button.showsBorderOnlyWhileMouseInside = true
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        button.title = text
        button.imagePosition = .imageLeading
        button.contentTintColor = .labelColor
        button.frame = CGRect(x: 0, y: 0, width: button.frame.size.width, height: 80)
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}
