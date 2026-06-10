//
//  VoiceController.swift
//  Cooked
//
//  Created by Tomáš Kříž on 09.06.2026.
//

import Foundation
import Speech
import AVFoundation
import Observation

enum VoiceCommand {
    case nextStep
    case previousStep
    case scrollTop
    case scrollBottom
    case scrollUp
    case scrollDown
    case unknown(String)
}

@MainActor
@Observable
final class VoiceController {

    // MARK: - Public state

    // Whether the mic is actively listening
    private(set) var isListening = false

    // Last recognised raw transcript (for debugging / UI feedback)
    private(set) var lastTranscript: String = ""

    // Emits a command whenever one is confidently recognised
    var onCommand: ((VoiceCommand) -> Void)?

    // Non-nil when something went wrong
    private(set) var errorMessage: String?

    // MARK: - Private

    private let recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Debounce: don't fire the same command twice within this window
    private var lastCommandDate: Date = .distantPast
    private let commandCooldown: TimeInterval = 1.2

    // MARK: - Init

    init() {
        // Initialise with the current app locale so the recogniser understands same language user is reading recipe in
        recognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    // MARK: - Public API

    func requestPermissions() async -> Bool {
        // Speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            errorMessage = String(localized: "voice.error.speech_permission")
            return false
        }

        // Microphone permission
        if #available(iOS 17.0, *) {
            let micGranted = await AVAudioApplication.requestRecordPermission()
            guard micGranted else {
                errorMessage = String(localized: "voice.error.mic_permission")
                return false
            }
        } else {
            let micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard micGranted else {
                errorMessage = String(localized: "voice.error.mic_permission")
                return false
            }
        }

        return true
    }

    func startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = String(localized: "voice.error.unavailable")
            return
        }

        do {
            try beginSession()
            isListening = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    func toggle() {
        isListening ? stopListening() : startListening()
    }

    // MARK: - Private

    private func beginSession() throws {
        // Tear down any previous session first
        stopListening()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { throw VoiceError.requestCreationFailed }

        // Report partial results so we can react without waiting for silence
        recognitionRequest.shouldReportPartialResults = true

        // Limit on-device only
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }

        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcript = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                Task { @MainActor in
                    self.lastTranscript = transcript
                    self.evaluate(transcript: transcript)
                }
            }

            if error != nil || result?.isFinal == true {
                // Auto-restart so listening is continuous
                Task { @MainActor in
                    if self.isListening {
                        try? self.beginSession()
                    }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Command matching

    private func evaluate(transcript: String) {
        guard let command = match(transcript: transcript) else { return }

        // Prevent the same utterance from firing repeatedly
        let now = Date()
        guard now.timeIntervalSince(lastCommandDate) >= commandCooldown else { return }
        lastCommandDate = now

        onCommand?(command)
    }

    // Maps a lowercased transcript to a VoiceCommand
    private func match(transcript: String) -> VoiceCommand? {

        let nextPhrases = [
            "next", "next step", "forward", "continue",
            "další", "další krok", "dál",               // Czech
        ]

        let previousPhrases = [
            "back", "previous", "previous step", "go back",
            "zpět", "předchozí", "předchozí krok",       // Czech
        ]

        let topPhrases = [
            "top", "beginning", "start", "go to top",
            "začátek", "nahoru",                         // Czech
        ]
        
        let bottomPhrases = [
            "bottom", "end", "go bottom",
            "konec",  "dolů",           // Czech
        ]
        
        let downPhrases = [
            "down", "lower",
            "níž"            // Czech
        ]
        
        let upPhrases = [
            "up", "higher",
            "výš",              // Czech
        ]

        if nextPhrases.contains(where: { transcript.hasSuffix($0) || transcript == $0 }) {
            return .nextStep
        }
        if previousPhrases.contains(where: { transcript.hasSuffix($0) || transcript == $0 }) {
            return .previousStep
        }
        if topPhrases.contains(where: { transcript.hasSuffix($0) || transcript == $0 }) {
            return .scrollTop
        }
        if bottomPhrases.contains(where: { transcript.hasSuffix($0) || transcript == $0 }) {
            return .scrollBottom
        }
        if upPhrases.contains(where: { transcript.hasSuffix($0) || transcript == $0 }) {
            return .scrollUp
        }
        if downPhrases.contains(where: { transcript.hasSuffix($0) || transcript == $0 }) {
            return .scrollDown
        }

        return nil
    }

    // MARK: - Errors

    enum VoiceError: LocalizedError {
        case requestCreationFailed
        var errorDescription: String? { "Could not create speech recognition request." }
    }
}
