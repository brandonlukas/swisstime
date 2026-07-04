import SwiftUI
import AVFoundation
import UIKit

/// One name per key: AppSettings' engine-side getters and the views'
/// @AppStorage bindings read the same storage, and a raw string typo'd in
/// either place would split the truth silently.
enum SettingsKey {
    static let theme = "settings.theme"
    static let voiceCues = "settings.voiceCues"
    static let haptics = "settings.haptics"
    static let liveActivity = "settings.liveActivity"
    static let voiceIdentifier = "settings.voiceIdentifier"
}

/// UserDefaults-backed switches, readable from engine code that has no
/// SwiftUI environment. Views bind the same keys through @AppStorage.
enum AppSettings {
    static var voiceCues: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.voiceCues) as? Bool ?? true
    }
    static var haptics: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true
    }
    static var liveActivity: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.liveActivity) as? Bool ?? true
    }
    static var voiceIdentifier: String? {
        let id = UserDefaults.standard.string(forKey: SettingsKey.voiceIdentifier)
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
/// Low Power Mode (via PowerState, the app's single low-power truth) rests
/// the motors automatically. Generators are held and re-prepared after each
/// fire so the Taptic Engine is warm when the tap lands — a cold per-call
/// generator can buzz late or not at all.
@MainActor
enum Haptics {
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    static var enabled: Bool {
        AppSettings.haptics && !PowerState.shared.lowPower
    }

    static func impact() {
        guard enabled else { return }
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
    }

    static func success() {
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    static func selection() {
        guard enabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
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

/// The main window's current scheme, published. When the theme is System
/// the app root is un-overridden, so this tracks the live system
/// appearance — and being an ObservableObject it reaches INTO a presented
/// sheet, whose content closure would otherwise never re-evaluate.
@MainActor
final class SystemScheme: ObservableObject {
    static let shared = SystemScheme()
    @Published var scheme: ColorScheme = .light
}

/// Invisible: sits on the app root and reports its resolved scheme.
struct SchemeReporter: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .onAppear { SystemScheme.shared.scheme = colorScheme }
            .onChange(of: colorScheme) { _, new in
                SystemScheme.shared.scheme = new
            }
    }
}

/// The whole page earns its place with the voice picker; everything else
/// is a quiet switch. Settings that can be situations aren't here — Low
/// Power Mode already calms the water, stills the tilt, and rests haptics.
struct SettingsView: View {
    @ObservedObject private var systemScheme = SystemScheme.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var theme = ThemeChoice.system.rawValue
    @AppStorage(SettingsKey.voiceCues) private var voiceCues = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.liveActivity) private var liveActivity = true
    @AppStorage(SettingsKey.voiceIdentifier) private var voiceIdentifier = ""
    @State private var voices: [VoiceOption] = []
    @State private var preview = VoicePreview()
    /// The voice list is long enough to bury Haptics and Live Activity —
    /// it stays folded behind the current pick until asked for.
    @State private var voicesExpanded = false
    /// Cached fold-row summary; see resolveSelectedVoiceName.
    @State private var selectedVoiceName = ""

    /// A voice plus its display line, resolved once when the list loads —
    /// `detailLine` does a Locale lookup per voice, too slow to redo on
    /// every unrelated re-render of this screen (toggling Haptics, etc).
    private struct VoiceOption: Identifiable {
        let voice: AVSpeechSynthesisVoice
        let detail: String
        var id: String { voice.identifier }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SheetCloseButton { dismiss() }
                Spacer()
            }
            .padding(20)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    PageHeader(title: "Settings")
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
                    if ProcessInfo.processInfo.arguments.contains("-debugScheme") {
                        Text(verbatim: "reported=\(systemScheme.scheme) sheet=\(sheetScheme)")
                            .font(.app(13, .bold))
                            .foregroundStyle(Color.signalRed)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .background(PaperBackground())
        // A sheet is its own hosting window, and the app-level
        // preferredColorScheme doesn't reliably reach it once the theme
        // changes WHILE the sheet is up — it latches whatever it had.
        // Carrying the preference on the sheet's own content keeps the
        // very screen doing the switching honest about the result.
        .preferredColorScheme(sheetScheme)
        .onChange(of: voiceIdentifier) { _, _ in resolveSelectedVoiceName() }
        .onAppear {
            resolveSelectedVoiceName()
            // Debug: walk the theme through the reported repro sequence
            // (day → system → night) with the sheet up, for screenshots.
            if ProcessInfo.processInfo.arguments.contains("-autoCycleTheme") {
                let steps: [(Double, ThemeChoice)] = [(2, .day), (4, .system), (6, .night)]
                for (delay, choice) in steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        theme = choice.rawValue
                    }
                }
            }
        }
    }

    /// Day and Night pin the scheme. System can't just pass nil: a nil
    /// preference doesn't CLEAR an override this window already applied
    /// (Day → System left the sheet stuck light) — so System resolves to
    /// the live system appearance reported by the app root.
    private var sheetScheme: ColorScheme {
        ThemeChoice(rawValue: theme)?.colorScheme ?? systemScheme.scheme
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    voicesExpanded.toggle()
                }
                if voicesExpanded, voices.isEmpty { loadVoices() }
            } label: {
                HStack(spacing: 10) {
                    Text("Voice")
                        .font(.app(17, .medium))
                    Spacer(minLength: 8)
                    Text(selectedVoiceName)
                        .font(.app(15))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(voicesExpanded ? 180 : 0))
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if voicesExpanded {
                voiceRow(name: "Automatic",
                         detail: "The most natural voice on this device",
                         selected: voiceIdentifier.isEmpty) {
                    voiceIdentifier = ""
                    preview.speak(nil)
                }
                ForEach(voices) { option in
                    Rectangle().fill(Color.hairline).frame(height: 1)
                    voiceRow(name: option.voice.name,
                             detail: option.detail,
                             selected: voiceIdentifier == option.voice.identifier) {
                        voiceIdentifier = option.voice.identifier
                        preview.speak(option.voice)
                    }
                }
                Text("More voices — including higher-quality ones — can be downloaded in Settings → Accessibility → Spoken Content → Voices.")
                    .font(.app(13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
        }
    }

    /// The folded row's summary, resolved OFF the main thread and cached:
    /// AVSpeechSynthesisVoice(identifier:) is an XPC-backed registry
    /// lookup, and body re-evaluates on every unrelated toggle — the
    /// lookup must not run per render.
    private func resolveSelectedVoiceName() {
        let id = voiceIdentifier
        guard !id.isEmpty else {
            selectedVoiceName = "Automatic"
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let name = AVSpeechSynthesisVoice(identifier: id)?.name ?? "Automatic"
            DispatchQueue.main.async { selectedVoiceName = name }
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

    private static func detailLine(for voice: AVSpeechSynthesisVoice) -> String {
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
    /// the automatic pick so the list and the default agree. Each voice's
    /// display line is resolved here too, once, instead of on every render.
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
                .map { VoiceOption(voice: $0, detail: Self.detailLine(for: $0)) }
            DispatchQueue.main.async { voices = list }
        }
    }
}
