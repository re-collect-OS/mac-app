
import Foundation
import SwiftUI
import Combine
import AmplitudeSwift
import Sentry

let amplitude = Amplitude(configuration: Configuration(
    apiKey: "4fc552a081596886e9aedc6d4135c4a4",
    defaultTracking: DefaultTrackingOptions(sessions: false)
))


struct SearchView: View {
    @State private var authManager: AuthenticationManager = AuthenticationManager()
    @ObservedObject var sharedStateManager = SharedStateManager.shared
    @FocusState private var isTextFieldFocused: Bool
    @State private var isTextFieldActive: Bool = false
    @State private var isRequestInProgress: Bool = false
    @State private var selectedFilter: Int? = nil
    @State private var showFilters: Bool = false
    @State private var selectedType: String? = "web"
    @State private var selectedTime: Double = 0
    @State private var selectedDomain: String = ""
    @State private var hover: Bool = false
    @EnvironmentObject var appStateManager: AppStateManager
    @State private var sliderValue: Double = 0
    @State private var shouldShowFilterReminder: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var scrollViewId = UUID()
    @State private var searchPerformed = false
    @State private var documents: [Document] = []
    @State private var isSearchInProgress = false
    @State private var cardWindows: [FlatWindow] = []
    @State private var cardWindowsVisible: Bool = false
    @State private var searchText = ""
    @State private var peeledCards: [PeeledCard] = []
    @State private var stackId: String?
    
    let searchQueryCharacterLimit = 150
    
    var hasCardWindows: Bool {
        return !cardWindows.isEmpty
    }
    
    func sliderValueToISO8601(sliderValue: Double) -> String {
        let currentDate = Date()
        var dateComponent = DateComponents()
        
        if sliderValue <= 50 {
            let days = Int(sliderValue / 50 * 14)
            dateComponent.day = -days
        } else if sliderValue <= 75 {
            let weeks = Int((sliderValue - 50) / 25 * 5) + 3
            dateComponent.weekOfYear = -weeks
        } else if sliderValue < 100 {
            let months = Int((sliderValue - 75) / 25 * 9) + 3
            dateComponent.month = -months
        } else {
            return ""
        }
        
        let calendar = Calendar.current
        if let date = calendar.date(byAdding: dateComponent, to: currentDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            return formatter.string(from: date)
        }
        
        return ""
    }
    
    func timeRangeText(from value: Double) -> String {
        if value <= 50 {
            let days = Int((value / 50) * 14)
            return days == 0 ? "In the last 0 days" : "In the last \(days) days"
        } else if value <= 75 {
            let weeks = Int((value - 50) / 25 * 5) + 3
            return "In the last \(weeks) weeks"
        } else if value < 100 {
            let months = Int((value - 75) / 25 * 9) + 3
            return "In the last \(months) months"
        } else {
            return "All time"
        }
    }
    
    func decodeJsonResponse(jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        var temporaryDocuments = [Document]()
        var seenDocIds = Set<String>()
        
        do {
            let jsonResponse = try decoder.decode(JsonResponse.self, from: jsonData)
            self.stackId = jsonResponse.stack_id // Store the stack_id
            for document in jsonResponse.results {
                if seenDocIds.contains(document.doc_id) { continue }
                seenDocIds.insert(document.doc_id)
                temporaryDocuments.append(document)
            }
            DispatchQueue.main.async {
                self.documents = temporaryDocuments
            }
        } catch {
            print("Error decoding JSON: \(error)")
            SentrySDK.capture(error: error)
        }
    }
    
