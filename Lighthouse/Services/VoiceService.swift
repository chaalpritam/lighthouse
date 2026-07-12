import Foundation
import AVFoundation
import Speech
import Combine

enum VoiceState: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case unavailable(String)
}

@MainActor
final class VoiceService: NSObject, ObservableObject {
    @Published private(set) var state: VoiceState = .idle
    @Published private(set) var transcript = ""

    var onFinalTranscript: ((String) -> Void)?
    var onSpeakDone: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        return speech && mic
    }

    func startListening() {
        guard speechRecognizer?.isAvailable == true else {
            state = .unavailable("Speech recognition unavailable")
            return
        }
        stopListening()
        transcript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            state = .listening

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.stopListening()
                            let text = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                self.onFinalTranscript?(text)
                            }
                        }
                    }
                    if error != nil {
                        self.stopListening()
                    }
                }
            }
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        if state == .listening || state == .processing {
            state = .idle
        }
    }

    func speak(_ text: String) {
        stopListening()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        state = .speaking
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        if state == .speaking { state = .idle }
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .idle
            onSpeakDone?()
        }
    }
}
