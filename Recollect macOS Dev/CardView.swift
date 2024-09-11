
import Foundation
import SwiftUI
import AmplitudeSwift
import AppKit
import CoreServices
import Sentry



struct CardView: View {
    @ObservedObject var authManager: AuthenticationManager
    var cardTitle: String
    var cardContent: String
    var cardURL: String?
    var docId: String
    @Environment(\.colorScheme) var colorScheme
    @State private var appleScriptResult: NSAppleEventDescriptor? = nil
    var isScreenshot: Bool
    var thumbnailS3Path: String?
    @State private var isImageLoaded: Bool = false
    @State private var thumbnailImage: NSImage?
    @State private var thumbnailImageForView: Image?
    @State private var isDragging = false
    @State private var dragAmount = CGSize.zero
    @State private var isSelected = false
    @State private var isLongPress = false
    @State private var isHovered = false
    @State private var showTooltip = true
    var onPeel: (String, String, String?, String, Bool, String?, CGPoint) -> Void
    var onRemove: (String) -> Void

    private func loadThumbnail() {
        guard let path = thumbnailS3Path else { return }
        authManager.fetchThumbnail(for: path) { result in
            switch result {
            case .success(let imageData):
                if let uiImage = NSImage(data: imageData) {
                    DispatchQueue.main.async {
                        self.thumbnailImage = uiImage
                        self.thumbnailImageForView = Image(nsImage: uiImage)
                        print("Image loaded successfully")
                    }
                }
            case .failure(let error):
                print("Failed to load thumbnail: \(error)")
            }
        }
    }

    func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let hostName = url.host else { return urlString }
        return hostName
    }

    func imageNameForURL(_ urlString: String?, defaultBrowser: String, isDarkMode: Bool) -> String {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return checkDefaultBrowser()
        }

        let domain = extractDomain(from: urlString)
        if url.pathExtension == "pdf" {
            return isDarkMode ? "pdfwhite" : "pdf"
        } else if domain == "youtube.com" {
            return "youtube"
        } else if domain == "twitter.com" {
            return "twitter"
        } else if urlString.starts(with: "https://app.re-collect.ai/apple-note/") {
            return "applenote"
        } else if urlString.starts(with: "https://app.re-collect.ai/") {
            return isDarkMode ? "dailynotewhite" : "dailynote"
        } else {
            return checkDefaultBrowser()
        }
    }

    func checkDefaultBrowser() -> String {
        let testURL = URL(string: "http://www.example.com")!
        guard let browserAppURL = NSWorkspace.shared.urlForApplication(toOpen: testURL) else {
            return "link.circle"
        }

        let browserAppName = browserAppURL.lastPathComponent.lowercased()
        if browserAppName.contains("chrome") {
            return "chrome"
        } else if browserAppName.contains("safari") {
            return "safari2"
        } else if browserAppName.contains("firefox") {
            return "firefox"
        } else {
            return "link.circle"
        }
    }

    func extractNoteId(from urlString: String) -> String? {
        guard urlString.starts(with: "https://app.re-collect.ai/apple-note/"),
              let noteIdRange = urlString.range(of: "apple-note/") else {
            return nil
        }
        return String(urlString[noteIdRange.upperBound...])
    }

    private func openImageInPreview(nsImage: NSImage) {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".png"
        let fileURL = temporaryDirectoryURL.appendingPathComponent(fileName)

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("Error converting image")
            return
        }

        do {
            try pngData.write(to: fileURL, options: [.atomic])
            NSWorkspace.shared.openFile(fileURL.path, withApplication: "Preview")
        } catch {
            print("Error writing or opening image file: \(error)")
            SentrySDK.capture(error: error)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(cardTitle)
                        .font(.title2)
                        .fontWeight(.medium)
                }
                .padding(.top, 20)

                if let urlString = cardURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack {
                            Image(imageNameForURL(urlString, defaultBrowser: "default-browser", isDarkMode: colorScheme == .dark))
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)

                            Text(urlString.starts(with: "https://app.re-collect.ai/apple-note/") ? "Apple Note" : extractDomain(from: urlString))
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .onTapGesture {
                            if urlString.starts(with: "https://app.re-collect.ai/apple-note/"), let noteId = extractNoteId(from: urlString) {
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
                            } else if let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Divider()

                if isScreenshot, let image = thumbnailImageForView {
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(.bottom, 5)
                } else if isScreenshot {
                    Text("Loading image...")
                        .onAppear { loadThumbnail() }
                } else {
                    Text(cardContent)
                        .lineSpacing(2)
                        .padding(.bottom, 0)
                    Spacer()
                }
            }
            .padding(.horizontal, 13)
            .onAppear {
                if isScreenshot && thumbnailImage == nil {
                    loadThumbnail()
                }
            }
            Spacer()
        }
        .frame(minHeight: isScreenshot && isImageLoaded ? 600 : 100, maxHeight: isScreenshot ? 600 : 175)
        .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .opacity(isDragging ? 0.5 : (isHovered ? 0.7 : 1))
        .offset(dragAmount)
        .animation(.easeInOut, value: isDragging)
        .help(Text("Double click and drag to pop out"))

        .gesture(
            DragGesture()
                .onChanged { gesture in
                    self.isLongPress = true
                    self.isDragging = true
                    self.dragAmount = gesture.translation
                }
                .onEnded { gesture in
                    self.isDragging = false
                    self.dragAmount = .zero

                    if self.isScreenshot, let nsImage = self.thumbnailImage {
                        if self.isLongPress {
                            self.openImageInPreview(nsImage: nsImage)
                        }
                    } else {
                        if isLongPress {
                            self.onPeel(cardTitle, cardContent, cardURL, docId, isScreenshot, thumbnailS3Path, NSEvent.mouseLocation)
                            self.onRemove(docId)
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isLongPress = false
                    }
                }
        )
        .animation(.easeInOut, value: isDragging)
    }
}

struct DraggableCardView: View {
    @ObservedObject var authManager: AuthenticationManager
    var cardTitle: String
    var cardContent: String
    var cardURL: String?
    var docId: String
    var isScreenshot: Bool
    var thumbnailPath: String?
    @State private var dragOffset = CGSize.zero
    var onPeel: (String, String, String?, String, Bool, String?, CGPoint) -> Void
    var onRemove: (String) -> Void

    var body: some View {
        CardView(
            authManager: authManager,
            cardTitle: cardTitle,
            cardContent: cardContent,
            cardURL: cardURL,
            docId: docId,
            isScreenshot: isScreenshot,
            thumbnailS3Path: thumbnailPath,
            onPeel: onPeel,
            onRemove: onRemove
        )
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    self.dragOffset = gesture.translation
                }
                .onEnded { _ in
                    self.dragOffset = .zero
                }
        )
    }
}