    func performSearch(query: String, docType: String?, startTime: String?, domain: String?) async {
        self.isSearchInProgress = true
        
        var filterBy: [String: Any] = [:]
        if let docType = docType { filterBy["doc_type"] = docType }
        if let startTimeString = startTime {
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd"
            if let startDate = inputFormatter.date(from: startTimeString) {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let startTimeISO = isoFormatter.string(from: startDate)
                filterBy["start_time"] = startTimeISO
            }
        }
        if let domain = domain { filterBy["domain"] = domain }
        
        await authManager.sendPostRequest(query: query, numConnections: 40, minScore: 0.5, hybridSearchFactor: 1.0, filterBy: filterBy) { response in
            if response == "No results" {
                DispatchQueue.main.async {
                    self.documents = []
                    self.isSearchInProgress = false
                }
            } else {
                self.decodeJsonResponse(jsonString: response)
                DispatchQueue.main.async {
                    self.isSearchInProgress = false
                }
            }
        }
    }
    
    func createPeeledRecallCardWindow(cardTitle: String, cardContent: String, cardURL: String?, docId: String, isScreenshot: Bool, thumbnailS3Path: String?, at position: CGPoint) {
        let mouseLocation = NSEvent.mouseLocation
        let windowWidth: CGFloat = 350
        let windowHeight: CGFloat = isScreenshot ? 600 : 300
        
        let windowX = mouseLocation.x - windowWidth / 2
        let windowY = mouseLocation.y - windowHeight / 2
        
        let card = PeeledCard(title: cardTitle, content: cardContent, url: cardURL, docId: docId, isScreenshot: isScreenshot, thumbnailPath: thumbnailS3Path, window: nil)
        let windowID = UUID()
        let cardWindow = FlatWindow(windowID: windowID, CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), showCloseButton: true) {
            self.peeledCards.removeAll { $0.docId == docId }
        } content: {
            PeeledRecallCardView(
                authManager: authManager,
                cardTitle: cardTitle,
                cardContent: cardContent,
                cardURL: cardURL,
                docId: docId,
                isScreenshot: isScreenshot,
                thumbnailS3Path: thumbnailS3Path
            )
            .cornerRadius(15)
            .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
        }
        
