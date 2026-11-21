import AVFoundation
import SwiftUI
import TriviaKit

/// Plays the equipped sound pack's effects. Every sound is synthesized on
/// the phone from `SoundCatalog` (no audio files), rendered once per pack
/// and cached.
///
/// Uses the ambient audio session: sounds mix with the player's music or
/// podcast, and the ring/silent switch mutes them. The Settings "Sound
/// effects" toggle turns them off entirely.
@MainActor
final class SoundEffects {
    static let shared = SoundEffects()

    /// The pack in use. `PlayerStore` points this at the equipped pack.
    private(set) var packID = SoundCatalog.defaultID

    private let engine = AVAudioEngine()
    /// A few voices so a tick and a "correct" can overlap.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false
    private var failed = false

    private init() {
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                               queue: .main) { [weak self] _ in
            // Headphones in or out: the engine stops and must restart.
            MainActor.assumeIsolated { self?.started = false }
        }
    }

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingKey.sound) as? Bool ?? true
    }

    func use(_ id: String) {
        guard id != packID else { return }
        packID = id
        // Keep only the new pack's sounds in memory.
        buffers = buffers.filter { $0.key.hasPrefix(id + "/") }
    }

    /// Plays a cue in the equipped pack, unless sound is off.
    func play(_ cue: SoundCue) {
        guard Self.enabled else { return }
        play(cue, pack: packID)
    }

    /// Plays a cue in any pack, for shop previews. Respects the Sound
    /// toggle only through the silent switch: the player asked to hear it.
    func preview(_ cue: SoundCue, pack id: String) {
        play(cue, pack: id)
    }

    private func play(_ cue: SoundCue, pack id: String) {
        guard startIfNeeded(), let buffer = buffer(for: cue, pack: id) else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    private func buffer(for cue: SoundCue, pack id: String) -> AVAudioPCMBuffer? {
        let key = "\(id)/\(cue.rawValue)"
        if let cached = buffers[key] { return cached }
        let samples = SoundCatalog.pack(id).render(cue, sampleRate: format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        buffers[key] = buffer
        return buffer
    }

    /// Starts the engine on first use. Returns false if audio isn't available.
    private func startIfNeeded() -> Bool {
        if started && engine.isRunning { return true }
        guard !failed else { return false }
        do {
            if players.isEmpty {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                for _ in 0..<4 {
                    let player = AVAudioPlayerNode()
                    engine.attach(player)
                    engine.connect(player, to: engine.mainMixerNode, format: format)
                    players.append(player)
                }
            }
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            started = true
            return true
        } catch {
            // No audio (rare): play silently rather than retrying every tap.
            failed = true
            return false
        }
    }
}

extension View {
    /// Plays `cue` whenever `value` changes and `when` says so.
    func soundEffect<V: Equatable>(_ cue: SoundCue, trigger value: V,
                                   when condition: @escaping (V, V) -> Bool = { _, _ in true }) -> some View {
        onChange(of: value) { old, new in
            if condition(old, new) { SoundEffects.shared.play(cue) }
        }
    }
}
