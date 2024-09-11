//
//  AbstractCardRecall.swift
//  re-collect
//
//  Created by Mansidak Singh on 6/13/24.
//

import Foundation
import SwiftUI
import AppKit
import Alamofire
class AbstractResponseViewModel: ObservableObject {
    @Published var responseText: String = ""
    @Published var documentLinks: [(title: String, link: String)] = []
    @Published var isLoading: Bool = true // Add loading state

    func appendResponse(with newText: String) {
        DispatchQueue.main.async {
            self.responseText += newText
            self.isLoading = false // Set loading to false when response is appended
        }
    }

    func setDocumentLinks(_ links: [(String, String)]) {
        DispatchQueue.main.async {
            self.documentLinks = links
        }
    }
}

struct AbstractCardView: View {
    @ObservedObject var viewModel: AbstractResponseViewModel
    let cardTitle: String
    func trimLeadingText(_ text: String) -> String {
        if let range = text.range(of: "Here's") {
            if let end = text[range.upperBound...].firstIndex(where: { $0 == ":" || $0 == "." }) {
                let trimmedStartIndex = text.index(after: end)
                let nextIndex = text.index(trimmedStartIndex, offsetBy: 1)
                
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    return String(text[nextIndex...].dropFirst())
                } else {
                    return String(text[trimmedStartIndex...])
                }
            }
        }
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(cardTitle)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sources:")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            
                            ForEach(viewModel.documentLinks, id: \.title) { title, link in
                                HStack {
                                    Button(action: { openURL(link) }) {
                                                    Text(title)
                                                        .font(.subheadline)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .frame(maxWidth: 200) // Adjust the width as needed
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .onHover { hovering in
                                                    if hovering {
                                                        NSCursor.pointingHand.push()
                                                    } else {
                                                        NSCursor.pop()
                                                    }
                                                }
                                    
                                    Divider()
                                        .frame(height: 20)
                                }
                            }
                        }
                    }
                }

                if viewModel.isLoading {
                    HStack{
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                        Spacer()
                    }
                } else {
                    ScrollView {
                        Divider()
                        Text(trimLeadingText(viewModel.responseText))
                    }
                   
                }
            }

            Spacer()
        }
        .frame(width: 370, height: 280)
        .padding()
        .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    func extractNoteId(from urlString: String) -> String? {
        guard urlString.starts(with: "https://app.re-collect.ai/apple-note/"),
              let noteIdRange = urlString.range(of: "apple-note/") else {
            return nil
        }
        return String(urlString[noteIdRange.upperBound...])
    }

    func openURL(_ urlString: String) {
        if urlString.starts(with: "https://app.re-collect.ai/apple-note/") {
            if let noteId = extractNoteId(from: urlString) {
                let formattedNoteId = "x-coredata://\(noteId)"
                let script = """
                tell application "Notes"
                    show note id "\(formattedNoteId)"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                    if let error = error {
                        print(error)
                    }
                }
            }
        } else if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
