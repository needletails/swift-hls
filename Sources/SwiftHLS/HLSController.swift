import Foundation
import Vapor
import HTTPTypes

actor HLSController {
    
    var file: String = ""
    var count: Int = 0
    var maxAge: Int = 0
    var durration: UInt64 = 0
    let store: PlayListStore
    
    init(store: PlayListStore) {
        self.store = store
    }
    
    func lastMSN(_ mp: SimpleMediaPlaylist) -> UInt64 {
        if mp.nextPartIndex == 0 {
            return mp.nextPartIndex - 1
        }
        return mp.nextPartIndex
    }
    
    func lastPart(_ mp: SimpleMediaPlaylist) -> UInt64 {
        if mp.nextPartIndex == 0 {
            return mp.maxPartIndex - 1
        }
        return mp.nextPartIndex - 1
    }
    
    func newFullSegment() -> FullSegment {
        let simpleSegement = SimpleSegment(id: UUID(), uri: "")
        return FullSegment(
            id: UUID(),
            simpleSegment: simpleSegement,
            parts: []
        )
    }
    
    func getMediaPlaylist(playlistName: String) async throws -> SimpleMediaPlaylist {
        guard let list = try await store.findPlaylist(playlistName) else { throw ServerRawErrors.playlistIsNil }
        return list
    }

    func getPlaylistAsyncSequence(_ req: Request, playlistName: String, seqNo: UInt64, partNo: UInt64) async throws -> SimpleMediaPlaylist? {
        let list = try await getMediaPlaylist(playlistName: playlistName)
        
        // There were no _HLS_ parameters
        if seqNo == 0 || lastMSN(list) > seqNo || lastMSN(list) == seqNo && lastPart(list) >= partNo {
            return list
        }
        
        // If a client supplies an _HLS_msn parameter greater than the Media Sequence Number of the last segment in the Playlist plus 2 .. return 400
        if seqNo > lastMSN(list) + 2 {
            throw ServerRawErrors.seqNoError
        }
        // A 3x target duration timeout is recommended for blocking requests, after which the server should return 503.
        if lastMSN(list) > seqNo || (lastMSN(list) == seqNo && lastPart(list) >= partNo) {
            return list
        }
        return nil
    }
    
    func encodeWithSkip(_ until: UInt64, playlist: SimpleMediaPlaylist) async -> String {
        return await encode(until, playlist: playlist)
    }
    
    func encode(_ playlist: SimpleMediaPlaylist) async -> String {
//        return await encode(playlist)
        ""
    }

    
    //TODO: This should actually be a custom encoder in the pipeline maybe...???
    func encode(_ until: UInt64, playlist: SimpleMediaPlaylist) async -> String {
        let totalDurationOfPlaylist = UInt64(playlist.targetDuration.components.seconds) * UInt64(playlist.segments.count)
        var skipDuration: UInt64 = 0
        var skippedSegnents = UInt64(0)
        var version = playlist.version
        if until > 0 {
            skipDuration = totalDurationOfPlaylist - (until + 2) * UInt64(playlist.targetDuration.components.seconds)
            skippedSegnents = skipDuration / UInt64(playlist.targetDuration.components.seconds)
            version = 9
        }
        var out = "#EXTM3U\n"
        out += "#EXT-X-TARGETDURATION:\(playlist.targetDuration.components.seconds)\nf-164"
        out += "#EXT-X-VERSION:\(version)\n"
        out += "#EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES,CAN-SKIP-UNTIL=%1.0f,PART-HOLD-BACK=%1.3f\n\(until * UInt64(playlist.targetDuration.components.seconds))\(3 * UInt64(playlist.partTargetDuration.components.seconds))"
        out += "#EXT-X-PART-INF:PART-TARGET=\(playlist.partTargetDuration.components.seconds)\nf664"
        out += "#EXT-X-MEDIA-SEQUENCE:\(playlist.mediaSequenceNumber)\n"
        if skippedSegnents > 0 {
            out += "#EXT-X-SKIP:SKIPPED-SEGMENTS=\(skippedSegnents)\n"
        }
        
        var durrationSkipped: UInt64 = 0
        
        for fullSeg in playlist.segments {
            if durrationSkipped < skipDuration {
                durrationSkipped += UInt64(playlist.targetDuration.components.seconds)
                continue
            }
            
            for eLine in fullSeg.simpleSegment.extraLines ?? [] {
                if eLine == "" { continue }
                out += "\(eLine)\n"
            }
            
            if fullSeg.parts.count > 0 {
                for partSeg in fullSeg.parts {
                    let fileExt = partSeg.uri
                    if partSeg.independent == true {
                        out += "#EXT-X-PART:DURATION=\(partSeg.duration ?? 0.0),INDEPENDENT=YES,URI=\"\(Constants.segmentEndPoint)\(fileExt ?? "")?segment=\(partSeg.uri ?? "")\"\n"
                    } else {
                        out += "#EXT-X-PART:DURATION=\(partSeg.duration ?? 0.0),URI=\"\(Constants.segmentEndPoint)\(fileExt ?? "")?segment=\(partSeg.uri ?? "")\"\n"
                    }
                }
            }
            if fullSeg.simpleSegment.uri != "" {
                out += "#EXTINF:\(fullSeg.simpleSegment.duration ?? 0.0),\n"
                out += "\(fullSeg.simpleSegment.uri ?? "")\n"
            }
        }
        
        if playlist.preloadHints != [:] {
            for hint in playlist.preloadHints {
                let fileExt = hint.value
                out += "#EXT-X-PRELOAD-HINT:TYPE=\(hint.key),URI=\"\(Constants.segmentEndPoint)\(fileExt)?segment=\(hint.value)\"\n"
            }
        }
        return out
    }
    
    //TODO: This should actually be a custom decode in the pipeline
    func decode(_ playlist: SimpleMediaPlaylist) async throws  {
        
    }
    

    func handle(_ req: Request) async throws -> Response {
    
        let path = req.url.path
        //TODO: applicationSupportDir is different on linux
        guard var applicationSupportDir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            fatalError("Couldn't access application support directory")
        }
        
        if path.hasPrefix(Constants.playListEndPoint.rawValue) {
            
            let seqParam: String? = req.query[Constants.seqParamQName.rawValue]
            let partParam: String? = req.query[Constants.partParamQName.rawValue]
            let skipParam: Bool? = req.query[Constants.skipParamQName.rawValue]
            let path = path.deletingPrefix("/")
            //TODO: This should be a playlist name not a file path
            let file = applicationSupportDir.appendingPathComponent("\(path)/\(Constants.index)")
            var content = ""

            if seqParam?.isEmpty == false {
                guard let seqParam = seqParam else { throw ResponseErrors.throwError(.badRequest) }
                guard let partParam = partParam else { throw ResponseErrors.throwError(.badRequest) }
                guard let seqNo = UInt64(seqParam) else { throw ResponseErrors.throwError(.badRequest) }
                guard let partNo = UInt64(partParam) else { throw ResponseErrors.throwError(.badRequest) }
                do {
                    let currentMediaPlaylist = try await getPlaylistAsyncSequence(req, playlistName: file.absoluteString, seqNo: seqNo, partNo: partNo)
                    if skipParam == true {
                        content = await encodeWithSkip(
                            MutableConstants.canSkipUntil,
                            playlist: currentMediaPlaylist!
                        )
                    } else {
                        content = await encode(currentMediaPlaylist!)
                    }
                    content += "#\n"
                    _ = try await encodeResponseWrapper(req, file: "file.m3u8", count: content.count, maxAge: maxAge, duration: 0)
                    
                } catch {
                    throw ResponseErrors.throwError(.badRequest)
                }
            }

        } else {
            
            applicationSupportDir = URL(string: String(path.trimmingPrefix(while: { $0 == "/" })))!
            maxAge = 300
            
            if path.contains("/\(Constants.segmentEndPoint).") {
                //TODO: This should be a playlist name not a file path
                var indexFile = applicationSupportDir.path.trimmingPrefix(while: { $0 == "/" }) + "/\(Constants.index)"
                guard let segURI: String? = req.query["segment"] else { throw ResponseErrors.throwError(.badRequest) }
                do {
                    let currentMediaPlaylist = try await getPlaylistAsyncSequence(req, playlistName: String(indexFile), seqNo: 0, partNo: 0)
                    indexFile = applicationSupportDir.path.trimmingPrefix(while: { $0 == "/" }) + "/\(segURI ?? "")"
                    var segmentReady = false
                    
                    for try segment in currentMediaPlaylist!.segments {
                        for partial in segment.parts {
                            if partial.uri == segURI {
                                segmentReady = true
                                break
                            }
                        }
                    }
                    
                    maxAge = 6
                    
                    if !segmentReady {
                        var nextSeqNo = lastMSN(currentMediaPlaylist!)
                        var nextPartNo = lastPart(currentMediaPlaylist!)
                        if nextPartNo == currentMediaPlaylist!.maxPartIndex {
                            nextPartNo = 0
                            nextSeqNo += 1
                        } else {
                            nextPartNo += 1
                        }
                        
                        do {
                            _ = try await getPlaylistAsyncSequence(req, playlistName: String(indexFile), seqNo: nextSeqNo, partNo: nextPartNo)
                        } catch {
                           throw ResponseErrors.throwError(.badRequest)
                        }
                    }
                        
                        
                } catch {
                    throw ResponseErrors.throwError(.badRequest)
                }

            }
            do {
                _ = try await encodeResponseWrapper(req, file: file, count: -1, maxAge: maxAge, duration: durration)
            } catch {
               throw ResponseErrors.throwError(.badRequest)
            }
            
        }
        
        return Response(status: .ok)
    }
}



