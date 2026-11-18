import AVFoundation
import Foundation
import MediaPlayer
import Observation
import ReadAloudCore
import UIKit

struct NowPlayingMetadata: Sendable {
    var title: String
    var artist: String
    var album: String
    var artworkData: Data?
}

/// Receives `AVSpeechSynthesizer` callbacks and forwards them as Sendable events.
/// The delegate protocol is not main-actor isolated, so no actor state is touched here.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    enum Event: Sendable {
        case willSpeak(ObjectIdentifier, NSRange)
        case didFinish(ObjectIdentifier)
    }

    var handler: (@Sendable (Event) -> Void)?

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        handler?(.willSpeak(ObjectIdentifier(utterance), characterRange))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        handler?(.didFinish(ObjectIdentifier(utterance)))
    }
}

/// Read-Aloud engine: `AVSpeechSynthesizer` playback of one block of text with word and sentence
/// ranges for highlighting, plus audio session, interruption handling and Lock Screen controls.
///
/// Text is spoken as a queue of short utterances (see `TextChunker`) so seeking, rate changes and
/// highlighting stay accurate on long chapters. Utterance-relative ranges are mapped back to
/// offsets in the full text.
@MainActor
@Observable
final class SpeechEngine {
    enum State: Sendable { case idle, playing, paused }

    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    /// Word currently being spoken, as a UTF-16 range in the loaded text.
    private(set) var wordRange: NSRange?
    /// Sentence containing the current word.
    private(set) var sentenceRange: NSRange?

    @ObservationIgnored var onSectionFinished: (@MainActor () -> Void)?
    /// Called with the start of the current sentence whenever it changes. Callers must throttle persistence.
    @ObservationIgnored var onPosition: (@MainActor (Int) -> Void)?
    @ObservationIgnored var onStateChange: (@MainActor (State) -> Void)?
    /// Lock Screen next/previous track: -1 or +1 section.
    @ObservationIgnored var onSkipSection: (@MainActor (Int) -> Void)?
    @ObservationIgnored var nowPlaying: NowPlayingMetadata? { didSet { updateNowPlaying() } }

    @ObservationIgnored private(set) var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    private struct InFlight {
        let utterance: AVSpeechUtterance
        let id: ObjectIdentifier
        let base: Int
    }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = SpeechDelegate()
    @ObservationIgnored private var text: NSString = ""
    @ObservationIgnored private var string = ""
    @ObservationIgnored private var voice: AVSpeechSynthesisVoice?
    @ObservationIgnored private var chunks: [SpeechChunk] = []
    @ObservationIgnored private var nextChunkIndex = 0
    @ObservationIgnored private var inFlight: [InFlight] = []
    /// Cancelled utterances stay alive briefly so a late callback can never match a new utterance's id.
    @ObservationIgnored private var retired: [[AVSpeechUtterance]] = []
    @ObservationIgnored private var resumeLocation = 0
    @ObservationIgnored private var needsRestartOnResume = false
    @ObservationIgnored private var interruptedWhilePlaying = false
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var commandTargets: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var isRegistered = false

    init() {
        delegate.handler = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        synthesizer.delegate = delegate
    }

    // MARK: - Loading and transport

    /// Loads text without starting playback. Cancels anything in progress but keeps the audio session.
    func load(text: String, language: String?, resumeAt location: Int = 0) {
        cancelInFlight()
        self.string = text
        self.text = text as NSString
        self.voice = Self.bestVoice(forLanguage: language)
        self.resumeLocation = min(max(location, 0), self.text.length)
        needsRestartOnResume = false
        wordRange = nil
        sentenceRange = nil
        state = .idle
    }

