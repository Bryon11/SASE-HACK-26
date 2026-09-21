import AVFoundation

/// Synthesizes short coin "dings" that rise in pitch, so no audio files are needed.
/// Uses the ambient category: respects the silent switch and mixes with music.
@MainActor
final class CoinSoundPlayer {
    static let shared = CoinSoundPlayer()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let format: AVAudioFormat

    /// Semitone steps of a major scale — each coin rings one note higher.
    private static let steps: [Double] = [0, 2, 4, 7, 9, 12, 14]

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        for _ in 0..<4 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
    }

    func ding(step: Int, final: Bool = false) {
        guard startIfNeeded() else { return }
        let semitones = Self.steps[min(max(step, 0), Self.steps.count - 1)]
        let frequency = 1046.5 * pow(2, semitones / 12) // starts at C6
        guard let buffer = makeTone(frequency: frequency, final: final) else { return }

        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
    }

    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            return true
        } catch {
            print("Coin sound unavailable: \(error)")
            return false
        }
    }

    /// A bright bell tone; the final coin adds a low "thunk" underneath.
    private func makeTone(frequency: Double, final: Bool) -> AVAudioPCMBuffer? {
        let duration = final ? 0.6 : 0.3
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        let sampleRate = format.sampleRate
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let attack = min(t / 0.004, 1)
            let bell = sin(2 * .pi * frequency * t) + 0.45 * sin(2 * .pi * frequency * 2.52 * t)
            var value = bell * attack * exp(-t * (final ? 6 : 10))
            if final {
                value += 0.9 * sin(2 * .pi * 180 * t) * attack * exp(-t * 18)
            }
            samples[i] = Float(value * 0.2)
        }
        return buffer
    }
}
