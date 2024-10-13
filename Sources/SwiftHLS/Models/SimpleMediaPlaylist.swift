//
//  SimpleMediaPlaylist.swift
//  swift-hls
//
//  Created by Cole M on 10/13/24.
//

import Foundation

struct SimpleMediaPlaylist: Codable, Sendable {
    
    var _id: String
    var name: String
    /// #EXT-X-TARGETDURATION:4
    var targetDuration: Duration
    /// #EXT-X-VERSION:3
    var version: UInt64
    /// #EXT-X-PART-INF:PART-TARGET=1.004000
    var partTargetDuration: Duration
    /// #EXT-X-MEDIA-SEQUENCE:339
    var mediaSequenceNumber: UInt64
    /// The segment list of the mediaplaylist
    var segments: [FullSegment]
    /// The index to be used for the next full segment/
    var nextMSNIndex: UInt64
    /// The index to be used for the next partial segment
    var nextPartIndex: UInt64
    /// To determine when to "roll over" on the NextPartIndex
    var maxPartIndex: UInt64
    /// A map[<TYPE>]URI
    var preloadHints:  [String: String]
    
    init(
        id: UUID,
        name: String,
        targetDuration: Duration,
        version: UInt64,
        partTargetDuration: Duration,
        mediaSequenceNumber: UInt64,
        segments: [FullSegment],
        nextMSNIndex: UInt64,
        nextPartIndex: UInt64,
        maxPartIndex: UInt64,
        preloadHints: [String : String]
    ) {
        self._id = id.uuidString
        self.name = name
        self.targetDuration = targetDuration
        self.version = version
        self.partTargetDuration = partTargetDuration
        self.mediaSequenceNumber = mediaSequenceNumber
        self.segments = segments
        self.nextMSNIndex = nextMSNIndex
        self.nextPartIndex = nextPartIndex
        self.maxPartIndex = maxPartIndex
        self.preloadHints = preloadHints
    }
    
}
