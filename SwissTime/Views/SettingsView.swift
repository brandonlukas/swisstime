import SwiftUI
import AVFoundation
import UIKit

/// UserDefaults-backed switches, readable from engine code that has no
/// SwiftUI environment. Views bind the same keys through @AppStorage.
enum AppSettings {
    static var voiceCues: Bool {
        UserDefaults.standard.object(forKey: "settings.voiceCues") as? Bool ?? true
    }
    static var haptics: Bool {
        UserDefaults.standard.object(forKey: "settings.haptics") as? Bool ?? true
    }
    static var liveActivity: Bool {
        UserDefaults.standard.object(forKey: "settings.liveActivity") as? Bool ?? true
    }
    static var voiceIdentifier: String? {
        let id = UserDefaults.standard.string(forKey: "settings.voiceIdentifier")
        return (id?.isEmpty ?? true) ? nil : id
    }
}

/// System / day / night swim. `system` follows iOS.
enum ThemeChoice: String, CaseIterable {
    case system, day, night

    var title: String {
        switch self {
        case .system: return "System"
        case .day: return "Day"
        case .night: return "Night"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .day: return .light
        case .night: return .dark
        }
    }
}

/// Every buzz in the app runs through here: one switch to rule them, and
/// Low Power Mode rests the motors automatically.
@MainActor
enum Haptics {
    static var enabled: Bool {
        AppSettings.haptics && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// Says the actual cue in the tapped voice — auditioning with the words
/// the voice will actually say. The launch-time session category is
/// mixable, so previews never pause the user's music.
final class VoicePreview {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ voice: AVSpeechSynthesisVoice?) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "5 seconds left.")
        utterance.voice = voice ?? AudioManager.naturalVoice()
        synthesizer.speak(utterance)
    }
}

/// The whole page earns its place with the voice picker; everything else
/// is a quiet switch. Settings that can be situations aren't here — Low
/// Power Mode already calms the water, stills the tilt, and rests haptics.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings.theme") private var theme = ThemeChoice.system.rawValue
    @AppStorage("settings.voiceCues") private var voiceCues = true
    @AppStorage("settings.haptics") private var haptics = true
    @AppStorage("settings.liveActivity") private var liveActivity = true
    @AppStorage("settings.voiceIdentifier") private var voiceIdentifier = ""
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var preview = VoicePreview()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(20)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Settings")
                            .display(26)
                            .padding(.bottom, 14)
                        InkRule()
                    }
                    SegmentRow(label: "Theme",
                               options: ThemeChoice.allCases.map(\.rawValue),
                               display: { ThemeChoice(rawValue: $0)?.title ?? $0 },
                               selection: $theme)
                    VStack(alignment: .leading, spacing: 10) {
                        CheckboxRow(title: "Voice cues", isOn: $voiceCues)
                        Text("Spoken announcements like “5 seconds left.” Beeps and chimes always play.")
                            .font(.app(14))
                            .foregroundStyle(.secondary)
                    }
                    if voiceCues {
                        voiceSection
                    }
                    CheckboxRow(title: "Haptics", isOn: $haptics)
                    VStack(alignment: .leading, spacing: 10) {
                        CheckboxRow(title: "Live Activity", isOn: $liveActivity)
                        Text("The running timer on the Lock Screen and in the Dynamic Island.")
                            .font(.app(14))
                            .foregroundStyle(.secondary)
                    }
                    Text("In Low Power Mode the water calms, the tilt stills, and haptics rest — automatically.")
                        .font(.app(13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .background(PaperBackground())
        .onAppear(perform: loadVoices)
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Voice")
                .font(.app(17, .medium))
                .padding(.bottom, 4)
            voiceRow(name: "Automatic",
                     detail: "The most natural voice on this device",
                     selected: voiceIdentifier.isEmpty) {
                voiceIdentifier = ""
                preview.speak(nil)
            }
            ForEach(voices, id: \.identifier) { voice in
                Rectangle().fill(Color.hairline).frame(height: 1)
                voiceRow(name: voice.name,
                         detail: detailLine(for: voice),
                         selected: voiceIdentifier == voice.identifier) {
                    voiceIdentifier = voice.identifier
                    preview.speak(voice)
                }
            }
            Text("More voices — including higher-quality ones — can be downloaded in Settings → Accessibility → Spoken Content → Voices.")
                .font(.app(13))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }

    private func voiceRow(name: String, detail: String, selected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.app(16, selected ? .medium : .regular))
                    Text(detail)
                        .font(.app(13))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detailLine(for voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium: quality = "Premium"
        case .enhanced: quality = "Enhanced"
        default: quality = "Standard"
        }
        let language = Locale.current.localizedString(forIdentifier: voice.language)
            ?? voice.language
        return "\(quality) · \(language)"
    }

    /// Enumerating voices is slow — off the main thread, same filter as
    /// the automatic pick so the list and the default agree.
    private func loadVoices() {
        DispatchQueue.global(qos: .userInitiated).async {
            let list = AVSpeechSynthesisVoice.speechVoices()
                .filter {
                    $0.language.hasPrefix("en")
                        && !$0.voiceTraits.contains(.isNoveltyVoice)
                        && !$0.voiceTraits.contains(.isPersonalVoice)
                }
                .sorted { a, b in
                    if a.quality != b.quality {
                        return a.quality.rawValue > b.quality.rawValue
                    }
                    return a.name < b.name
                }
            DispatchQueue.main.async { voices = list }
        }
    }
}
