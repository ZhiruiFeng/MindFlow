//
//  AudioRecorder.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import AVFoundation

/// Audio recording service
class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?
    
    @Published var isRecording = false
    @Published var isPaused = false
    
    private override init() {
        super.init()
        // macOS doesn't need to configure audio session, AVAudioSession is only available on iOS
        print("✅ AudioRecorder 初始化完成")
    }
    
    // MARK: - Recording Control
    
    /// Start recording
    func startRecording(completion: @escaping (Bool) -> Void) {
        // Generate temporary file path
        let tempDir = FileManager.default.temporaryDirectory
        audioURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).m4a")

        guard let url = audioURL else {
            completion(false)
            return
        }

        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            let success = audioRecorder?.record() ?? false
            isRecording = success
            isPaused = false
            
            if success {
                print("✅ 开始录音: \(url.lastPathComponent)")
            } else {
                print("❌ 录音失败")
            }
            
            completion(success)
        } catch {
            print("❌ 创建录音器失败: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    /// Pause recording
    func pauseRecording() {
        guard isRecording else { return }
        
        audioRecorder?.pause()
        isPaused = true
        print("⏸ 录音已暂停")
    }
    
    /// Resume recording
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        audioRecorder?.record()
        isPaused = false
        print("▶️ 录音已继续")
    }
    
    /// Stop recording
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }

        audioRecorder?.stop()
        isRecording = false
        isPaused = false

        print("⏹ 录音已停止")

        // Return recording file URL
        completion(audioURL)
    }
    
    /// Cancel recording
    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        isRecording = false
        isPaused = false

        // Delete temporary file
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
        }

        audioURL = nil
        print("🗑 录音已取消")
    }
    
    // MARK: - Audio Level
    
    /// Get current audio level (0.0 - 1.0)
    func getAudioLevel() -> Float {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return 0.0
        }

        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)

        // Convert decibel value to 0-1 range
        // averagePower range is typically -160 to 0
        let normalized = (averagePower + 160) / 160
        return max(0.0, min(1.0, normalized))
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        audioRecorder?.stop()
        audioRecorder = nil
        
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        audioURL = nil
        isRecording = false
        isPaused = false
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✅ 录音完成: \(recorder.url.lastPathComponent)")
        } else {
            print("❌ 录音失败")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("❌ 录音编码错误: \(error.localizedDescription)")
        }
    }
}

