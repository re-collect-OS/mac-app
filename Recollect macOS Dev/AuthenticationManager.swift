//
//  AuthenticationManager.swift
//  Recollect macOS Dev
//
//  Created by Mansidak Singh on 2/7/24.
//

import Amplify
import Alamofire
import Foundation
import AWSPluginsCore
import Sentry

class AuthenticationManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isSigningOut: Bool = false
    @Published var loginMessage: String? = nil
    @Published var isSyncing: Bool = false
    @Published var syncMessage: String = ""
    
    
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
    
   
    
    
    func signIn(username: String, password: String) async {
        do {
            let signInResult = try await Amplify.Auth.signIn(username: username, password: password)
            // Track event with Amplitude
            amplitude.track(eventType: "User: log in")
           
            if signInResult.isSignedIn {
                DispatchQueue.main.async {
                    // Handle successful sign-in
                    self.loginMessage = "Login successful!"
                    Task {
                        await self.setUserIdtoAmplitude() // Set user ID in Amplitude
                    }
                    self.isLoggedIn = true // Update isLoggedIn state
                }
            } else {
                DispatchQueue.main.async {
                    // Handle case where signInResult indicates not signed in, but no exception thrown
                    self.loginMessage = "Login failed: User is not signed in."
                }
            }
        } catch let authError as AuthError {
            // Detailed error handling for AuthError
            DispatchQueue.main.async {
                self.loginMessage = self.handleAuthError(authError)
                
            }
        } catch {
            // Handling for non-AuthError failures
            DispatchQueue.main.async {
                self.loginMessage = "Login failed: \(error.localizedDescription)"
                SentrySDK.capture(error: error)
            }
        }
    }

    func handleAuthError(_ error: AuthError) -> String {
        var errorMessage: String = "An unexpected error occurred."
        
        // Detailed switch case handling for different AuthError cases
        switch error {
        case .configuration(let description, _, _),
             .service(let description, _, _),
             .validation(_, let description, _, _),
             .notAuthorized(let description, _, _),
             .invalidState(let description, _, _),
             .sessionExpired(let description, _, _),
             .signedOut(let description, _, _),
             .unknown(let description, _):
            errorMessage = "\(description)"
        }
        print(errorMessage) // Optionally log the detailed error message for debugging
        return errorMessage
    }

    
    
    
    
    
    func getUserData(docId: String, completion: @escaping (String) -> Void) async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            
            if let cognitoSession = session as? AuthCognitoTokensProvider {
                let result = try await cognitoSession.getCognitoTokens()
                
                switch result {
                case .success(let tokens):
                    let accessToken = tokens.accessToken
                    
                    let headers: HTTPHeaders = [
                        .authorization(bearerToken: accessToken),
                        .accept("application/json"),
                        .contentType("application/json")
                    ]
                    
                    let urlString = "https://api.recollect.cloud/user-data?doc_id=\(docId)"
                    
                    AF.request(urlString, method: .get, headers: headers).validate().responseJSON { response in
                        switch response.result {
                        case .success(let data):
                            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                DispatchQueue.main.async {
                                    completion(jsonString)
                                    print(response)
                                }
                            } else {
                                DispatchQueue.main.async {
                                    completion("Failed to format JSON response")
                                    
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion("Request failed: \(error.localizedDescription)")
                                SentrySDK.capture(error: error)

                            }
                        }
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion("Failed to get tokens: \(error.localizedDescription)")
                        SentrySDK.capture(error: error)

                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion("Session is not Cognito tokens provider")

                }
            }
        } catch {
            DispatchQueue.main.async {
                completion("Failed to fetch auth session: \(error.localizedDescription)")
                SentrySDK.capture(error: error)

            }
        }
    }
    
    func signOut() async {
        isSigningOut = true
        do {
            try await Amplify.Auth.signOut()
            amplitude.track(
                eventType: "User: log out"
            )
            
            
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.isSigningOut = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isSigningOut = false
            }
        }
    }
    func checkUserState() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            DispatchQueue.main.async {
                self.isLoggedIn = session.isSignedIn
            }
            
        } catch {
            print("Fetch session failed with error \(error)")
            SentrySDK.capture(error: error)
        }
    }
    
    
    
    
    func fetchEmail() async throws -> String {
        // Fetch all attributes for the current authenticated user
        let attributes = try await Amplify.Auth.fetchUserAttributes()
        
        // Find the email attribute
        guard let emailAttribute = attributes.first(where: { $0.key == AuthUserAttributeKey.email }) else {
            throw NSError(domain: "AuthenticationManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Email attribute not found"])
        }
        amplitude.setUserId(userId: emailAttribute.value)
        print("printing user id")
        print(emailAttribute.value)
        
        return emailAttribute.value
    }
    
    
    
    
    
    
    
    
    func sendPostRequest(query: String, numConnections: Int,
                         minScore: Double, hybridSearchFactor: Double,
                         filterBy: [String: Any], // New parameter for filter_by
                         completion: @escaping (String) -> Void) async {
        
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            
            if let cognitoSession = session as? AuthCognitoTokensProvider {
                let result = try await cognitoSession.getCognitoTokens()
                
                switch result {
                case .success(let tokens):
                    let accessToken = tokens.accessToken
                    
                    let headers: HTTPHeaders = [
                        .authorization(bearerToken: accessToken),
                        .accept("application/json"),
                        .contentType("application/json")
                    ]
                    
                    let parameters: [String: Any] = [
                        "query": query,
                        "num_connections": numConnections,
                        "min_score": minScore,
                        "source": "mac-app",
                        "hybrid_search_factor": hybridSearchFactor,
                        "engine": "paragraph-embedding-v2",
                        "filter_by": filterBy // Include the new filterBy parameter
                    ]
                    
                    let urlString = "https://api.recollect.cloud/connections"
                    print("Sending request with filters: \(filterBy)")

                    AF.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                        switch response.result {
                        case .success(let data):
                            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                print("RESPONSE SUCCESS: \(jsonString)")
                                amplitude.track(
                                    eventType: "Recall: did Recall"
                                )
                                DispatchQueue.main.async {
                                    if let jsonResponse = try? JSONDecoder().decode(JsonResponse.self, from: jsonData) {
                                        if jsonResponse.results.isEmpty {
                                            // Call completion with a specific message or simply indicate no results
                                            DispatchQueue.main.async {
                                                completion("No results") // Indicate no results were found
                                            }
                                        } else {
                                            // Existing logic to handle non-empty results
                                            DispatchQueue.main.async {
                                                completion(jsonString) // Proceed with existing results
                                            }
                                        }
                                    } else {
                                        completion("Failed to decode JSON response")
                                    }
                                }
                            }
                        case .failure(let error):
                            print("Request failed with error: \(error)")
                            SentrySDK.capture(error: error) // Capture the error with Sentry
                            DispatchQueue.main.async {
                                completion("Request failed: \(error.localizedDescription)")
                            }
                            amplitude.track(
                                eventType: "Recall: failed",
                                eventProperties: ["Error": "\(error.localizedDescription)"]
                            )
                            
                        }
                    }
                    
                case .failure(let error):
                    print("Error getting tokens: \(error)")
                    SentrySDK.capture(error: error) // Capture the error with Sentry
                }
            } else {
                print("Session is not Cognito tokens provider")
            }
        } catch {
            print("Error fetching auth session: \(error)")
            SentrySDK.capture(error: error) // Capture the error with Sentry
        }
    }
    func sendUserData(urlVisits: [URLVisit], source: String = "mac-app") async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            
            if let cognitoSession = session as? AuthCognitoTokensProvider {
                let result = try await cognitoSession.getCognitoTokens()
                
                switch result {
                case .success(let tokens):
                    let accessToken = tokens.accessToken
                    
                    let headers: HTTPHeaders = [
                        .authorization(bearerToken: accessToken),
                        .accept("application/json"),
                        .contentType("application/json")
                    ]
                    
                    // Splitting the urlVisits into chunks of 1000
                    let chunks = urlVisits.chunked(into: 1000)
                    
                    for chunk in chunks {
                        let visitsArray: [[String: Any]] = chunk.map { visit in
                            [
                                "timestamp": visit.timestamp, // Ensure this is an ISO date string
                                "url": visit.url,
                                "title": visit.title,
                                "transition_type": visit.transitionType
                            ]
                        }
                        
                        let parameters: [String: Any] = [
                            "url_visits": visitsArray,
                            "source": source
                        ]
                        
                        let urlString = "https://api.recollect.cloud/user-data"
                        
                        // Await the completion of each request before continuing
                        await withCheckedContinuation { continuation in
                            AF.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                                switch response.result {
                                case .success(let responseData):
                                    // Directly print the raw JSON response
                                    print("Success with JSON: \(responseData)")
                                case .failure(let error):
                                    print("Request failed with error: \(error)")
                                    SentrySDK.capture(error: error)

                                }
                                continuation.resume()
                            }


                        }
                    }
                    
                case .failure(let error):
                    print("Error getting tokens: \(error)")
                    SentrySDK.capture(error: error)

                }
            } else {
                print("Session is not Cognito tokens provider")
            }
        } catch {
            print("Error fetching auth session: \(error)")
            SentrySDK.capture(error: error)
        }
    }
    
    
    
    
    
    
    
    
    
    
    func fetchOrCreateRecurringImportID() async -> String? {
        do {
            // Fetch Auth Session and Cognito Tokens
            let session = try await Amplify.Auth.fetchAuthSession()
            if let cognitoSession = session as? AuthCognitoTokensProvider {
                let result = try await cognitoSession.getCognitoTokens()
                
                switch result {
                case .success(let tokens):
                    let accessToken = tokens.accessToken
                    let urlString = "https://api.recollect.cloud/v2/recurring-imports/apple-notes"
                    
                    if let recurringImportID = try await getRecurringImportID(accessToken: accessToken, urlString: urlString) {
                        return recurringImportID
                    } else {
                        return try await createRecurringImportID(accessToken: accessToken, urlString: urlString)
                    }
                    
                case .failure(let error):
                    print("Error getting tokens: \(error.localizedDescription)")
                    SentrySDK.capture(error: error)

                }
            } else {
                print("Session is not Cognito tokens provider")
            }
        } catch {
            print("Error during the operation: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
        
        return nil
    }


    func getRecurringImportID(accessToken: String, urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("GET request failed, HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return nil
        }
        
        let responseObj = try JSONDecoder().decode(RecurringImportResponse.self, from: data)
        if responseObj.count > 0, let recurringImportID = responseObj.items.first?.id {
            print("Recurring Import ID fetched successfully: \(recurringImportID)")
            return recurringImportID
        }
        
        print("No Recurring Import ID found after GET request.")
        return nil
    }

    private func createRecurringImportID(accessToken: String, urlString: String) async throws -> String? {
        print("attempting new ID broski")

        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestBody = RecurringImportBody(enabled: true)
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let rawResponseString = String(data: data, encoding: .utf8) {
            print("Raw server response: \(rawResponseString)")
        } else {
            print("Unable to convert server response to string")
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            print("Failed to create Recurring Import ID, HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return nil
        }
        
        let responseObj = try JSONDecoder().decode(RecurringImportCreationResponse.self, from: data)
        print("New Recurring Import ID created successfully: \(responseObj.id)")
        return responseObj.id
    }



    func syncNotes(notes: [Note], source: String, completion: @escaping (Bool) -> Void) async {
        print("Number of notes received: \(notes.count)") // Print the number of notes

        guard let recurringImportID = await fetchOrCreateRecurringImportID() else {
            print("Failed to fetch recurring import ID")
            completion(false)
            return
        }

        // Check if there are enough notes to warrant batching
        let shouldBatch = notes.count > 10
        print("Batching required: \(shouldBatch ? "Yes" : "No")") // Print whether batching is required

        let batches = shouldBatch ? notes.chunked(into: 10) : [notes]
        print("Number of batches: \(batches.count)") // Print the number of batches

        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                print("Session is not Cognito tokens provider for syncing notes")
                completion(false)
                return
            }

            let tokensResult = try await cognitoSession.getCognitoTokens()
            switch tokensResult {
            case .success(let tokens):
                let accessToken = tokens.accessToken
                print("Successfully obtained access token for sync operation.")

                for batch in batches {
                    // Perform the sync operation for each batch (or the entire set if batching is not needed)
                    if await !sendBatch(batch: batch, accessToken: accessToken, recurringImportID: recurringImportID, source: source) {
                        completion(false)
                        return
                    }
                }

                completion(true)
            case .failure(let error):
                print("Error getting tokens for syncing notes: \(error.localizedDescription)")
                SentrySDK.capture(error: error)

                completion(false)
            }
        } catch {
            print("Error fetching auth session for syncing notes: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
            completion(false)
        }
    }

    
        // Helper function to perform the actual sync operation for a batch
    private func sendBatch(batch: [Note], accessToken: String, recurringImportID: String, source: String) async -> Bool {
        let urlString = "https://api.recollect.cloud/v2/apple-notes/sync"
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestPayload = SyncNotesRequest(notes: batch, recurringImportID: recurringImportID, source: source)
        guard let jsonData = try? JSONEncoder().encode(requestPayload) else { return false }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Failed to get HTTP response")
                return false
            }
            
            // Convert the server's response to a String to print regardless of the result, success or failure.
            let serverResponse = String(data: data, encoding: .utf8) ?? "Unable to convert server response to string"
            print("Server Response: \(serverResponse)")
            
            // Handle successful server response with HTTP Status Code 200 or 201, as examples
            if httpResponse.statusCode == 200 {
                print("Sync operation successful. Server response: \(serverResponse)")
                return true // Assuming the operation is complete and successful
            } else if httpResponse.statusCode == 201 {
                print("Resource created successfully. Server response: \(serverResponse)")
                return true // Assuming the resource creation operation is complete and successful
            }
            
            // Specifically handle server errors (e.g., HTTP Status Code 500)
            if httpResponse.statusCode == 500 {
                print("Failed to sync notes, HTTP Status Code: 500. Server error message: \(serverResponse)")
            } else {
                // Handle other erroneous status codes by providing generic feedback
                print("Failed to sync notes, HTTP Status Code: \(httpResponse.statusCode). Server response: \(serverResponse)")
            }
            
            return false // If the code reaches here, the operation was not successful
            
        } catch {
            // Catch and print any errors thrown during the networking operation itself
            print("Error in networking operation while syncing notes batch: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
            return false
        }
    }
    
    
    
    
    
}




extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension AuthenticationManager {
    func fetchNotesIntegrationEnabledState() async -> Bool? {
        print("attempted extension")
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            if let cognitoSession = session as? AuthCognitoTokensProvider {
                let result = try await cognitoSession.getCognitoTokens()
                
                switch result {
                case .success(let tokens):
                    let accessToken = tokens.accessToken
                    let urlString = "https://api.recollect.cloud/v2/recurring-imports/apple-notes"
                    
                    guard let url = URL(string: urlString) else {
                        print("Invalid URL: \(urlString)")
                        return nil
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        print("GET request failed, HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                        return nil
                    }
                    
                    let responseObj = try JSONDecoder().decode(RecurringImportResponse.self, from: data)
                    print(responseObj)
                    if responseObj.count > 0, let isEnabled = responseObj.items.first?.settings.enabled {
                        return isEnabled
                    }
                    
                case .failure(let error):
                    print("Error getting tokens: \(error.localizedDescription)")
                    SentrySDK.capture(error: error)

                }
            } else {
                print("Session is not Cognito tokens provider")
            }
        } catch {
            print("Error during the operation: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
        
        return nil
    }
    
    
    

    
    
}



extension AuthenticationManager {
   
    
    func fetchThumbnail(for path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return completion(.failure(URLError(.badURL)))
        }
        
        let fullPath = "https://api.recollect.cloud/v2/thumbnail/?s3_path=\(encodedPath)"
        
        guard let url = URL(string: fullPath) else {
            return completion(.failure(URLError(.badURL)))
        }
        
        // Authenticate and fetch the session
        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                if let cognitoSession = session as? AuthCognitoTokensProvider {
                    let result = try await cognitoSession.getCognitoTokens()
                    
                    switch result {
                    case .success(let tokens):
                        let accessToken = tokens.accessToken
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "GET"
                        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                        
                        URLSession.shared.dataTask(with: request) { data, response, error in
                            guard let data = data, error == nil else {
                                return completion(.failure(error ?? URLError(.cannotLoadFromNetwork)))
                            }
                            return completion(.success(data))
                        }.resume()
                        
                    case .failure(let error):
                        print("Error getting tokens: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                } else {
                    print("Session is not a Cognito tokens provider")
                    completion(.failure(URLError(.unsupportedURL))) // Use an appropriate error
                }
            } catch {
                print("Error fetching auth session or decoding JSON: \(error.localizedDescription)")
                SentrySDK.capture(error: error)
                completion(.failure(error))
            }
        }
    }
    
    
    
    
    
    func sendGraphAbstractRequest(searchQuery: String, artifactIds: [String], titles: [String], highlights: [String], systemPrompt: String, Prompt: String, viewModel: AbstractResponseViewModel, completion: @escaping (Result<Void, Error>) -> Void) async {
        let urlString = "https://api.recollect.cloud/gist"
        
        let payload = GraphAbstractRequest(
            search_query: searchQuery,
            artifact_ids: artifactIds,
            titles: titles,
            highlights: highlights,
            system_prompt: systemPrompt,
            prompt: Prompt
        )
        
        print("Payload preparation:")
        print(payload)
        
        do {
            try payload.validate()
            print("Payload validated successfully.")
        } catch {
            print("Payload validation failed: \(error)")
            SentrySDK.capture(error: error)
            completion(.failure(error))
            return
        }

        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                print("Invalid session: Not a Cognito tokens provider")
                completion(.failure(NetworkError.invalidSession))
                return
            }

            let tokensResult = try await cognitoSession.getCognitoTokens()
            switch tokensResult {
            case .success(let tokens):
                let accessToken = tokens.accessToken
                print("Successfully fetched Cognito tokens.")
                
                let headers: HTTPHeaders = [
                    .authorization(bearerToken: accessToken),
                    .accept("application/json"),
                    .contentType("application/json")
                ]

                guard let jsonData = try? JSONEncoder().encode(payload) else {
                    print("Failed to encode payload to JSON.")
                    completion(.failure(NetworkError.requestError(NSError(domain: "Invalid JSON payload", code: -1, userInfo: nil))))
                    return
                }

                var request = URLRequest(url: URL(string: urlString)!)
                request.httpMethod = "POST"
                request.headers = headers
                request.httpBody = jsonData

                print("Sending request to \(urlString) with payload.")

                AF.streamRequest(request).responseStream { stream in
                    switch stream.event {
                    case .stream(let result):
                        switch result {
                        case .success(let data):
                            if let content = String(data: data, encoding: .utf8) {
                                print("Streamed response content: \(content)")
                                viewModel.appendResponse(with: content)  // Update view model with chunked response
                            } else {
                                print("Received data, but could not convert to string.")
                            }
                        case .failure(let error):
                            print("Error during streaming: \(error)")
                            SentrySDK.capture(error: error)

                            completion(.failure(error))
                        }
                    case .complete:
                        print("Streaming complete")
                        completion(.success(()))
                    }
                }

            case .failure(let error):
                print("Error fetching tokens: \(error)")
                SentrySDK.capture(error: error)
                completion(.failure(NetworkError.tokenFetchError(error)))
            }
        } catch {
            print("Error during token fetch or request: \(error)")
            SentrySDK.capture(error: error)
            completion(.failure(error))
        }
    }


    
}



