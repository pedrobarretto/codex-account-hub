import CodexAuthCore
import Foundation

struct ProfileDraft: Equatable {
    var id: UUID?
    var displayName: String
    var notes: String
    var authJSONString: String

    static let empty = ProfileDraft(id: nil, displayName: "", notes: "", authJSONString: "{\n  \"auth_mode\": \"\"\n}")
}

enum DraftValidation: Equatable {
    case valid(AuthPayload)
    case invalid(String)

    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }

    var message: String {
        switch self {
        case .valid(let payload):
            let mode = payload.authMode ?? "unknown"
            return "Valid auth object. auth_mode: \(mode)"
        case .invalid(let reason):
            return reason
        }
    }
}

enum BannerKind {
    case info
    case success
    case warning
    case error
}

struct BannerMessage: Identifiable, Equatable {
    let id = UUID()
    let kind: BannerKind
    let text: String
}
