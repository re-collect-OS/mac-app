import SwiftUI
import SQLite
import Foundation
import Sentry

class SyncStateManager: ObservableObject {
    static let shared = SyncStateManager()

    @Published var isFetchingSafariHistory: Bool = false

    private init() {}
}

struct SafariHistorySyncView: SwiftUI.View {
    @State private var historyItems: [HistoryItem] = []
//    @State private var isFetching: Bool = false
    @State private var fetchSuccessful: Bool = false
    let sharedDefaults = UserDefaults(suiteName: "Q785W7SZ82.safariparser")
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var appStateManager: AppStateManager
    @StateObject private var syncStateManager = SyncStateManager.shared
    func checkDiskAccess() {
           let fileManager = FileManager.default
           let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
           do {
               let _ = try fileManager.contentsOfDirectory(atPath: path.path)
             print("")
           } catch {
               // Access denied, prompt the user to grant full disk access
               print("trying to get acess")
               SentrySDK.capture(error: error)
           }
       }
    
    func openSystemPreferencesForFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    
    var body: some SwiftUI.View {
        
        
        
        VStack (alignment: .leading, spacing:20) {
            HStack{
                Image("Onboarding_Safari")
                    .resizable()
                    .scaledToFit()
                    .frame(width:50)
                Spacer()
            }
            Text("Sync your Safari ")
                .font(.title)
                .fontWeight(.medium)
            Text("Connect and import your Safari history from this machine into your re:collect account.")
            VStack {
                if   self.syncStateManager.isFetchingSafariHistory {
                    ProgressView("Fetching history...")
                } else {
                    if fetchSuccessful {
                        VStack(alignment: .leading){
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Fetch successful! Your re:collect library will populate with the articles shortly.")
                                
                            }
                            HStack{
                                Button("Done"){
                                    appStateManager.shouldPresentSafariSheet = false
                                    
                                }
                                Spacer()
                            }
                        }
                    } else {
                        HStack{
                            Button("Fetch History") {
                                fetchHistory()
                            }
                            .controlSize(.large)
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "4240B9"))
                            
                            Button("No thanks") {
                                appStateManager.shouldPresentSafariSheet = false
                            }
                            
                    
                            
                            
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 40)
        
        .onAppear {
                            checkDiskAccess()
                        }
    }
       
    func fetchHistory() {
        self.syncStateManager.isFetchingSafariHistory = true
        fetchSuccessful = false
        
        Task {
            await loadHistory()
            self.syncStateManager.isFetchingSafariHistory = false
            fetchSuccessful = true
        }

    }
    
    func sendHistoryData(urlVisits: [URLVisit]) async {
        await authManager.sendUserData(urlVisits: urlVisits)
    }

    

    func loadHistory() async {
        amplitude.track(
            eventType: "Onboarding: started import Safari History."
        )
        let historyFilePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari/History.db")
        let dateFormatter = ISO8601DateFormatter()

        do {
            let db = try SQLite.Connection(historyFilePath.absoluteString, readonly: true)
            let historyItemsTable = Table("history_items")
            let historyVisitsTable = Table("history_visits")
            let id = SQLite.Expression<Int64>("id")
            let url = SQLite.Expression<String>("url")
            let visitTime = SQLite.Expression<Double>("visit_time")

            var latestVisitTimes: [String: Double] = [:]

            let query = historyItemsTable
                .join(historyVisitsTable, on: historyItemsTable[id] == historyVisitsTable[Expression<Int64>("history_item")])
                .select(historyItemsTable[url], historyVisitsTable[visitTime])
                .order(visitTime.desc)

            for history in try db.prepare(query) {
                let itemURL = cleanURL(history[url])
                let timestamp = history[visitTime]

                // Process for the latest timestamp
                if shouldIncludeURL(itemURL) {
                    if let existingTimestamp = latestVisitTimes[itemURL], timestamp > existingTimestamp {
                        latestVisitTimes[itemURL] = timestamp
                    } else if latestVisitTimes[itemURL] == nil {
                        latestVisitTimes[itemURL] = timestamp
                    }
                }
            }

            var urlVisits: [URLVisit] = []
            for (itemURL, timestamp) in latestVisitTimes {
                let dateString = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timestamp))
                let urlVisit = URLVisit(timestamp: dateString, url: itemURL, title: "", transitionType: "link")
                urlVisits.append(urlVisit)
            }

            // Directly work with URLVisits for server communication
            await sendHistoryData(urlVisits: urlVisits)

            // Optionally, convert URLVisits to HistoryItems for local file operations
            let historyItems = urlVisits.map { HistoryItem(timestamp: $0.timestamp, url: $0.url, title: $0.title, transitionType: $0.transitionType) }
            DispatchQueue.main.async {
                self.historyItems = historyItems
                saveHistoryItemsAsJSON(historyItems)
                // Log the count of history items saved.
                print("Saved \(historyItems.count) history items to JSON file.")
                amplitude.track(
                    eventType: "Onboarding: finished import Safari History."
                )
            }

        } catch {
            print("Error opening database or reading data: \(error)")
            SentrySDK.capture(error: error)
        }
    }




    func shouldIncludeURL(_ url: String) -> Bool {
        let urlLC = url.lowercased()
        if excludedDomains.contains(where: urlLC.contains) {
            return false
        }

        let urlComponents = URLComponents(string: urlLC)
        if let pathExtension = urlComponents?.path.split(separator: ".").last {
            if excludedFileTypes.contains(String(pathExtension)) {
                return false
            }
        }

        return true
    }
    func saveHistoryItemsAsJSON(_ items: [HistoryItem]) {
           let encoder = JSONEncoder()
           if let encodedData = try? encoder.encode(items) {
               do {
                   // Get the URL for the Application Support directory
                   let directoryURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

                   // Define the file name and extension
                   let filename = "SafariHistory.json"
                   
                   // Create the full file URL in the Application Support directory
                   var fileURL = directoryURL.appendingPathComponent(filename)
                   
                   // Write the encoded data to the file
                   try encodedData.write(to: fileURL, options: .atomic)
                   
                   // Optionally, exclude the file from iCloud backups
                   var resourceValues = URLResourceValues()
                   resourceValues.isExcludedFromBackup = true
                   try fileURL.setResourceValues(resourceValues)
                   
                   print("History items saved to: \(fileURL.path)")
                
               } catch {
                   print("Failed to save history items: \(error.localizedDescription)")
                   SentrySDK.capture(error: error)
               }
           }
       }
    
    func cleanURL(_ url: String) -> String {
            guard let urlComponents = URLComponents(string: url) else {
                return url
            }
            
            var cleanComponents = URLComponents()
            cleanComponents.scheme = urlComponents.scheme
            cleanComponents.host = urlComponents.host
            cleanComponents.path = urlComponents.path
            
            return cleanComponents.url?.absoluteString ?? url
        }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    
}



struct HistoryItem: Codable {
    let timestamp: String
    let url: String
    let title: String
    let transitionType: String
}
