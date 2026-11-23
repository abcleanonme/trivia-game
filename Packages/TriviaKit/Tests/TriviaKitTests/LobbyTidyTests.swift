import Foundation
import Testing
@testable import TriviaKit

@Suite struct LobbyTidyTests {
    @Test func hidingAFriendCanBeUndone() {
        var tidy = LobbyTidy()
        tidy.hide("alex")
        #expect(tidy.isHidden("alex"))
        #expect(!tidy.isHidden("sam"))
        tidy.unhide("alex")
        #expect(!tidy.isHidden("alex"))
    }

    @Test func archiveKeepsOrderAndSkipsDuplicates() {
        var tidy = LobbyTidy()
        tidy.archive(["a", "b"])
        tidy.archive(["b", "c"])
        #expect(tidy.archived == ["a", "b", "c"])
        tidy.unarchive("b")
        #expect(tidy.archived == ["a", "c"])
        #expect(!tidy.isArchived("b"))
    }

    @Test func archiveDropsTheOldestPastTheLimit() {
        var tidy = LobbyTidy()
        tidy.archive((0..<(LobbyTidy.archiveLimit + 5)).map(String.init))
        #expect(tidy.archived.count == LobbyTidy.archiveLimit)
        #expect(tidy.archived.first == "5")
        #expect(!tidy.isArchived("0"))
    }

    @Test func forgetRemovesClearedMatches() {
        var tidy = LobbyTidy(archived: ["a", "b", "c"])
        tidy.forget(["a", "c", "zzz"])
        #expect(tidy.archived == ["b"])
    }

    @Test func staleAfterAWeek() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(!LobbyTidy.isStale(updated: now.addingTimeInterval(-6 * 86_400), now: now))
        #expect(LobbyTidy.isStale(updated: now.addingTimeInterval(-7 * 86_400), now: now))
    }

    @Test func roundTripsThroughJSON() throws {
        var tidy = LobbyTidy()
        tidy.hide("alex")
        tidy.archive(["m1"])
        let data = try JSONEncoder().encode(tidy)
        #expect(try JSONDecoder().decode(LobbyTidy.self, from: data) == tidy)
    }
}
