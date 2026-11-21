import Foundation

/// Moments in the game that make a sound.
public enum SoundCue: String, CaseIterable, Sendable {
    case correct, wrong
    /// A correct answer that keeps a streak of three or more going.
    case streak
    /// The clock ran out.
    case timeUp
    /// Each of the last few seconds on the clock.
    case tick
    case powerUp
    /// Round over: the score screen.
    case roundEnd
    /// Sparks spent in a shop.
    case purchase

    public var title: String {
        switch self {
        case .correct: "Correct"
        case .wrong: "Wrong"
        case .streak: "Streak"
        case .timeUp: "Time's up"
        case .tick: "Clock"
        case .powerUp: "Power-up"
        case .roundEnd: "Round end"
        case .purchase: "Purchase"
        }
    }
}

/// One synthesized note. Every sound in the game is built from these at
/// runtime, so there are no audio files and nothing licensed.
public struct Tone: Equatable, Sendable {
    public enum Wave: Sendable { case sine, triangle, square, saw, noise }

    /// Seconds from the start of the sound.
    public var start: Double
    public var duration: Double
    /// Hz at the start; glides to `glideTo` if set.
    public var frequency: Double
    public var glideTo: Double?
    public var wave: Wave
    /// 0...1 before the pack's master volume.
    public var volume: Double
    /// Seconds to fade in. The rest of the note decays.
    public var attack: Double
    /// How fast the note dies away: higher is plucky, 0 is a flat hold.
    public var decay: Double
    /// Mixes in an octave-and-a-fifth overtone (0...1) for bell or wood colors.
    public var overtone: Double
    /// Vibrato depth in semitones (6 Hz).
    public var vibrato: Double

    public init(_ start: Double, _ duration: Double, _ frequency: Double, glideTo: Double? = nil,
                wave: Wave = .sine, volume: Double = 0.8, attack: Double = 0.005, decay: Double = 6,
                overtone: Double = 0, vibrato: Double = 0) {
        self.start = start
        self.duration = duration
        self.frequency = frequency
        self.glideTo = glideTo
        self.wave = wave
        self.volume = volume
        self.attack = attack
        self.decay = decay
        self.overtone = overtone
        self.vibrato = vibrato
    }
}

/// A sound-effect theme: the same cues voiced a different way. Sold for
/// Sparks in the Style shop like app themes. Ids match `CosmeticCatalog`.
public struct SoundPack: Identifiable, Sendable {
    /// How a pack voices its notes.
    public struct Voice: Sendable {
        var wave: Tone.Wave = .sine
        var decay: Double = 6
        var overtone: Double = 0
        var attack: Double = 0.005
        var vibrato: Double = 0
        /// Multiplies every frequency (2 = an octave up).
        var octave: Double = 1
    }

    public let id: String
    let voice: Voice
    /// Pack-specific notes for a cue, when the generic recipe won't do.
    let custom: @Sendable (SoundCue) -> [Tone]?
    /// Master volume, so packs sound about equally loud.
    public let gain: Double

    public func tones(for cue: SoundCue) -> [Tone] {
        custom(cue) ?? generic(cue)
    }

    /// Length in seconds, including the tail.
    public func duration(of cue: SoundCue) -> Double {
        tones(for: cue).map { $0.start + $0.duration }.max() ?? 0
    }

    /// Mono samples in -1...1.
    public func render(_ cue: SoundCue, sampleRate: Double = 44_100) -> [Float] {
        Synth.render(tones(for: cue), gain: gain, sampleRate: sampleRate)
    }

