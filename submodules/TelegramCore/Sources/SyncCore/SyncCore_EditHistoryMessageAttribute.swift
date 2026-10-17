import Foundation
import Postbox

public struct EditHistoryVersion: PostboxCoding, Equatable {
    public let text: String
    public let timestamp: Int32

    public init(text: String, timestamp: Int32) {
        self.text = text
        self.timestamp = timestamp
    }

    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.timestamp = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeInt32(self.timestamp, forKey: "d")
    }
}

public class EditHistoryMessageAttribute: MessageAttribute {
    public let versions: [EditHistoryVersion]

    public init(versions: [EditHistoryVersion]) {
        self.versions = versions
    }

    required public init(decoder: PostboxDecoder) {
        self.versions = decoder.decodeObjectArrayWithDecoderForKey("v")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.versions, forKey: "v")
    }
}

public extension Message {
    var editHistoryVersions: [EditHistoryVersion] {
        for attribute in self.attributes {
            if let editHistory = attribute as? EditHistoryMessageAttribute {
                return editHistory.versions
            }
        }
        return []
    }
}
