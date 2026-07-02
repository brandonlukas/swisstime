import AVFoundation

/// Owns the audio session, speech synthesis, and alert sounds.
///
/// While a workout runs, a silent looping player keeps the app alive in the
/// background (the target has the `audio` background mode). Other apps' audio
/// is only ducked while we are actually speaking or beeping; afterwards the
/// session is briefly cycled so their volume comes back up.
final class AudioManager: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let session = AVAudioSession.sharedInstance()
    private var beepPlayer: AVAudioPlayer?
    private var donePlayer: AVAudioPlayer?
    private var silencePlayer: AVAudioPlayer?

    private var activeSounds = 0
    private var running = false
    private var keepAliveWanted = true

    override init() {
        super.init()
        synthesizer.delegate = self
        beepPlayer = makePlayer("beep")
        donePlayer = makePlayer("done")
        silencePlayer = makePlayer("silence")
        silencePlayer?.numberOfLoops = -1
        silencePlayer?.volume = 0
    }

    func start() {
        running = true
        keepAliveWanted = true
        applyCategory(ducking: false)
        try? session.setActive(true)
        silencePlayer?.play()
    }

    func stop() {
        running = false
        synthesizer.stopSpeaking(at: .immediate)
        beepPlayer?.stop()
        donePlayer?.stop()
        silencePlayer?.stop()
        activeSounds = 0
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The silent loop only needs to run while the timer is actually counting.
    func setKeepAlive(_ wanted: Bool) {
        keepAliveWanted = wanted
        guard running else { return }
        if wanted {
            silencePlayer?.play()
        } else if activeSounds == 0 {
            silencePlayer?.pause()
        }
    }

    func speak(_ text: String, interrupting: Bool = false) {
        guard running, !text.isEmpty else { return }
        if interrupting, synthesizer.isSpeaking {
            // didCancel fires per dropped utterance, keeping the duck count balanced.
            synthesizer.stopSpeaking(at: .immediate)
        }
        beginSound()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func playBeep() { play(beepPlayer) }
    func playDone() { play(donePlayer) }

    private func play(_ player: AVAudioPlayer?) {
        guard running, let player else { return }
        if player.isPlaying {
            // Restarting a playing sound yields only one didFinish;
            // don't count it twice or the duck would never lift.
            player.currentTime = 0
            return
        }
        beginSound()
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        return player
    }

    private func applyCategory(ducking: Bool) {
        let options: AVAudioSession.CategoryOptions = ducking
            ? [.duckOthers, .mixWithOthers]
            : [.mixWithOthers]
        try? session.setCategory(.playback, mode: .spokenAudio, options: options)
    }

    private func beginSound() {
        activeSounds += 1
        guard activeSounds == 1 else { return }
        applyCategory(ducking: true)
        try? session.setActive(true)
    }

    private func endSound() {
        activeSounds = max(0, activeSounds - 1)
        guard activeSounds == 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.running, self.activeSounds == 0 else { return }
            // Ducking only ends when the session deactivates, so cycle it.
            self.silencePlayer?.pause()
            try? self.session.setActive(false, options: .notifyOthersOnDeactivation)
            self.applyCategory(ducking: false)
            try? self.session.setActive(true)
            if self.keepAliveWanted {
                self.silencePlayer?.play()
            }
        }
    }
}

extension AudioManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        endSound()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        endSound()
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player !== silencePlayer {
            endSound()
        }
    }
}
