//
//  Constants.swift
//  swift-hls
//
//  Created by Cole M on 10/13/24.
//


@globalActor actor HLSActor {
    static let shared = HLSActor()
}

enum Constants: String, Sendable {
    case index = "prog_index.m3u8"
    case playListEndPoint = "lowLatencyHLS.m3u8"
    case segmentEndPoint = "lowLatencySeg"
    case serverVersionString = "ll-hls/swift/0.1"
    case seqParamQName = "_HLS_msn"
    case partParamQName = "_HLS_part"
    case skipParamQName = "_HLS_skip"
    
}

@HLSActor
struct MutableConstants: Sendable {
    static let canSkipUntil = UInt64(6)
    static var httpAddr = ["http", ":8443", "Listen address"]
    static var dir = ["dir", "", "Root dir with hls files"]
    static var certDir = ["certdir", "", "Dir with server.crt, and server.key files"]
}