struct GraphAbstractRequest: Codable {
    let search_query: String
    let artifact_ids: [String]
    let titles: [String]
    let highlights: [String]
    let system_prompt: String
    let prompt: String
    

    enum CodingKeys: String, CodingKey {
        case search_query = "search_query"
        case artifact_ids = "artifact_ids"
        case titles = "titles"
        case highlights = "highlights"
        case system_prompt = "system_prompt"
        case prompt = "prompt"

    }

    init(search_query: String, artifact_ids: [String], titles: [String], highlights: [String], system_prompt : String, prompt: String) {
        self.search_query = search_query
        self.artifact_ids = artifact_ids
        self.titles = titles
        self.highlights = highlights
        self.system_prompt = system_prompt
        self.prompt = prompt
    }

    // Ensure lists are of the same length
    func validate() throws {
        if artifact_ids.count != titles.count || titles.count != highlights.count {
            throw ValidationError.invalidInput("The lists artifact_ids, titles, and highlights must be of the same length.")
        }
    }
}



enum ValidationError: Error, LocalizedError {
    case invalidInput(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        }
    }
}

enum NetworkError: Error {
    case invalidSession
    case tokenFetchError(Error)
    case requestError(Error)
    case noData
    case unknown
}

struct ArtifactSummary: Codable {
    var artifact_id: String
    var summary: String
}