    /// Notes of the cue in this pack's voice: the same melodies in every
    /// pack, so each cue stays recognizable whatever pack is on.
    private func generic(_ cue: SoundCue) -> [Tone] {
        func n(_ t: Double, _ d: Double, _ f: Double, _ v: Double = 0.8, glide: Double? = nil) -> Tone {
            Tone(t, d, f * voice.octave, glideTo: glide.map { $0 * voice.octave }, wave: voice.wave, volume: v,
                 attack: voice.attack, decay: voice.decay, overtone: voice.overtone, vibrato: voice.vibrato)
        }
        switch cue {
        case .correct: // Rising major third: "ding-ding".
            return [n(0, 0.25, Note.e5), n(0.08, 0.4, Note.gs5)]
        case .wrong: // Two low falling notes.
            return [n(0, 0.2, Note.ds4, 0.7), n(0.12, 0.35, Note.a3, 0.7)]
        case .streak: // Quick major arpeggio.
            return [n(0, 0.2, Note.c5), n(0.06, 0.2, Note.e5), n(0.12, 0.2, Note.g5), n(0.18, 0.45, Note.c6)]
        case .timeUp:
            return [n(0, 0.18, Note.g4, 0.7), n(0.16, 0.18, Note.e4, 0.7), n(0.32, 0.4, Note.c4, 0.7)]
        case .tick:
            return [n(0, 0.07, Note.a5, 0.35)]
        case .powerUp: // Upward sweep.
            return [n(0, 0.3, Note.c5, 0.6, glide: Note.c6), n(0.12, 0.3, Note.g5, 0.4)]
        case .roundEnd: // Little fanfare.
            return [n(0, 0.18, Note.g4), n(0.15, 0.18, Note.c5), n(0.3, 0.18, Note.e5),
                    n(0.45, 0.7, Note.g5), n(0.45, 0.7, Note.c5, 0.5)]
        case .purchase: // Coin.
            return [n(0, 0.08, Note.b5, 0.6), n(0.07, 0.4, Note.e6, 0.6)]
        }
    }
}

/// Note frequencies (equal temperament, A4 = 440).
enum Note {
    static let a3 = 220.0, c4 = 261.63, ds4 = 311.13, e4 = 329.63, g4 = 392.0
    static let a4 = 440.0, c5 = 523.25, e5 = 659.25, g5 = 783.99, gs5 = 830.61
    static let a5 = 880.0, b5 = 987.77, c6 = 1046.5, e6 = 1318.51
}

public enum SoundCatalog {
    public static let defaultID = "sound.classic"

    public static func pack(_ id: String) -> SoundPack { byID[id] ?? byID[defaultID]! }