extension HLSController: AsyncResponseEncodable {
    
    
    
    func encodeResponseWrapper(_
                               req: Request,
                               file: String,
                               count: Int,
                               maxAge: Int,
                               duration: UInt64
    ) async throws -> Response {
        self.file = file
        self.count = count
        self.maxAge = maxAge
        self.durration = duration
        return try await encodeResponse(for: req)
    }
    
  public func encodeResponse(for request: Request) async throws -> Response {
    var headers = HTTPHeaders()
      if file.hasSuffix("mp4") {
          headers.add(name: .contentType, value: "video/mp4")
      } else if file.hasSuffix(".ts") {
          headers.add(name: .contentType, value: "video/mp2t")
      } else if file.hasSuffix(".m3u8") {
          headers.add(name: .contentType, value: "application/vnd.apple.mpegurl")
      }
      headers.add(name: .cacheControl, value: "max-age=\(maxAge)")
      if count != -1 {
          headers.add(name: .contentLength, value: "\(count)")
      }
      headers.add(name: .server, value: Constants.serverVersionString.rawValue)
      headers.add(name: "block-duration", value: "\(durration)")
      headers.add(name: .accessControlAllowOrigin, value: "*")
      headers.add(name: .accessControlExpose, value: "age")
      headers.add(name: .accessControlAllowOrigin, value: "Range")
    return .init(status: .ok, headers: headers, body: .init(string: ""))
  }
}

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}

enum ResponseErrors: Error, Sendable {
    case throwError(HTTPResponse.Status)
}

enum ServerRawErrors: String, Error, Sendable {
    case userIsNil
    case projectIsNil
    case playlistIsNil
    case seqNoError = "400 seqNo requested too far in future"
}
