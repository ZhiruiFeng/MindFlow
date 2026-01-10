//
//  PronunciationButton.swift
//  MindFlow
//
//  Reusable speaker button component for word pronunciation
//

import SwiftUI

/// A reusable button component for playing word pronunciation
struct PronunciationButton: View {
    let word: String
    var size: ButtonSize = .regular

    @ObservedObject private var ttsService = TTSService.shared
    @ObservedObject private var settings = Settings.shared

    enum ButtonSize {
        case small
        case regular
        case large

        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .regular: return 18
            case .large: return 24
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .regular: return 6
            case .large: return 8
            }
        }
    }

    var body: some View {
        Button(action: playPronunciation) {
            Group {
                if ttsService.isLoading {
                    ProgressView()
                        .scaleEffect(size == .small ? 0.5 : (size == .regular ? 0.7 : 0.9))
                        .frame(width: size.fontSize, height: size.fontSize)
                } else {
                    Image(systemName: speakerIcon)
                        .font(.system(size: size.fontSize))
                }
            }
            .foregroundColor(buttonColor)
            .frame(width: size.fontSize + size.padding * 2, height: size.fontSize + size.padding * 2)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(helpText)
        .contentShape(Rectangle())
    }

    // MARK: - Computed Properties

    private var speakerIcon: String {
        if ttsService.isPlaying {
            return "speaker.wave.3.fill"
        } else {
            return "speaker.wave.2"
        }
    }

    private var buttonColor: Color {
        if isDisabled {
            return .secondary.opacity(0.5)
        } else if ttsService.isPlaying {
            return .blue
        } else {
            return .secondary
        }
    }

    private var isDisabled: Bool {
        settings.elevenLabsKey.isEmpty || ttsService.isLoading
    }

    private var helpText: String {
        if settings.elevenLabsKey.isEmpty {
            return "Configure ElevenLabs API key in Settings to enable pronunciation"
        } else if ttsService.isPlaying {
            return "Playing pronunciation..."
        } else {
            return "Play pronunciation"
        }
    }

    // MARK: - Actions

    private func playPronunciation() {
        Task {
            do {
                try await ttsService.pronounce(word: word)
            } catch {
                print("TTS error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview

struct PronunciationButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Text("Small:")
                PronunciationButton(word: "eloquent", size: .small)
            }

            HStack(spacing: 16) {
                Text("Regular:")
                PronunciationButton(word: "eloquent", size: .regular)
            }

            HStack(spacing: 16) {
                Text("Large:")
                PronunciationButton(word: "eloquent", size: .large)
            }
        }
        .padding()
    }
}
