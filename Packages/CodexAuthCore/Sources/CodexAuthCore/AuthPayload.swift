import Foundation

public struct AuthPayload: Equatable {
    public let rawData: Data
    public let canonicalData: Data
    private let rootObject: [String: Any]

    public init(data: Data) throws {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CodexAuthCoreError.invalidJSON
        }

        guard let object = jsonObject as? [String: Any] else {
            throw CodexAuthCoreError.unsupportedRoot
        }

        do {
            self.canonicalData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        } catch {
            throw CodexAuthCoreError.invalidJSON
        }

        self.rawData = data
        self.rootObject = object
    }

    public init(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw CodexAuthCoreError.invalidJSON
        }
        try self.init(data: data)
    }

    public var authMode: String? {
        rootObject["auth_mode"] as? String
    }

    public var apiKey: String? {
        rootObject["OPENAI_API_KEY"] as? String
    }

    public var lastRefresh: String? {
        rootObject["last_refresh"] as? String
    }

    public var hasTokensObject: Bool {
        rootObject["tokens"] is [String: Any]
    }

    public func prettyPrintedString() throws -> String {
        let formattedData = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
        guard let string = String(data: formattedData, encoding: .utf8) else {
            throw CodexAuthCoreError.invalidJSON
        }
        return string
    }

    public static func == (lhs: AuthPayload, rhs: AuthPayload) -> Bool {
        lhs.canonicalData == rhs.canonicalData
    }
}
