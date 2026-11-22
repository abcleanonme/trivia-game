import Foundation
import Testing
@testable import TriviaKit

@Suite struct SoundTests {
    @Test func everySoundCosmeticHasAPack() {
        let cosmetics = Set(CosmeticCatalog.items(in: .sounds).map(\.id))
        let packs = Set(SoundCatalog.all.map(\.id))
        #expect(cosmetics == packs)
        #expect(cosmetics.contains(SoundCatalog.defaultID))
        #expect(CosmeticCatalog.item(SoundCatalog.defaultID)?.unlock == .starter)
        for item in CosmeticCatalog.items(in: .sounds) where item.unlock != .starter {
            #expect((250...450).contains(item.price ?? 0), "\(item.id)")
        }
    }

    @Test func everyCueRendersShortAndInRange() {
        for pack in SoundCatalog.all {
            for cue in SoundCue.allCases {
                let samples = pack.render(cue, sampleRate: 8_000)
                let peak = samples.map { abs($0) }.max() ?? 0
                #expect(peak > 0.05, "\(pack.id) \(cue) is silent")
                #expect(peak <= 1)
                #expect(pack.duration(of: cue) <= 1.5, "\(pack.id) \(cue) too long")
                // Ends quietly, so nothing clicks.
                #expect(abs(samples.last ?? 1) < 0.05, "\(pack.id) \(cue) clicks")
            }
        }
    }

    @Test func packsSoundDifferent() {
        let renders = SoundCatalog.all.map { $0.render(.correct, sampleRate: 8_000) }
        #expect(Set(renders.map { $0.prefix(400).map { Int($0 * 100) } }).count == renders.count)
    }

    @Test func renderingIsDeterministic() {
        let pack = SoundCatalog.pack("sound.arcade")
        #expect(pack.render(.tick) == pack.render(.tick))
    }

    @Test func unknownPackFallsBackToDefault() {
        #expect(SoundCatalog.pack("sound.gone").id == SoundCatalog.defaultID)
    }

    @Test func soundPacksBuyAndEquip() throws {
        var wallet = Wallet(sparks: 300)
        var inv = Inventory()
        #expect(inv.equipped(.sounds).id == SoundCatalog.defaultID)
        #expect(!inv.buy("sound.cosmic", with: &wallet)) // 450
        #expect(inv.buy("sound.marimba", with: &wallet))
        inv.equip("sound.marimba")
        #expect(inv.equipped(.sounds).id == "sound.marimba")
        #expect(wallet.sparks == 50)

        // A save from before sound packs existed.
        let old = Data(#"{"owned":["avatar.monogram"],"equipped":{"theme":"theme.classic"}}"#.utf8)
        let saved = try JSONDecoder().decode(Inventory.self, from: old)
        #expect(saved.equipped(.sounds).id == SoundCatalog.defaultID)
        #expect(saved.owns(SoundCatalog.defaultID))
    }
}
