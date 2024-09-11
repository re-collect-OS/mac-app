//
//  SafariHistoryManager.swift
//  re-collect
//
//  Created by Mansidak Singh on 3/18/24.
//

import Foundation
import SQLite



    
    

class SafariHistoryManager {
    static let shared = SafariHistoryManager()
    private var authManager: AuthenticationManager?
    private let syncInterval: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
//    private let syncInterval: TimeInterval = 60 // 1 minute for testing

    private let userDefaultsKey = "lastSafariSyncTimestamp"


    private init() {}
    
    func configure(with authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    

    func attemptSync() {
        let now = Date().timeIntervalSince1970
        let lastSyncTimestamp = UserDefaults.standard.double(forKey: userDefaultsKey)

        if now - lastSyncTimestamp > syncInterval {
            print("It's about time ")
            performSync {
                UserDefaults.standard.set(now, forKey: self.userDefaultsKey)
            }
            
        }
        
        else {
            
            print("Not time yet")
        }
    }

    private func performSync(completion: @escaping () -> Void) {
        // Perform the sync operation
        SafariHistoryManager.shared.fetchAndSendSafariHistory { success, error in
            if success {
                print("Successfully synced Safari history.")
                completion()
            } else if let error = error {
                print("Failed to sync Safari history: \(error.localizedDescription)")
            }
        }
    }
    
    

    func fetchAndSendSafariHistory(completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let urlVisits = try await loadSafariHistory()
                print("THIS MANY")
                print(urlVisits.count)
                urlVisits.forEach { visit in
                    print("URL: \(visit.url) - Timestamp: \(visit.timestamp)")
                }
                
                await sendHistoryData(urlVisits: urlVisits)
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    private func loadSafariHistory() async throws -> [URLVisit] {
        let historyFilePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari/History.db")
        let db = try SQLite.Connection(historyFilePath.path)
        
        let historyItemsTable = Table("history_items")
        let historyVisitsTable = Table("history_visits")
        let id = SQLite.Expression<Int64>("id")
        let url = SQLite.Expression<String>("url")
        let visitTime = SQLite.Expression<Double>("visit_time")
        let historyItem = SQLite.Expression<Int64>("history_item")

        // Fetch the last sync timestamp; if none exists, default to 24 hours ago
        let lastSyncTimestamp = UserDefaults.standard.double(forKey: userDefaultsKey)
        let lastSyncTime = lastSyncTimestamp > 0 ? lastSyncTimestamp : Date().addingTimeInterval(-24 * 60 * 60).timeIntervalSince1970

        let query = historyItemsTable
            .join(historyVisitsTable, on: historyItemsTable[id] == historyVisitsTable[historyItem])
            .select(historyItemsTable[url], historyVisitsTable[visitTime])
            .where(historyVisitsTable[visitTime] > lastSyncTime)

        let dateFormatter = ISO8601DateFormatter()

        var urlVisits: [URLVisit] = []

        for history in try db.prepare(query) {
            let itemURL = cleanURL(history[url])
            let timestamp = history[visitTime]

            if shouldIncludeURL(itemURL) {
                let visit = URLVisit(timestamp: dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timestamp)), url: itemURL, title: "", transitionType: "link")
                urlVisits.append(visit)
            }
        }

        return urlVisits
    }



    private func shouldIncludeURL(_ url: String) -> Bool {
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

    private func cleanURL(_ url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else {
            return url
        }
        
        var cleanComponents = URLComponents()
        cleanComponents.scheme = urlComponents.scheme
        cleanComponents.host = urlComponents.host
        cleanComponents.path = urlComponents.path
        
        return cleanComponents.url?.absoluteString ?? url
    }

    private func sendHistoryData(urlVisits: [URLVisit]) async {
        guard let authManager = authManager else {
            print("AuthenticationManager is not configured in SafariHistoryManager.")
            return
        }
        
        // Placeholder: Send data using authManager
        await authManager.sendUserData(urlVisits: urlVisits)
    }
}
