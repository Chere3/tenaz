import AVFoundation
import Observation
import Speech

/// On-device transcription for speaking tasks (SFSpeechRecognizer, en-US). Permission is asked
/// only from the main window ("Set up microphone" on the Placement and Exams pages), never inside
/// Exam Mode, whose screen-saver-level panel would hide the system prompt. While microphone or
/// speech recognition is not authorized, every speaking task stays on the typed path.
@Observable
final class SpeechRecorder {
    enum Status: Equatable {
        /// Never asked: the button offers to ask.
        case notAsked
        /// The system prompts are on screen.
        case asking
        case denied
        case unavailable(String)
        case ready
        case recording
    }

    private(set) var status: Status = .notAsked
    private(set) var transcript = ""

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognition: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    init() { refresh() }

    /// Reads the current authorization without asking for anything.
    func refresh() {
        guard status != .recording, status != .asking else { return }
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        let speech = SFSpeechRecognizer.authorizationStatus()
        if mic == .denied || mic == .restricted || speech == .denied || speech == .restricted {
            status = .denied
        } else if mic == .authorized && speech == .authorized {
            status = recognizer?.isAvailable == true ? .ready : .unavailable("Speech recognition is not available right now.")
        } else {
            status = .notAsked
        }
    }

    /// Asks for microphone and speech recognition (the system shows its own prompts).
    func requestAccess() async {
        guard status == .notAsked else { return }
        status = .asking
        let micOK = await AVCaptureDevice.requestAccess(for: .audio)
        let speechOK = await Self.requestSpeech()
        status = micOK && speechOK ? .ready : .denied
        if status == .ready, recognizer?.isAvailable != true { status = .unavailable("Speech recognition is not available right now.") }
    }

    private nonisolated static func requestSpeech() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    func start() {
        guard status == .ready, let recognizer else { return }
        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 2048, format: input.outputFormat(forBus: 0), block: Self.tap(request))
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            status = .unavailable("The microphone didn't start.")
            return
        }
        recognition = recognizer.recognitionTask(with: request, resultHandler: Self.handler { [weak self] text in
            self?.transcript = text
        })
        self.engine = engine
        self.request = request
        status = .recording
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        request?.endAudio()
        recognition?.finish()
        engine = nil
        request = nil
        recognition = nil
        if status == .recording { status = .ready }
    }

    /// Audio-thread tap: built outside the main actor so it never asserts main-actor isolation.
    private nonisolated static func tap(_ request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    private nonisolated static func handler(_ update: @escaping @MainActor (String) -> Void)
        -> (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            Task { @MainActor in update(text) }
        }
    }
}
