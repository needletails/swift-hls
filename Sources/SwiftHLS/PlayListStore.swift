//
//  Repository.swift
//  swift-hls
//
//  Created by Cole M on 10/13/24.
//
import Vapor

enum CreatePlaylistResult: Sendable, Equatable {
    case success, fail(Error), playlistExist(String)
    
    static func == (lhs: CreatePlaylistResult, rhs: CreatePlaylistResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            return true
        case (let .fail(lhsError), let .fail(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (let .playlistExist(lhsString), let .playlistExist(rhsString)):
            return lhsString == rhsString
        default:
            return false
        }
    }
}

//CRUD Methods Protocol
protocol PlayListStore: Sendable {
    func findPlaylists() async throws -> [SimpleMediaPlaylist]?
    func findPlaylist(_ name: String) async throws -> SimpleMediaPlaylist?
    func createPlaylist(_ playlist: SimpleMediaPlaylist) async -> CreatePlaylistResult
    func updatePlaylist(_ name: String, update project: SimpleMediaPlaylist) async throws
    func deletePlaylist(_ name: String) async throws
}
