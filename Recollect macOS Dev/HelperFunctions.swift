//
//  FocusedTextField.swift
//  Recollect macOS Dev
//
//  Created by Mansidak Singh on 2/10/24.
//

import Foundation
import SwiftUI
import AppKit


struct SearchField : NSViewRepresentable {
    @Binding var searchString: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: searchString)
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = searchString
    }
    
    func makeCoordinator() -> SearchField.Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchField
        
        init(_ parent: SearchField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                self.parent.searchString = textField.stringValue
            }
        }
    }
}

extension View {
    func focusableTextField() -> some View {
        return self.onReceive(NotificationCenter.default.publisher(for: Notification.Name("FocusSearchField"))) { _ in
            DispatchQueue.main.async {
                NSApp.keyWindow?.firstResponder?.resignFirstResponder()
                NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.contentView?.subviews[0])
            }
        }
    }
}