    public static let all: [SoundPack] = [
        // Soft sine chimes: the free default.
        SoundPack(id: "sound.classic", voice: .init(wave: .sine, decay: 7, overtone: 0.15),
                  custom: { _ in nil }, gain: 0.55),
        // Wooden mallets: plucky, with a woody overtone.
        SoundPack(id: "sound.marimba", voice: .init(wave: .sine, decay: 14, overtone: 0.5),
                  custom: { _ in nil }, gain: 0.6),
        // Tiny bright bells an octave up.
        SoundPack(id: "sound.musicbox", voice: .init(wave: .triangle, decay: 5, overtone: 0.35, octave: 2),
                  custom: { _ in nil }, gain: 0.45),
        // 8-bit square waves.
        SoundPack(id: "sound.arcade", voice: .init(wave: .square, decay: 3, attack: 0.001),
                  custom: arcade, gain: 0.22),
        // Boings and slide whistles.
        SoundPack(id: "sound.cartoon", voice: .init(wave: .sine, decay: 2, vibrato: 0.3),
                  custom: cartoon, gain: 0.55),
        // Wobbly synth sweeps.
        SoundPack(id: "sound.cosmic", voice: .init(wave: .saw, decay: 3, attack: 0.03, vibrato: 0.15),
                  custom: cosmic, gain: 0.2),
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    private static let arcade: @Sendable (SoundCue) -> [Tone]? = { cue in
        func sq(_ t: Double, _ d: Double, _ f: Double, _ v: Double = 0.8, glide: Double? = nil) -> Tone {
            Tone(t, d, f, glideTo: glide, wave: .square, volume: v, attack: 0.001, decay: 2)
        }
        switch cue {
        case .wrong: // Buzzer.
            return [sq(0, 0.35, 140, glide: 90), Tone(0, 0.35, 70, wave: .saw, volume: 0.5, decay: 2)]
        case .timeUp:
            return [sq(0, 0.6, 400, glide: 60)]
        case .powerUp:
            return (0..<6).map { sq(Double($0) * 0.045, 0.06, 400 * pow(1.25, Double($0)), 0.6) }
        case .tick:
            return [Tone(0, 0.04, 1200, wave: .noise, volume: 0.4, decay: 30)]
        case .purchase:
            return [sq(0, 0.07, Note.b5), sq(0.07, 0.3, Note.e6)]
        default: return nil
        }
    }

    private static let cartoon: @Sendable (SoundCue) -> [Tone]? = { cue in
        func whistle(_ t: Double, _ d: Double, _ from: Double, _ to: Double, _ v: Double = 0.8) -> Tone {
            Tone(t, d, from, glideTo: to, wave: .sine, volume: v, attack: 0.02, decay: 1.5, vibrato: 0.4)
        }
        switch cue {
        case .correct:
            return [whistle(0, 0.35, 500, 1100)]
        case .wrong: // Sad trombone-ish slide.
            return [Tone(0, 0.6, 300, glideTo: 180, wave: .triangle, volume: 0.8, attack: 0.03, decay: 1.5, vibrato: 0.6)]
        case .streak:
            return [whistle(0, 0.25, 500, 900), whistle(0.2, 0.35, 700, 1400)]
        case .timeUp: // Boing.
            return [Tone(0, 0.5, 120, glideTo: 380, wave: .sine, volume: 0.9, decay: 4, vibrato: 1.5)]
        case .tick: // Wood block.
            return [Tone(0, 0.06, 900, wave: .sine, volume: 0.5, decay: 40, overtone: 0.6)]
        case .powerUp:
            return [whistle(0, 0.45, 300, 1500)]
        default: return nil
        }
    }

    private static let cosmic: @Sendable (SoundCue) -> [Tone]? = { cue in
        func pad(_ t: Double, _ d: Double, _ f: Double, _ v: Double = 0.8, glide: Double? = nil) -> Tone {
            Tone(t, d, f, glideTo: glide, wave: .saw, volume: v, attack: 0.03, decay: 3, vibrato: 0.15)
        }
        switch cue {
        case .correct:
            return [pad(0, 0.4, Note.e5, glide: Note.gs5 * 2), Tone(0, 0.4, Note.gs5, wave: .sine, volume: 0.6, decay: 4)]
        case .wrong:
            return [pad(0, 0.5, 220, glide: 110)]
        case .powerUp: // Laser.
            return [pad(0, 0.35, 1800, glide: 300)]
        case .tick:
            return [Tone(0, 0.08, 2000, glideTo: 1500, wave: .sine, volume: 0.35, decay: 25)]
        default: return nil
        }
    }
}

/// Turns tones into samples. Pure and deterministic (noise uses a fixed
/// seed), so it can be unit tested.
enum Synth {
    static func render(_ tones: [Tone], gain: Double, sampleRate: Double) -> [Float] {
        let length = tones.map { $0.start + $0.duration }.max() ?? 0
        var out = [Double](repeating: 0, count: Int(length * sampleRate) + 1)
        var seed: UInt32 = 0x2545F491
        for tone in tones {
            let first = Int(tone.start * sampleRate)
            let count = Int(tone.duration * sampleRate)
            var phase = 0.0, phase2 = 0.0
            for i in 0..<count where first + i < out.count {
                let t = Double(i) / sampleRate
                let progress = Double(i) / Double(max(count, 1))
                var f = tone.frequency
                if let end = tone.glideTo { f *= pow(end / tone.frequency, progress) }
                if tone.vibrato > 0 { f *= pow(2, tone.vibrato * sin(2 * .pi * 6 * t) / 12) }
                phase = (phase + f / sampleRate).truncatingRemainder(dividingBy: 1)
                phase2 = (phase2 + 3 * f / sampleRate).truncatingRemainder(dividingBy: 1)
                let s: Double
                switch tone.wave {
                case .sine: s = sin(2 * .pi * phase)
                case .triangle: s = 1 - 4 * abs(phase - 0.5)
                case .square: s = phase < 0.5 ? 1 : -1
                case .saw: s = 2 * phase - 1
                case .noise:
                    seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
                    s = Double(seed) / Double(UInt32.max) * 2 - 1
                }
                let over = tone.overtone > 0 ? tone.overtone * sin(2 * .pi * phase2) * exp(-t * tone.decay * 2) : 0
                // Fade in, decay, and a short fade out so nothing clicks.
                let attack = tone.attack > 0 ? min(t / tone.attack, 1) : 1
                let release = min(Double(count - i) / (0.01 * sampleRate), 1)
                let env = attack * exp(-t * tone.decay) * release
                out[first + i] += (s + over) / (1 + tone.overtone) * env * tone.volume
            }
        }
        return out.map { Float(max(-1, min(1, $0 * gain))) }
    }
}
