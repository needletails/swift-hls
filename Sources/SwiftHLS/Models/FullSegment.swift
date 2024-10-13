//
//  FullSegment.swift
//  swift-hls
//
//  Created by Cole M on 10/13/24.
//

import Foundation

/// FullSegment is a segment with a set of children
struct FullSegment: Codable, Sendable {
    
    var _id: String
    /// This contains the information for the full segment (if complete)
    var simpleSegment: SimpleSegment
    /// An array of part segments that this full is made up off
    var parts: [SimpleSegment]
    
    init(
        id: UUID,
        simpleSegment: SimpleSegment,
        parts: [SimpleSegment]
    ) {
        self._id = id.uuidString
        self.simpleSegment = simpleSegment
        self.parts = parts
    }
}
