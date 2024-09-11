import Foundation

struct Document: Codable, Identifiable {
    var id = UUID()
    let doc_id: String
    let title: String
    let url: String?
    var sentences: [Sentence]? = []
    var tweets: [Tweet]?
    let doc_type: String
    let doc_subtype: String?
    var shouldBeDisplayed: Bool = true
    var is_screenshot: Bool? // Adds a condition to check for screenshot types
    var thumbnail_s3_path: String? // Path to the image if it's a screenshot

    enum CodingKeys: String, CodingKey {
        case doc_id, title, sentences, url, tweets, doc_type, doc_subtype, is_screenshot, thumbnail_s3_path
    }
}

struct Sentence: Codable {
    let text: String
    let paragraph_number: Int
}



struct Tweet: Codable {
    var sentences: [Sentence]
    let display_name: String
    let user_name : String

}


struct JsonResponse: Codable {
    let results: [Document]
    let stack_id: String 
    
}



struct Note: Codable {
    let id: String
    let title: String
    let body: String
    let createdDate: String
    let modifiedDate: String

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }
}
struct RecurringImportResponse: Codable {
    let count: Int
    let items: [RecurringImportItem]
}

struct RecurringImportItem: Codable {
    let id: String
    let settings: RecurringImportSettings
}

struct RecurringImportSettings: Codable {
    let enabled: Bool
    let account_id: String? // Make this field optional
}

struct RecurringImportCreationResponse: Codable {
    var id: String
    var settings: RecurringImportSettings
}
struct RecurringImportBody: Codable {
    var enabled: Bool
}
// Update your SyncNotesRequest to include the `recurringImportID`
struct SyncNotesRequest: Codable {
    let notes: [Note]
    let recurringImportID: String
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case notes
        case recurringImportID = "recurring_import_id"
        case source
    }
}



struct SyncNotesResponse: Codable {
    let ignoredChanges: [IgnoredChange]

    struct IgnoredChange: Codable {
        let id: String
        let reason: String
    }
}

struct PeeledCard {
    var title: String
    var content: String
    var url: String?
    var docId: String
    var isScreenshot: Bool
    var thumbnailPath: String?
    var window: FlatWindow? // Optional reference to the associated window
}

struct AbstractCard {
    var window: FlatWindow
    var titles: [String]
    var docIds: [String]
    var bodies: [String]
}


