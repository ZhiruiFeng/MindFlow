//
//  RecordingView.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("MindFlow")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // 根据状态显示不同的内容
            switch viewModel.state {
            case .idle:
                idleView
            case .recording:
                recordingView
            case .processing, .transcribing, .optimizing:
                processingView
            case .completed:
                PreviewView(result: viewModel.result)
            case .error(let message):
                errorView(message: message)
            }
            
            Spacer()
        }
        .frame(minWidth: 400, minHeight: 450)
        .onAppear {
            viewModel.checkPermissions()
        }
    }
    
    // MARK: - Idle View
    
    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 麦克风图标
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("准备开始录音")
                .font(.title3)
                .foregroundColor(.secondary)
            
            // 开始按钮
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
    
    // MARK: - Recording View
    
    private var recordingView: some View {
        VStack(spacing: 16) {
            // 动画录音图标
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
            .padding(.top, 20)
            
            // 录音时长
            Text(viewModel.formattedDuration)
                .font(.system(.largeTitle, design: .monospaced))
                .bold()
            
            Text("录音中...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 音频波形（简化显示）
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 3, height: CGFloat.random(in: 10...40))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Spacer()
            
            // 控制按钮 - 确保可见
            VStack(spacing: 12) {
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
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
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
        .padding()
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
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
        .padding()
    }
}

// MARK: - Recording ViewModel

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var state: TranscriptionState = .idle
    @Published var duration: TimeInterval = 0
    @Published var pulseAnimation = false
    @Published var isPaused = false
    @Published var result: TranscriptionResult?
    
    private let audioRecorder = AudioRecorder.shared
    private let sttService = STTService.shared
    private let llmService = LLMService.shared
    private let permissionManager = PermissionManager.shared
    
    private var timer: Timer?
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func checkPermissions() {
        if !permissionManager.isMicrophonePermissionGranted {
            state = .error("需要麦克风权限才能录音")
        }
    }
    
    func startRecording() {
        guard permissionManager.isMicrophonePermissionGranted else {
            state = .error("需要麦克风权限")
            return
        }
        
        state = .recording
        duration = 0
        isPaused = false
        
        // 开始录音
        audioRecorder.startRecording { [weak self] success in
            if !success {
                self?.state = .error("无法开始录音")
            }
        }
        
        // 启动计时器
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.duration += 0.1
        }
    }
    
    func pauseRecording() {
        isPaused.toggle()
        if isPaused {
            audioRecorder.pauseRecording()
        } else {
            audioRecorder.resumeRecording()
        }
    }
    
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        pulseAnimation = false
        
        state = .processing
        
        // 停止录音
        audioRecorder.stopRecording { [weak self] audioURL in
            guard let self = self, let url = audioURL else {
                self?.state = .error("录音文件无效")
                return
            }
            
            // 转录
            self.transcribe(audioURL: url)
        }
    }
    
    private func transcribe(audioURL: URL) {
        state = .transcribing
        
        Task {
            do {
                let text = try await sttService.transcribe(audioURL: audioURL)
                await MainActor.run {
                    self.optimize(originalText: text, audioURL: audioURL)
                }
            } catch {
                await MainActor.run {
                    self.state = .error("转录失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func optimize(originalText: String, audioURL: URL) {
        state = .optimizing
        
        Task {
            do {
                let optimizedText = try await llmService.optimizeText(originalText)
                
                let result = TranscriptionResult(
                    originalText: originalText,
                    optimizedText: optimizedText,
                    duration: duration,
                    audioFilePath: audioURL.path
                )
                
                await MainActor.run {
                    self.result = result
                    self.state = .completed
                }
            } catch {
                // 如果优化失败，至少返回原始文本
                let result = TranscriptionResult(
                    originalText: originalText,
                    optimizedText: nil,
                    duration: duration,
                    audioFilePath: audioURL.path
                )
                
                await MainActor.run {
                    self.result = result
                    self.state = .completed
                }
            }
        }
    }
    
    func reset() {
        state = .idle
        duration = 0
        pulseAnimation = false
        isPaused = false
        result = nil
    }
}

// MARK: - Preview

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
    }
}