        DispatchQueue.main.async {
            var newCard = card
            newCard.window = cardWindow
            self.peeledCards.append(newCard)
            if !self.cardWindowsVisible {
                self.cardWindowsVisible.toggle()
            }
            cardWindow.orderFrontRegardless()
        }
    }
    
    
    
    func removeDocumentFromStack(withId docId: String) {
        self.documents.removeAll { $0.doc_id == docId }
    }
    
    
    @State private var abstractCards: [AbstractCard] = []
    
    
    func createAbstractCardWindow(abstract: String, titles: [String], docIds: [String], bodies: [String], prompt: String, system_prompt: String) {
        let viewModel = AbstractResponseViewModel()
        viewModel.appendResponse(with: abstract)
        
        let windowID = UUID()
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 300
        
        // Get the screen dimensions
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            // Calculate the center position
            let windowX = (screenFrame.width - windowWidth) / 2
            let windowY = (screenFrame.height - windowHeight) / 2
            
            let cardWindow = FlatWindow(windowID: windowID, CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), showCloseButton: true) {
                self.abstractCards.removeAll { $0.window.windowID == windowID }
            } content: {
                AbstractCardView(viewModel: viewModel, cardTitle: "Remixx")
                    .cornerRadius(15)
                    .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
            }
            
            let abstractCard = AbstractCard(window: cardWindow, titles: titles, docIds: docIds, bodies: bodies)
            DispatchQueue.main.async {
                self.abstractCards.append(abstractCard)
                cardWindow.orderFrontRegardless()
                animateAndClosePeeledCards()
                // Send the graph abstract request and update the view model with streaming responses
                Task {
                    await authManager.sendGraphAbstractRequest(
                        searchQuery: abstract,
                        artifactIds: docIds,
                        titles: titles,
                        highlights: bodies,
                        systemPrompt: system_prompt,
                        Prompt: prompt,
                        viewModel: viewModel
                    ) { result in
                        switch result {
                        case .success:
                            print("Abstract request completed successfully")

                        case .failure(let error):
                            print("Failed to generate abstract: \(error)")
                        }
                    }
                    
                }
            }
        }
    }

    
    
    func createAbstractCardWindow(viewModel: AbstractResponseViewModel, titlesAndLinks: [(String, String)]) {
        viewModel.setDocumentLinks(titlesAndLinks) // Set the document links in the view model
        
        let windowID = UUID()
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 300
        
        // Get the screen dimensions
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            // Calculate the center position
            let windowX = (screenFrame.width - windowWidth) / 2
            let windowY = (screenFrame.height - windowHeight) / 2
            
            let cardWindow = FlatWindow(windowID: windowID, CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), showCloseButton: true) {
                self.abstractCards.removeAll { $0.window.windowID == windowID }
            } content: {
                AbstractCardView(viewModel: viewModel, cardTitle: "Gist")
                    .cornerRadius(15)
                    .background(BlurView(material: .hudWindow, blendingMode: .withinWindow, state: .active))
            }
            
            let abstractCard = AbstractCard(window: cardWindow, titles: titlesAndLinks.map { $0.0 }, docIds: titlesAndLinks.map { $0.1 }, bodies: titlesAndLinks.map { $0.0 })
            DispatchQueue.main.async {
                self.abstractCards.append(abstractCard)
                cardWindow.orderFrontRegardless()
            }
        }
    }

    func animateAndClosePeeledCards() {
        if !peeledCards.isEmpty {
            peeledCards = peeledCards.filter { $0.window?.isVisible == true }
            
            for card in peeledCards {
                guard let window = card.window else { continue }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 1.5 // Set the duration of the animation
                    
                    // Apply the fade-out animation
                    window.animator().alphaValue = 0
                    
                    // Get the screen dimensions and calculate the center point
                    if let screen = window.screen {
                        let screenFrame = screen.frame
                        let windowWidth = window.frame.width
                        let windowHeight = window.frame.height
                        
                        // Calculate the center position
                        let windowX = (screenFrame.width - windowWidth) / 2
                        let windowY = (screenFrame.height - windowHeight) / 2
                        
                        let targetFrame = CGRect(
                            x: windowX,
                            y: windowY,
                            width: windowWidth,
                            height: windowHeight
                        )
                        window.animator().setFrame(targetFrame, display: true)
                    }
                } completionHandler: {
                    window.orderOut(nil)
                }
            }
            
            peeledCards.removeAll()
        }
    }

    
    
    func sendGraphAbstractRequestForPeeledCards() {
        if !peeledCards.isEmpty {
            let searchQuery = searchText
            let artifactIds = peeledCards.map { $0.docId }
            let titlesAndLinks = peeledCards.map { ($0.title, $0.url ?? "") }
            let dispatchGroup = DispatchGroup()

            // Check if highlights are too short and fetch more data if necessary
            for card in peeledCards {
                if card.content.count < 100 {
                    print("SUPERMAN")
                    dispatchGroup.enter() // Enter the dispatch group
                    // Asynchronously fetch more data if the highlight is too short
                    Task {
                        await authManager.getUserData(docId: card.docId) { jsonResponse in
                            guard let data = jsonResponse.data(using: .utf8),
                                  let document = try? JSONDecoder().decode(Document.self, from: data),
                                  let text = document.sentences?.map({ $0.text }).joined(separator: " ") else {
                                      dispatchGroup.leave() // Leave the dispatch group even if there's an error
                                      return
                                  }
                            let updatedText = String(text.prefix(300)) // Use first 300 characters
                            DispatchQueue.main.async {
                                print("AFTER SUPERMAN")
                                print(updatedText)
                                if let index = peeledCards.firstIndex(where: { $0.docId == card.docId }) {
                                    peeledCards[index].content = updatedText // Update the content in the peeled card
                                }
                                dispatchGroup.leave() // Leave the dispatch group after updating the content
                            }
                        }
                    }
                }
            }

            // Notify when all async tasks are complete
            dispatchGroup.notify(queue: .main) {
                let highlights = peeledCards.map { $0.content }
                let viewModel = AbstractResponseViewModel()
                let bodies = peeledCards.map { $0.content }

                let output_style = "a concise highly personalized tl;dr"
                let input_style = "text excerpts from articles, google docs and/or personal notes"

                let pattern = """
                The tone, voice, personality, style, and structure of these concise, highly personalized TL;DRs can be described as follows:

                Tone: Informal, conversational. The TL;DR sounds like it's coming from a knowledgeable friend who is summarizing the main points in a casual, relatable way.

                Voice: The voice is distinctive and expressive, using contractions, idioms, and colloquialisms to convey a sense of personality. It feels like the writer is speaking directly to the reader.

                Personality: The personality comes across as intelligent, insightful, and somewhat irreverent. The writer seems to have a good grasp of the subject matter but isn’t afraid to present it in a lighthearted or even slightly sarcastic manner. TO Personality: The personality comes across as intelligent, insightful, and somewhat irreverent. The writer seems to have a good grasp of the subject matter but isn’t afraid to present it in a lighthearted or and understandable way.
                
                Style: The writing style is concise and punchy, favoring short sentences and active verbs. It often uses metaphors, similes, or other figurative language to make the summary more engaging and memorable.

                Structure: The TL;DR typically consists of one or two sentences that capture the essence of the text excerpts. It may start with a broad statement that encapsulates the main theme, followed by a more specific observation or conclusion. The structure is designed to be easily digestible and impactful.

                To create similar TL;DRs, an AI should:
                1. Identify the key points and overarching themes in the text excerpts
                2. Synthesize the information into a concise, one- or two-sentence summary
                3. Use informal, conversational language and include contractions, idioms, or colloquialisms
                4. Employ figurative language, humor, or slight sarcasm when appropriate
                5. Focus on creating a punchy, memorable statement that captures the essence of the text
                6. Ensure the TL;DR can stand alone and conveys the main message even without the full context of the excerpts.
                """

                let example_inputs = """
                - We used the printing press as a machine that opens up what's available. The first evolutionary boost.
                - The printing press (around 1440) and then the Renesaince leaving more time for more people to consume media and follow their curiosity led to greater access. ; Around 1750 Diderot creates one of the first widely available Encyclopedias.
                - to collect all the knowledge that now lies scattered over the face of the earth, to make known its general structure to the men among we live, and to transmit it to those who will come after us", to make men not only wiser but also "more virtuous and more happy."
                - Realizing the inherent problems with the model of knowledge he had created, Diderot's view of his own success in writing the Encyclopédie were far from ecstatic.Diderot envisioned the perfect encyclopedia as more than the sum of its parts.In his own article on the encyclopedia, Diderot also wrote, "Were an analytical dictionary of the sciences and arts nothing more than a methodical combination of their elements, I would still ask whom...
                - 1936- H.G. Wells talks about a world encyclopedia in his World Brain book. He realized that the world was getting smaller as information traveled quickly and also feeling the changes that led to world war 2, believed that coordinated world knowledge was the only way forward.
                """

                let example_outputs = """
                We developed technology to overcome geographic and temporal limitations for access to knowledge- but it came back to bite us.
                """

                let prompt = """
                    To craft your response, condense information from multiple documents into a concise
                    synthesis that meets the goal of \(searchQuery) and that doesn't use unnecessary buzzwords.
                    YOU NEED TO reference the text from the documents. Here are the document titles:
                        \(titlesAndLinks) and here are the most important sentences in the same documents: \(highlights).

                    Make it like a fresh abstraction that mentions all the highlights explicitly but subtly.
                    Your response should NOT start with the word "synthesis" or "summary".
                    Just start with the actual content every single time. So don't start with things like
                    "here's a summary" etc. Just spit out the content.
                """

                let system_prompt =  """
                You are an expert article summarizer. You should sound as objective as possible. Your task is to summarize text excerpts from articles, google docs and/or personal notes into a concise highly personalized tl;dr as they are related to \(searchQuery) that follows the following style \(pattern)

                Here's \(output_style) made from \(input_style) \(example_outputs) based on \(example_inputs) but don't use these explciitly or reference them at all. No referencing to the examples. Please create \(output_style) that follows the style above.
                Here are the input document titles: \(titlesAndLinks) and here are the most important sentences in the same documents: \(highlights).

                Think step-by-step about the main points of the \(input_style) and write \(output_style) that follows the style and structure above. Pay attention to the examples given above and try to match them as closely as possible. Do not include any pre-ambles or post-ambles. Return text answer only, do not wrap answer in any XML tags.
                Your response should NOT start with the word 'synthesis' or 'summary' or 'tldr'. Your response should be one or two sentences long. Summary:
                """

                let capturedPeeledCards = peeledCards // Capture the current state of peeledCards

                createAbstractCardWindow(viewModel: viewModel, titlesAndLinks: titlesAndLinks)

                print("Peeled cards before closing")
                print(capturedPeeledCards.map { $0.docId }) // Use the capturedPeeledCards

                animateAndClosePeeledCards()

                Task {
                    await authManager.sendGraphAbstractRequest(
                        searchQuery: searchQuery,
                        artifactIds: artifactIds,
                        titles: titlesAndLinks.map { $0.0 },
                        highlights: highlights,
                        systemPrompt: system_prompt,
                        Prompt: prompt,
                        viewModel: viewModel
                    ) { result in
                        switch result {
                        case .success:
                            print("Abstract request completed successfully")
                            saveGeneratedArtifactForPeeledCards(viewModel: viewModel, prompt: prompt, systemPrompt: system_prompt, peeledCards: capturedPeeledCards) // Pass the capturedPeeledCards
                        case .failure(let error):
                            print("Failed to generate abstract: \(error)")
                        }
                    }
                }
            }
        }
    }

    func saveGeneratedArtifactForPeeledCards(viewModel: AbstractResponseViewModel, prompt: String, systemPrompt: String, peeledCards: [PeeledCard]) {
        print("Peeled cards now 391")
        print(peeledCards.map { $0.docId }) // Use the passed peeledCards
        let searchQuery = searchText
        let artifactIds = peeledCards.map { $0.docId }
        let modelParameters: [String: Any] = [
            "Prompt": prompt,
            "system_prompt": systemPrompt,
            "temperature": 0,
            "model_name": "meta-llama/Meta-Llama-3-70B-Instruct"
        ]
        let metadata: [String: Any] = [
            "query": searchQuery,
            "stack_id": stackId, // Use the dynamic stack_id
            "artifact_ids": artifactIds,
            "model_parameters": modelParameters
        ]

        Task {
            await authManager.saveGeneratedArtifact(
                kind: "recall",
                indexableText: viewModel.responseText, // Use responseText from viewModel
                mimeType: "text/plain",
                metadata: metadata
            ) { result in
                switch result {
                case .success(let response):
                    print("Success: \(response)")
                case .failure(let error):
                    print("Failure: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    
    
    func functionThatFails() throws {
        throw TestError.intentionalError
    }
    
    enum TestError: Error {
        case intentionalError
    }
    
    
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if let url = URL(string: "https://app.re-collect.ai") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(colorScheme == .dark ? "logotypewhite" : "logotype")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 25)
                        .padding(.leading, 2.5)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .frame(width: 1, height: 25)
                    .padding(.leading, -10)
                
                Menu {
                    Button(action: { sharedStateManager.isPinned.toggle() }) {
                        Text(sharedStateManager.isPinned ? "✓ Pinned" : "Pin")
                    }
                    Button("Settings") { WindowManager.shared.showMainWindow() }
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "chevron.down")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 6)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .menuIndicator(.hidden)
                .padding(.leading, -10)
                .frame(width: 10)
                
                Spacer()
                if peeledCards.count >= 2 {
                    StyledButton(label: "", systemIcon: "circle.hexagongrid.fill") {
                        sendGraphAbstractRequestForPeeledCards()
                    }
                }
                
                StyledButton(label: "", systemIcon: "house") {
                    if let url = URL(string: "https://app.re-collect.ai") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .padding(.trailing,5)

            }
            .zIndex(09999999999)
            .padding(.bottom, -20)
            .padding(.top, 20)
            //            .background(Color.red)
            
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        //                        Button("Print Card Windows") {
                        //                            for card in peeledCards {
                        //                                print("Title: \(card.title)")
                        //                                print("Content: \(card.content)")
                        //                                print("Document ID: \(card.docId)")
                        //                                print("URL: \(card.url ?? "No URL")")
                        //                                print("Is Screenshot: \(card.isScreenshot)")
                        //                                print("Thumbnail Path: \(card.thumbnailPath ?? "No Thumbnail")")
                        //                                print("------------------------------")
                        //                            }
                        //                        }

                        
                        TextField("Describe an idea or concept…", text: $searchText, axis: .vertical)
                            .font(Font.system(size: 17, design: .default))
                            .onChange(of: searchText) { newValue in
                                if newValue.count > searchQueryCharacterLimit {
                                    searchText = String(newValue.prefix(searchQueryCharacterLimit))
                                }
                            }
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 4)
                            .font(.title2)
                            .background(Color.clear)
                            .focused($isTextFieldFocused)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.isTextFieldFocused = true
                                }
                            }
                            .onChange(of: searchText) { newText in
                                if newText.isEmpty {
                                    selectedType = "web"
                                    selectedTime = 0
                                    selectedDomain = ""
                                    sliderValue = 0
                                }
                            }
                            .onSubmit {
                                searchPerformed = false
                                Task {
                                    documents.removeAll()
                                    isRequestInProgress = true
                                    
                                    var docTypeToSend: String? = nil
                                    var startTimeToSend: String? = nil
                                    var domainToSend: String? = nil
                                    
                                    if showFilters {
                                        amplitude.track(eventType: "Recall: toggled filters")
                                        switch selectedType {
                                        case "Article": docTypeToSend = "web"
                                        case "PDF": docTypeToSend = "pdf"
                                        case "Note": docTypeToSend = "recollect"
                                        case "YouTube": docTypeToSend = "video_transcription"
                                        case "Twitter": docTypeToSend = "twitter"
                                        case "Apple Notes": docTypeToSend = "native"
                                        default: break
                                        }
                                        if sliderValue != 0 {
                                            startTimeToSend = sliderValueToISO8601(sliderValue: sliderValue)
                                        }
                                        if !selectedDomain.isEmpty && (selectedType == "Note" || selectedType == "Article") {
                                            domainToSend = selectedDomain
                                        }
                                    }
                                    
                                    await performSearch(query: searchText, docType: docTypeToSend, startTime: startTimeToSend, domain: domainToSend)
                                    searchPerformed = true
                                    isRequestInProgress = false
                                    shouldShowFilterReminder = false
                                }
                                scrollViewId = UUID()
                            }
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.primary)
                            .padding(.horizontal, 4)
                            .padding(.top, 2.5)
                    }
                    .padding(.bottom, 10)
                    .padding(.top, 15)
                    
                    Spacer()
                    
                    if isSearchInProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.6)
                            .padding(.top, 10)
                    } else {
                        Button(action: { showFilters.toggle() }) {
                            Image(systemName: "slider.vertical.3")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .padding(.top, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 5)
            }
            .padding(.horizontal, 9)
            
            if shouldShowFilterReminder {
                HStack {
                    Text("Press enter to run search again with filters")
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 10))
                        .padding(.horizontal)
                        .padding(.top, -15)
                    Spacer()
                }
            }
            
            if showFilters {
                VStack(alignment: .leading) {
                    filterButtons.frame(height: 20)
                    filterOptions.frame(height: 30)
                }
                .onChange(of: selectedType) { _ in shouldShowFilterReminder = true }
                .onChange(of: sliderValue) { _ in shouldShowFilterReminder = true }
                .onChange(of: selectedDomain) { _ in shouldShowFilterReminder = true }
                .transition(.opacity)
            }
            
            if isSearchInProgress {
                VStack {
                    Spacer()
                    Text("Recalling...")
                    Spacer()
                }
                .frame(minHeight: 500)
            } else if documents.isEmpty && searchPerformed {
                VStack {
                    Spacer()
                    Text("No results")
                    Spacer()
                }
            } else if !documents.isEmpty {
                scrollViewContent
                    .id(scrollViewId)
            } else {
                VStack {
                    Spacer()
                    Spacer()
                }
                .frame(minHeight: 500)
            }
        }
        .cornerRadius(15)
    }
    
    var filterButtons: some View {
        VStack(alignment: .leading) {
            HStack {
                FilterButton(selectedFilter: $selectedFilter, filterId: 1, title: "Type")
                FilterButton(selectedFilter: $selectedFilter, filterId: 2, title: "Time")
                Button(action: {
                    if selectedType == "Note" || selectedType == "Article" {
                        selectedFilter = selectedFilter == 3 ? nil : 3
                    }
                }) {
                    Text("Domain")
                        .frame(maxWidth: .infinity)
                        .foregroundColor((selectedType == "Note" || selectedType == "Article") ? .primary : .gray)
                }
                .disabled(!(selectedType == "Note" || selectedType == "Article"))
                .background(selectedFilter == 3 && (selectedType == "Note" || selectedType == "Article") ? Color.clear : Color.clear)
                .cornerRadius(5)
            }
            .padding(.horizontal)
            .padding(.vertical, -10)
        }
    }
    
    @ViewBuilder
    var filterOptions: some View {
        Group {
            if selectedFilter != nil {
                switch selectedFilter {
                case 1:
                    VStack {
                        HStack {
                            Text("Select")
                            SegmentedPicker(["Article", "Note", "PDF", "YouTube", "Twitter", "Apple Notes"], selectedItem: $selectedType) { item in
                                Text(item)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                case 2:
                    HStack {
                        Text(timeRangeText(from: sliderValue))
                        Slider(value: $sliderValue, in: 0...100)
                            .onChange(of: sliderValue) { newValue in
                                let isoDate = sliderValueToISO8601(sliderValue: newValue)
                            }
                            .tint(Color.primary)
                    }
                    .padding(.horizontal)
                case 3:
                    HStack {
                        Text("Enter Domain")
                        TextField("instagram.com", text: $selectedDomain)
                            .disabled(!(selectedType == "Note" || selectedType == "Article"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(width: .infinity, height: 70)
                            .background(
                                ZStack(alignment: .bottom) {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(!(selectedType == "Note" || selectedType == "Article") ? Color.gray.opacity(0.5) : Color.gray)
                                        .padding(.top, 25)
                                }
                            )
                            .onSubmit {
                                Task {
                                    isRequestInProgress = true
                                    var docTypeToSend: String? = nil
                                    var startTimeToSend: String? = nil
                                    var domainToSend: String? = nil
                                    
                                    if showFilters {
                                        amplitude.track(eventType: "Recall: toggled filters")
                                        switch selectedType {
                                        case "Article": docTypeToSend = "web"
                                        case "PDF": docTypeToSend = "pdf"
                                        case "Note": docTypeToSend = "recollect"
                                        case "YouTube": docTypeToSend = "video_transcription"
                                        case "Twitter": docTypeToSend = "twitter"
                                        case "Apple Notes": docTypeToSend = "native"
                                        default: break
                                        }
                                        if sliderValue != 0 {
                                            startTimeToSend = sliderValueToISO8601(sliderValue: sliderValue)
                                        }
                                        if !selectedDomain.isEmpty && (selectedType == "Note" || selectedType == "Article") {
                                            domainToSend = selectedDomain
                                        }
                                    }
                                    
                                    await performSearch(query: searchText, docType: docTypeToSend, startTime: startTimeToSend, domain: domainToSend)
                                    isRequestInProgress = false
                                    shouldShowFilterReminder = false
                                }
                            }
                    }
                    .padding(.horizontal)
                default:
                    Spacer()
                }
            }
        }
        .frame(maxHeight: 30)
    }
    
    var scrollViewContent: some View {
        ScrollView {
            VStack(spacing: -15) {
                ForEach(documents) { document in
                    let displayTitle = document.doc_subtype == "note_card" ? "Daily Note" : document.title
                    if document.doc_type == "twitter", let tweets = document.tweets, !tweets.isEmpty {
                        let firstTweet = tweets.first!
                        let tweetContent = firstTweet.sentences.map { $0.text }.joined(separator: "\n")
                        DraggableCardView(
                            authManager: authManager,
                            cardTitle: displayTitle,
                            cardContent: tweetContent,
                            cardURL: document.url,
                            docId: document.doc_id,
                            isScreenshot: document.is_screenshot ?? false,
                            thumbnailPath: document.thumbnail_s3_path,
                            onPeel: { title, content, url, id, isScreenshot, thumbnailPath, position in
                                createPeeledRecallCardWindow(
                                    cardTitle: title,
                                    cardContent: content,
                                    cardURL: url,
                                    docId: id,
                                    isScreenshot: isScreenshot,
                                    thumbnailS3Path: thumbnailPath,
                                    at: position
                                )
                            },
                            onRemove: { id in
                                removeDocumentFromStack(withId: id)
                            }
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 15)
                    } else {
                        DraggableCardView(
                            authManager: authManager,
                            cardTitle: displayTitle,
                            cardContent: document.sentences?.map { $0.text }.joined(separator: "\n") ?? "",
                            cardURL: document.url,
                            docId: document.doc_id,
                            isScreenshot: document.is_screenshot ?? false,
                            thumbnailPath: document.thumbnail_s3_path,
                            onPeel: { title, content, url, id, isScreenshot, thumbnailPath, position in
                                createPeeledRecallCardWindow(
                                    cardTitle: title,
                                    cardContent: content,
                                    cardURL: url,
                                    docId: id,
                                    isScreenshot: isScreenshot,
                                    thumbnailS3Path: thumbnailPath,
                                    at: position
                                )
                            },
                            onRemove: { id in
                                removeDocumentFromStack(withId: id)
                            }
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 15)
                    }
                }
            }
            .padding(.top, -15)
        }
    }
    
    
    
}

struct FilterButton: View {
    @Binding var selectedFilter: Int?
    let filterId: Int
    let title: String
    
    var body: some View {
        Button {
            selectedFilter = selectedFilter == filterId ? nil : filterId
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .background(selectedFilter == filterId ? Color.clear : Color.clear)
        .cornerRadius(5)
    }
}

public struct SegmentedPicker<T: Hashable, Content: View>: View {
    @Namespace private var selectionAnimation
    @Binding var selectedItem: T?
    private let items: [T]
    private let content: (T) -> Content
    
    public init(_ items: [T], selectedItem: Binding<T?>, @ViewBuilder content: @escaping (T) -> Content) {
        self._selectedItem = selectedItem
        self.items = items
        self.content = content
    }
    
    @ViewBuilder func overlay(for item: T) -> some View {
        if item == selectedItem {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.2))
                .matchedGeometryEffect(id: "selectedSegmentHighlight", in: selectionAnimation)
        }
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(items, id: \.self) { item in
                    Button(action: {
                        withAnimation(.linear(duration: 0.04)) {
                            self.selectedItem = self.selectedItem == item ? nil : item
                        }
                    }) {
                        self.content(item)
                            .frame(minHeight: 14)
                    }
                    .buttonStyle(.bordered)
                    .contentShape(Rectangle())
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 1))
                    .overlay(self.overlay(for: item))
                    .cornerRadius(12)
                }
            }
        }
    }
}
