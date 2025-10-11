//
//  RecordingTabView.swift
//  MindFlow
//
//  Created on 2025-10-11.
//

import SwiftUI

/// 录音页面 Tab 内容
///
/// 提供录音、转录和文本优化的完整流程界面
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
                if let result = viewModel.result {
                    PreviewView(result: result)
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

/// 空闲状态视图 - 等待用户开始录音
struct IdleStateView: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("准备开始录音")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("点击下方按钮或使用快捷键 ⌘ Shift V")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: {
                viewModel.startRecording()
            }) {
                HStack {
                    Image(systemName: "record.circle")
                    Text("开始录音")
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

/// 录音状态视图 - 显示录音进度和控制按钮
struct RecordingStateView: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            recordingIndicator

            Text(viewModel.formattedDuration)
                .font(.system(.largeTitle, design: .monospaced))
                .bold()

            Text("录音中...")
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
                    Text(viewModel.isPaused ? "继续" : "暂停")
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
                    Text("停止并处理")
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

/// 处理状态视图 - 显示转录和优化进度
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
                Text("正在将语音转换为文字...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if case .optimizing = viewModel.state {
                Text("正在使用 AI 优化文本...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Error State View

/// 错误状态视图 - 显示错误信息和重试选项
struct ErrorStateView: View {
    let message: String
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("出错了")
                .font(.title3)
                .bold()

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("重试") {
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
