
import Foundation
import SwiftUI
import Sentry


struct PeeledRecallCardView: View {
    @ObservedObject var authManager: AuthenticationManager
    let cardTitle: String
    let cardContent: String
    let cardURL: String?
    let docId: String
    var isScreenshot: Bool
    var thumbnailS3Path: String?
    @State private var nsImage: NSImage?
    @State private var thumbnailImage: Image?
    @State private var updatedContent: String
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme

    init(authManager: AuthenticationManager, cardTitle: String, cardContent: String, cardURL: String?, docId: String, isScreenshot: Bool, thumbnailS3Path: String?) {
        self.authManager = authManager
        self.cardTitle = cardTitle
        self.cardContent = cardContent
        self.cardURL = cardURL
        self.docId = docId
        self.isScreenshot = isScreenshot
        self.thumbnailS3Path = thumbnailS3Path
        _updatedContent = State(initialValue: cardContent)
    }

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading) {
                Text(cardTitle)
                    .font(.title2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 17)

                if let urlString = cardURL, let url = URL(string: urlString) {
                    Button(action: { openURL(urlString) }) {
                        HStack {
                            Text(urlString.starts(with: "https://app.re-collect.ai/apple-note/") ? "Apple Note" : extractDomain(from: urlString))
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading)
                    .padding(.top, -8)
                }

                Divider()

                ScrollView {
                    if isScreenshot {
                        if let image = thumbnailImage {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 600)
                                .onTapGesture(count: 2) {
                                    if let nsImage = self.nsImage {
                                        saveAndOpenImage(nsImage: nsImage)
                                    }
                                }
                        } else {
                            ProgressView("Loading image...")
                                .onAppear { loadThumbnail() }
                        }
                    } else {
                        Text(isExpanded ? updatedContent : cardContent)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: 600, alignment: .leading)
                            .lineLimit(isExpanded ? nil : 10)
                            .truncationMode(.tail)
                    }
                }

                HStack {
                    StyledButton(label: isExpanded ? "" : "", systemIcon: isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                        if isExpanded {
                            Task { await updateContent(expand: false) }
                        } else {
                            Task { await updateContent(expand: true) }
                        }
                        isExpanded.toggle()
                    }
                    .padding(.leading, 15)

                    Spacer()
                    Image(colorScheme == .light ? "recollectsearch" : "recollectsearchdark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(.leading, 17)
                }
                .padding(.bottom, -20)
                .padding(.top, -2)
            }
            .frame(maxWidth: 800)
            .padding()
            .padding(.leading, -8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectViewBackground().ignoresSafeArea())
    }

    func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let hostName = url.host else { return urlString }
        return hostName
    }

    func loadThumbnail() {
        guard let path = thumbnailS3Path else { return }
        authManager.fetchThumbnail(for: path) { result in
            switch result {
            case .success(let imageData):
                if let nsImage = NSImage(data: imageData) {
                    DispatchQueue.main.async {
                        self.nsImage = nsImage
                        self.thumbnailImage = Image(nsImage: nsImage)
                    }
                }
            case .failure(let error):
                print("Failed to load thumbnail: \(error)")
            }
        }
    }

    func saveAndOpenImage(nsImage: NSImage) {
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
            NSWorkspace.shared.open(fileURL)
        } catch {
            print("Error writing or opening image file: \(error)")
            SentrySDK.capture(error: error)
        }
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

    func updateContent(expand: Bool) async {
        guard expand else { return }
        await authManager.getUserData(docId: docId) { jsonResponse in
            guard let data = jsonResponse.data(using: .utf8) else { return }
            let decoder = JSONDecoder()

            if let document = try? decoder.decode(Document.self, from: data) {
                let paragraphText: String
                if document.doc_type == "twitter", let tweets = document.tweets, !tweets.isEmpty {
                    let firstTweet = tweets.first!
                    let paragraphs = Dictionary(grouping: firstTweet.sentences, by: { $0.paragraph_number })
                        .sorted(by: { $0.key < $1.key })
                        .map { _, value in value.map { $0.text }.joined(separator: " ") }
                    paragraphText = paragraphs.joined(separator: "\n\n")
                } else {
                    let paragraphs = Dictionary(grouping: document.sentences!, by: { $0.paragraph_number })
                        .sorted(by: { $0.key < $1.key })
                        .map { _, value in value.map { $0.text }.joined(separator: " ") }
                    paragraphText = paragraphs.joined(separator: "\n\n")
                }
                DispatchQueue.main.async {
                    self.updatedContent = paragraphText
                }
            }
        }
    }
}

struct StyledButton: View {
    var label: String
    var systemIcon: String
    let action: () -> Void
    @State private var isHovered = false

    // Define a fixed size for the square button
    private let buttonSize: CGFloat = 10

    var body: some View {
        Button(action: action) {
            if label != "" {
                HStack {
                    Text(label)
                    Image(systemName: systemIcon)
                }
                .frame(width: buttonSize, height: buttonSize)  // Set the frame to be square
                .font(.title3)
                .padding(8)
                .foregroundColor(isHovered ? .primary : .primary)
                .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(7)
            } else {
                HStack {
                    Image(systemName: systemIcon)
                }
                .frame(width: buttonSize, height: buttonSize)  // Set the frame to be square
                .font(.title3)
                .padding(8)
                .foregroundColor(isHovered ? .primary : .primary)
                .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(7)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

       

}


struct VisualEffectViewBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}