    func setRate(_ newRate: Float) {
        let clamped = min(max(newRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        guard clamped != rate else { return }
        rate = clamped
        switch state {
        case .playing: startSpeaking(at: resumeLocation)
        case .paused: needsRestartOnResume = true
        case .idle: break
        }
    }

    func play(from location: Int? = nil) {
        registerIfNeeded()
        activateSession()
        // State first: startSpeaking may finish the section immediately (empty text) and set .idle.
        state = .playing
        startSpeaking(at: location ?? resumeLocation)
        updateNowPlaying()
    }

    func pause() {
        guard state == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
        updateNowPlaying()
    }

    func resume() {
        guard state == .paused else { return }
        activateSession()
        state = .playing
        if needsRestartOnResume || (!synthesizer.isSpeaking && !synthesizer.isPaused) {
            startSpeaking(at: resumeLocation)
        } else {
            synthesizer.continueSpeaking()
        }
        updateNowPlaying()
    }

    func toggle() {
        switch state {
        case .playing: pause()
        case .paused: resume()
        case .idle: play()
        }
    }

    func stop() {
        cancelInFlight()
        wordRange = nil
        sentenceRange = nil
        state = .idle
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        if isRegistered { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    /// Skips one sentence forward (`+1`) or back (`-1`).
    func skipSentence(_ direction: Int) {
        guard state != .idle else { return }
        let current = sentenceRange ?? NSRange(location: resumeLocation, length: 0)
        let target: Int
        if direction >= 0 {
            target = TextChunker.skipWhitespace(from: NSMaxRange(current), in: text)
        } else if current.location > 0,
                  let previous = TextChunker.sentenceRange(containing: current.location - 1, in: text) {
            target = previous.location
        } else {
            target = 0
        }
        guard target < text.length else {
            finishSection()
            return
        }
        state = .playing
        startSpeaking(at: target)
        updateNowPlaying()
    }

    /// Releases everything global: observers, Lock Screen commands, now-playing info, audio session.
    func shutdown() {
        stop()
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers = []
        for (command, token) in commandTargets {
            command.removeTarget(token)
            command.isEnabled = false
        }
        commandTargets = []
        isRegistered = false
        delegate.handler = nil
        onSectionFinished = nil
        onPosition = nil
        onStateChange = nil
        onSkipSection = nil
    }

    // MARK: - Speaking queue

    private func startSpeaking(at location: Int) {
        cancelInFlight()
        resumeLocation = location
        needsRestartOnResume = false
        chunks = TextChunker.chunks(in: string, from: location)
        nextChunkIndex = 0
        guard !chunks.isEmpty else {
            finishSection()
            return
        }
        fillQueue()
        if synthesizer.isPaused { synthesizer.continueSpeaking() }
    }

    /// Keeps two utterances queued so playback is gapless between chunks.
    private func fillQueue() {
        while inFlight.count < 2, nextChunkIndex < chunks.count {
            let chunk = chunks[nextChunkIndex]
            nextChunkIndex += 1
            let utterance = AVSpeechUtterance(string: chunk.text)
            utterance.voice = voice
            utterance.rate = rate
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0
            inFlight.append(InFlight(utterance: utterance, id: ObjectIdentifier(utterance), base: chunk.range.location))
            synthesizer.speak(utterance)
        }
    }

    private func cancelInFlight() {
        if !inFlight.isEmpty {
            retired.append(inFlight.map(\.utterance))
            if retired.count > 3 { retired.removeFirst() }
        }
        inFlight = []
        chunks = []
        nextChunkIndex = 0
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func handle(_ event: SpeechDelegate.Event) {
        switch event {
        case .willSpeak(let id, let range):
            guard let item = inFlight.first(where: { $0.id == id }) else { return }
            let location = min(item.base + range.location, max(text.length - 1, 0))
            let length = min(range.length, text.length - location)
            wordRange = NSRange(location: location, length: max(length, 0))

            if sentenceRange.map({ !NSLocationInRange(location, $0) }) ?? true {
                sentenceRange = TextChunker.sentenceRange(containing: location, in: text)
                let sentenceStart = sentenceRange?.location ?? location
                resumeLocation = sentenceStart
                onPosition?(sentenceStart)
            }

        case .didFinish(let id):
            guard let index = inFlight.firstIndex(where: { $0.id == id }) else { return }
            inFlight.remove(at: index)
            fillQueue()
            if inFlight.isEmpty, nextChunkIndex >= chunks.count, state == .playing {
                finishSection()
            }
        }
    }

    private func finishSection() {
        cancelInFlight()
        wordRange = nil
        sentenceRange = nil
        resumeLocation = 0
        state = .idle
        onSectionFinished?()
    }

    // MARK: - Voice

    private static func bestVoice(forLanguage language: String?) -> AVSpeechSynthesisVoice? {
        guard let prefix = language?.split(whereSeparator: { $0 == "-" || $0 == "_" }).first?.lowercased(),
              !prefix.isEmpty else { return nil }
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }
            .max { $0.quality.rawValue < $1.quality.rawValue }
    }

    // MARK: - Audio session

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    private func registerIfNeeded() {
        guard !isRegistered else { return }
        isRegistered = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { @Sendable [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
            let began = type == .began
            Task { @MainActor in self?.handleInterruption(began: began, shouldResume: shouldResume) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { @Sendable [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.pause() }   // headphones unplugged
        })

        let commands = MPRemoteCommandCenter.shared()
        addCommand(commands.playCommand) { if $0.state == .paused { $0.resume() } else if $0.state == .idle { $0.play() } }
        addCommand(commands.pauseCommand) { $0.pause() }
        addCommand(commands.togglePlayPauseCommand) { $0.toggle() }
        addCommand(commands.nextTrackCommand) { $0.onSkipSection?(1) }
        addCommand(commands.previousTrackCommand) { $0.onSkipSection?(-1) }
    }

    private func addCommand(_ command: MPRemoteCommand, action: @escaping @Sendable @MainActor (SpeechEngine) -> Void) {
        command.isEnabled = true
        let token = command.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                if let self { action(self) }
            }
            return .success
        }
        commandTargets.append((command, token))
    }

    private func handleInterruption(began: Bool, shouldResume: Bool) {
        if began {
            if state == .playing {
                interruptedWhilePlaying = true
                synthesizer.pauseSpeaking(at: .immediate)
                state = .paused
                updateNowPlaying()
            }
        } else {
            let wasInterrupted = interruptedWhilePlaying
            interruptedWhilePlaying = false
            if wasInterrupted && shouldResume { resume() }
        }
    }

    // MARK: - Lock Screen

    private func updateNowPlaying() {
        guard let metadata = nowPlaying, state != .idle else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadata.title,
            MPMediaItemPropertyArtist: metadata.artist,
            MPMediaItemPropertyAlbumTitle: metadata.album,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
        if let data = metadata.artworkData, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in
                UIImage(data: data) ?? UIImage()
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = state == .playing ? .playing : .paused
    }
}
