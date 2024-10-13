//
//  SimpleSegment.swift
//  swift-hls
//
//  Created by Cole M on 10/13/24.
//

import Foundation

/// SimpleSegment is a struct that represents a HLS Segment
struct SimpleSegment: Codable, Sendable {
    
    var _id: String
    /// #EXTINF:3.96667,
    var duration: Float64?
    /// fileSequence5.ts
    var uri: String?
    /// #EXT-X-PROGRAM-DATE-TIME:2019-11-08T22:41:10.072Z and many more
    var extraLines: [String]?
    /// INDEPENDENT=YES
    var independent: Bool?
    
    init(
        id: UUID,
        duration: Float64? = nil,
        uri: String? = nil,
        extraLines: [String]? = nil,
        independent: Bool? = nil
    ) {
        self._id = id.uuidString
        self.duration = duration
        self.uri = uri
        self.extraLines = extraLines
        self.independent = independent
    }
}
