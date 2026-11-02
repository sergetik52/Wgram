import Foundation

public struct WgramPlugin: Codable, Equatable {
    public let id: String
    public var name: String
    public var description: String
    public var author: String
    public var version: String
    public var isEnabled: Bool
    public var code: String
    public var createdAt: Double
    
    public init(
        id: String,
        name: String,
        description: String = "",
        author: String = "",
        version: String = "1.0",
        isEnabled: Bool = true,
        code: String,
        createdAt: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.isEnabled = isEnabled
        self.code = code
        self.createdAt = createdAt
    }
}
