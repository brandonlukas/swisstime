import AVFoundation
import UIKit

/// The one policy for the spoken "5 seconds left": fire with a small lead
/// (the synthesizer takes a beat to make sound — speech starting while the
/// clock still shows 0:05 reads right), and skip it on spans so short the
/// zero beep is already imminent. Shared so the player and the Sets tab
/// can never drift apart on it — including the wake-from-sleep latch,
/// which must use the same threshold as the fire test.
enum VoiceCueRule {
    static let lead: TimeInterval = 5.2
    static let minimumSpan: TimeInterval = 10
}

/// Owns the audio session, speech synthesis, and alert sounds.
///
/// While a workout runs, a silent looping player keeps the app alive in the
/// background (the target has the `audio` background mode). Other apps' audio
/// is only ducked while we are actually speaking or beeping; afterwards the
/// session is briefly cycled so their volume comes back up.
final class AudioManager: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let session = AVAudioSession.sharedInstance()
    /// Resolved per utterance, so a voice picked in Settings applies to an
    /// already-running session too; the expensive enumeration behind the
    /// automatic pick is cached once per process (warmed at session start).
    private var voice: AVSpeechSynthesisVoice? { Self.resolveVoice() }
    /// Session activation/category changes block on IPC to the media server —
    /// tens of ms — so they all run here, never on the main thread. Static:
    /// the session is process-shared, and when one engine hands off to
    /// another (counter yielding to a player) their deactivate/activate
    /// must land in order.
    private static let sharedSessionQueue = DispatchQueue(label: "SwissTime.AudioSession",
                                                          qos: .userInitiated)
    private var sessionQueue: DispatchQueue { Self.sharedSessionQueue }
    private var beepPlayer: AVAudioPlayer?
    private var donePlayer: AVAudioPlayer?
    private var silencePlayer: AVAudioPlayer?

    private var activeSounds = 0
    private var running = false
    private var keepAliveWanted = true
    private var inBackground = false

    /// Called once at app launch, before any engine exists. An
    /// AVAudioPlayer's prepareToPlay acquires audio hardware under the
    /// session's CURRENT category — and the process default (soloAmbient)
    /// is non-mixing, so the first engine of a cold launch paused the
    /// user's music the moment its players were created. Setting the
    /// mixable category up front (no activation) makes the first start
    /// behave like every start after it.
    static func warmUpSession() {
        sharedSessionQueue.async {
            try? AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .spokenAudio, options: [.mixWithOthers])
        }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
        beepPlayer = makePlayer("beep")
        donePlayer = makePlayer("done")
        silencePlayer = makePlayer("silence")
        silencePlayer?.numberOfLoops = -1
        silencePlayer?.volume = 0
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(didEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(willEnterForeground),
                           name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    /// While backgrounded the session must never go inactive: a session
    /// deactivated out of view may not be handed back by the system, which
    /// silences every cue and lets the app be suspended (the Live Activity
    /// keeps counting on its endDate, so it *looks* like only audio broke).
    @objc private func didEnterBackground() {
        inBackground = true
        guard running, keepAliveWanted else { return }
        sessionQueue.async { [self] in
            try? session.setActive(true)
            silencePlayer?.play()
        }
    }

    /// Back in view — now it's safe to cycle the session and lift any
    /// ducking left over from cues played in the background.
    @objc private func willEnterForeground() {
        inBackground = false
        guard running, activeSounds == 0 else { return }
        releaseDuck(keepAlive: keepAliveWanted)
    }

    /// Ducking only ends when the session deactivates, so cycle it.
    /// Foreground only — see didEnterBackground.
    private func releaseDuck(keepAlive: Bool) {
        sessionQueue.async { [self] in
            silencePlayer?.pause()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            applyCategory(ducking: false)
            try? session.setActive(true)
            if keepAlive { silencePlayer?.play() }
        }
    }

    func start() {
        running = true
        keepAliveWanted = true
        sessionQueue.async { [self] in
            applyCategory(ducking: false)
            try? session.setActive(true)
            silencePlayer?.play()
            // Resolve the voice now, off the critical path: enumerating
            // voices is slow, and in a session whose FIRST speech is a
            // timed cue (the Sets tab's "5 seconds left") that cost would
            // otherwise land on the cue itself and make it audibly late.
            _ = voice
        }
    }

    func stop() {
        running = false
        activeSounds = 0
        sessionQueue.async { [self] in
            synthesizer.stopSpeaking(at: .immediate)
            beepPlayer?.stop()
            donePlayer?.stop()
            silencePlayer?.stop()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// The silent loop only needs to run while the timer is actually counting.
    func setKeepAlive(_ wanted: Bool) {
        keepAliveWanted = wanted
        guard running else { return }
        let idle = activeSounds == 0
        sessionQueue.async { [self] in
            if wanted {
                silencePlayer?.play()
            } else if idle {
                silencePlayer?.pause()
            }
        }
    }

    /// Duck bookkeeping happens here on the caller's (main) thread, but the
    /// synthesizer runs on the session queue: preparing an utterance and
    /// voice can block for long enough to drop frames mid-transition.
    ///
    /// `delay` holds the voice until an alert sound fired alongside it has
    /// finished, so the two cues never talk over each other.
    func speak(_ text: String, interrupting: Bool = false, delay: TimeInterval = 0) {
        // The voice can be switched off wholesale — beeps and chimes carry
        // the moments that matter; speech is the optional narration.
        guard running, !text.isEmpty, AppSettings.voiceCues else { return }
        beginSound()
        sessionQueue.async { [self] in
            if interrupting, synthesizer.isSpeaking {
                // didCancel fires per dropped utterance, keeping the duck
                // count balanced. The new utterance is already counted, so
                // the duck never flaps between the two.
                synthesizer.stopSpeaking(at: .immediate)
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.preUtteranceDelay = delay
            synthesizer.speak(utterance)
        }
    }

    func playBeep() { play(beepPlayer) }
    func playDone() { play(donePlayer) }

    /// The user's chosen voice, or the best the device has.
    static func resolveVoice() -> AVSpeechSynthesisVoice? {
        if let id = AppSettings.voiceIdentifier,
           let chosen = AVSpeechSynthesisVoice(identifier: id) {
            return chosen
        }
        return naturalVoice()
    }

    /// The slow enumeration runs once; every later call — including the
    /// settings sheet's main-thread "Automatic" preview — hits the cache.
    private static let cachedNaturalVoice = computeNaturalVoice()

    static func naturalVoice() -> AVSpeechSynthesisVoice? {
        cachedNaturalVoice
    }

    /// Asking for a bare `en-US` voice yields the old compact robot; use the
    /// most natural English voice on the device instead. Novelty voices would
    /// be absurd mid-workout and personal voices need separate authorization.
    private static func computeNaturalVoice() -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en")
                && !$0.voiceTraits.contains(.isNoveltyVoice)
                && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        let best = candidates.max { a, b in
            if a.quality != b.quality { return a.quality.rawValue < b.quality.rawValue }
            return (a.language == "en-US" ? 1 : 0) < (b.language == "en-US" ? 1 : 0)
        }
        return best ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private func play(_ player: AVAudioPlayer?) {
        guard running, let player else { return }
        if player.isPlaying {
            // Restarting a playing sound yields only one didFinish;
            // don't count it twice or the duck would never lift.
            sessionQueue.async { player.currentTime = 0 }
            return
        }
        beginSound()
        sessionQueue.async {
            player.currentTime = 0
            player.play()
        }
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
        sessionQueue.async { [self] in
            applyCategory(ducking: true)
            try? session.setActive(true)
        }
    }

    private func endSound() {
        activeSounds = max(0, activeSounds - 1)
        guard activeSounds == 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.running, self.activeSounds == 0 else { return }
            if self.inBackground {
                // Best-effort duck release without dropping the session;
                // the full cycle waits for willEnterForeground.
                let keepAlive = self.keepAliveWanted
                self.sessionQueue.async {
                    self.applyCategory(ducking: false)
                    if keepAlive { self.silencePlayer?.play() }
                }
                return
            }
            self.releaseDuck(keepAlive: self.keepAliveWanted)
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
