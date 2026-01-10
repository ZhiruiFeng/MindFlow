//
//  RecordingTabView.swift
//  MindFlow
//
//  Created on 2025-10-11.
//

import SwiftUI

/// Recording tab view content
///
/// Provides the complete workflow interface for recording, transcription, and text optimization
struct RecordingTabView: View {
    @ObservedObject var viewModel: RecordingViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            switch viewModel.state {
            case .idle:
                IdleStateView(viewModel: viewModel)
            case .recording:
                RecordingStateView(viewModel: viewModel)
            case .processing, .transcribing, .optimizing:
                ProcessingStateView(viewModel: viewModel)
            case .completed:
                if viewModel.result != nil {
                    VStack(spacing: 0) {
                        PreviewView(result: $viewModel.result, viewModel: viewModel)

                        Divider()

                        // New Recording button
                        Button(action: {
                            viewModel.reset()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("recording.new".localized)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            case .error(let message):
                ErrorStateView(message: message, viewModel: viewModel)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.checkPermissions()
        }
    }
}

// MARK: - Idle State View

/// Idle state view - waiting for user to start recording
struct IdleStateView: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("recording.ready".localized)
                .font(.title3)
                .foregroundColor(.secondary)

            Text("recording.shortcut_hint".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: {
                viewModel.startRecording()
            }) {
                HStack {
                    Image(systemName: "record.circle")
                    Text("recording.start".localized)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Recording State View

/// Recording state view - displays recording progress and control buttons
struct RecordingStateView: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            recordingIndicator

            Text(viewModel.formattedDuration)
                .font(.system(.largeTitle, design: .monospaced))
                .bold()

            Text("recording.recording".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            audioWaveform

            Spacer()

            controlButtons
        }
    }

    private var recordingIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 100, height: 100)
                .scaleEffect(viewModel.pulseAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)

            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundColor(.red)
        }
        .onAppear {
            viewModel.pulseAnimation = true
        }
    }

    private var audioWaveform: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3, height: CGFloat.random(in: 10...40))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                viewModel.pauseRecording()
            }) {
                HStack {
                    Image(systemName: viewModel.isPaused ? "play.circle" : "pause.circle")
                    Text(viewModel.isPaused ? "recording.resume".localized : "recording.pause".localized)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: {
                viewModel.stopRecording()
            }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("recording.stop".localized)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Processing State View

/// Processing state view - displays transcription and optimization progress
struct ProcessingStateView: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text(viewModel.state.displayMessage)
                .font(.headline)

            if case .transcribing = viewModel.state {
                Text("state.transcribing_detail".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if case .optimizing = viewModel.state {
                Text("state.optimizing_detail".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Error State View

/// Error state view - displays error message and retry option
struct ErrorStateView: View {
    let message: String
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("recording.error".localized)
                .font(.title3)
                .bold()

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("recording.retry".localized) {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }
}

// MARK: - Preview

struct RecordingTabView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingTabView(viewModel: RecordingViewModel())
    }
}