struct AbstractContent: Codable {
    let content: String
}

extension AuthenticationManager {
    
    func saveGeneratedArtifact(kind: String, indexableText: String, mimeType: String, metadata: [String: Any], completion: @escaping (Result<String, Error>) -> Void) async {
        print("Mansidak saving generated Abstract")
        let urlString = "https://api.recollect.cloud/generated-artifact/save"
        
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formattedDate = dateFormatter.string(from: now)
        
        let payload: [String: Any] = [
            "kind": kind,
            "indexable_text": indexableText,
            "mime_type": mimeType,
            "generated_at": formattedDate,
            "metadata": metadata
        ]
        
        print("Payload being sent: \(payload)") // Print the payload
        
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                print("Invalid session: Not a Cognito tokens provider")
                completion(.failure(NetworkError.invalidSession))
                return
            }

            let tokensResult = try await cognitoSession.getCognitoTokens()
            switch tokensResult {
            case .success(let tokens):
                let accessToken = tokens.accessToken
                let headers: HTTPHeaders = [
                    .authorization(bearerToken: accessToken),
                    .accept("application/json"),
                    .contentType("application/json")
                ]
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
                    print("Failed to serialize payload to JSON.")
                    completion(.failure(NetworkError.requestError(NSError(domain: "Invalid JSON payload", code: -1, userInfo: nil))))
                    return
                }

                var request = URLRequest(url: URL(string: urlString)!)
                request.httpMethod = "POST"
                request.allHTTPHeaderFields = headers.dictionary
                request.httpBody = jsonData
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data, error == nil, let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                        completion(.failure(error ?? NetworkError.unknown))
                        return
                    }
                    
                    if let result = String(data: data, encoding: .utf8) {
                        completion(.success(result))
                    } else {
                        completion(.failure(NetworkError.noData))
                    }
                }.resume()
                
            case .failure(let error):
                print("Error fetching tokens: \(error.localizedDescription)")
                completion(.failure(NetworkError.tokenFetchError(error)))
            }
        } catch {
            print("Error during token fetch or request: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
            completion(.failure(error))
            
        }
    }
}
