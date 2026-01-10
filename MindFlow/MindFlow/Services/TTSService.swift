//
//  TTSService.swift
//  MindFlow
//
//  Text-to-Speech service using ElevenLabs API
//

import Foundation
import AVFoundation

/// Text-to-Speech service for vocabulary pronunciation
class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()

    private var settings: Settings {
        return Settings.shared
    }

    private var audioPlayer: AVAudioPlayer?

    /// In-memory cache for audio data
    private let audioCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 100  // Cache up to 100 words
        cache.totalCostLimit = 10 * 1024 * 1024  // 10MB limit
        return cache
    }()

    // MARK: - Published Properties

    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false

    // MARK: - Configuration

    /// Default voice ID (Rachel - clear American female)
    private let defaultVoiceId = "21m00Tcm4TlvDq8ikWAM"

    /// TTS model
    private let modelId = "eleven_multilingual_v2"

    // MARK: - Initialization

    private override init() {
        super.init()
        print("TTSService initialized")
    }

    // MARK: - Public Methods

    /// Pronounce a word
    /// - Parameter word: The word to pronounce
    @MainActor
    func pronounce(word: String) async throws {
        // Stop any current playback
        stopPlayback()

        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedWord.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        // Check cache first
        if let cachedData = getCachedAudio(for: normalizedWord) {
            try playAudioData(cachedData)
            return
        }

        // Generate audio from ElevenLabs
        let audioData = try await synthesizeWithElevenLabs(text: word)

        // Cache the audio
        cacheAudio(audioData, for: normalizedWord)

        // Play the audio
        try playAudioData(audioData)
    }

    /// Stop current audio playback
    @MainActor
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    /// Clear the audio cache
    func clearCache() {
        audioCache.removeAllObjects()
        print("TTS audio cache cleared")
    }

    // MARK: - ElevenLabs TTS API

    private func synthesizeWithElevenLabs(text: String) async throws -> Data {
        guard !settings.elevenLabsKey.isEmpty else {
            throw TTSError.missingAPIKey("ElevenLabs API Key not configured")
        }

        let endpoint = "https://api.elevenlabs.io/v1/text-to-speech/\(defaultVoiceId)"

        guard let url = URL(string: endpoint) else {
            throw TTSError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let trimmedKey = settings.elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(trimmedKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        // Request body
        let requestBody: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TTSError.apiError("ElevenLabs TTS: HTTP \(httpResponse.statusCode) - \(errorMessage)")
        }

        return data
    }

    // MARK: - Audio Playback

    @MainActor
    private func playAudioData(_ data: Data) throws {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            let success = audioPlayer?.play() ?? false
            if success {
                isPlaying = true
                print("Playing pronunciation audio")
            } else {
                throw TTSError.audioPlaybackError("Failed to start audio playback")
            }
        } catch {
            throw TTSError.audioPlaybackError("Failed to create audio player: \(error.localizedDescription)")
        }
    }

    // MARK: - Caching

    private func getCachedAudio(for word: String) -> Data? {
        let key = word.lowercased() as NSString
        if let cachedData = audioCache.object(forKey: key) {
            print("TTS cache hit for: \(word)")
            return cachedData as Data
        }
        return nil
    }

    private func cacheAudio(_ data: Data, for word: String) {
        let key = word.lowercased() as NSString
        audioCache.setObject(data as NSData, forKey: key, cost: data.count)
        print("TTS cached audio for: \(word)")
    }
}

// MARK: - AVAudioPlayerDelegate

extension TTSService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            if flag {
                print("Pronunciation playback finished")
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            if let error = error {
                print("Audio decode error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - TTS Error

enum TTSError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case apiError(String)
    case audioPlaybackError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidResponse:
            return "Invalid server response"
        case .apiError(let message):
            return "API error: \(message)"
        case .audioPlaybackError(let message):
            return "Audio playback error: \(message)"
        }
    }
}
