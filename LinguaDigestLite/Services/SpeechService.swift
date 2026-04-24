//
//  SpeechService.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation
import AVFoundation
import Combine

/// 语音朗读服务
class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    @Published var isSpeaking: Bool = false
    @Published var currentWordRange: NSRange?
    @Published var speakingProgress: Double = 0.0

    private var currentUtterance: AVSpeechUtterance?
    private var speakText: String?

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 可用语音

    /// 获取可用的英语语音
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.filter { $0.language.hasPrefix("en") }
    }

    /// 语音显示名称
    static func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        let locale = Locale(identifier: voice.language)
        let languageName = locale.localizedString(forLanguageCode: voice.language) ?? voice.language
        return "\(languageName) - \(voice.name)"
    }

    // MARK: - 朗读控制

    /// 朗读文本
    func speak(_ text: String, voice: AVSpeechSynthesisVoice? = nil, rate: Float = 0.5) {
        stop()

        speakText = text

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0

        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    /// 朗读文本段落
    func speakParagraph(_ text: String, voice: AVSpeechSynthesisVoice? = nil, rate: Float = 0.5) {
        speak(text, voice: voice, rate: rate)
    }

    /// 朗读单词
    func speakWord(_ word: String, voice: AVSpeechSynthesisVoice? = nil) {
        speak(word, voice: voice, rate: 0.4)
    }

    /// 停止朗读
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentWordRange = nil
        speakingProgress = 0.0
    }

    /// 暂停朗读
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
    }

    /// 继续朗读
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }

    // MARK: - 语音设置

    /// 获取默认语音
    static func defaultVoice() -> AVSpeechSynthesisVoice {
        return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice(language: "en-GB")!
    }

    /// 获取语音选项列表
    static func voiceOptions() -> [(name: String, voice: AVSpeechSynthesisVoice?)] {
        let voices = availableVoices()
        var options: [(name: String, voice: AVSpeechSynthesisVoice?)] = []

        // 添加常用选项
        options.append(("美式英语 (默认)", AVSpeechSynthesisVoice(language: "en-US")))
        options.append(("英式英语", AVSpeechSynthesisVoice(language: "en-GB")))
        options.append(("澳式英语", AVSpeechSynthesisVoice(language: "en-AU")))

        // 添加系统其他可用语音
        for voice in voices {
            let name = voiceDisplayName(voice)
            if !options.contains { $0.name == name } {
                options.append((name, voice))
            }
        }

        return options
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentWordRange = nil
            self.speakingProgress = 1.0
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordRange = characterRange

            // 计算进度
            if let text = self.speakText {
                self.speakingProgress = Double(characterRange.location + characterRange.length) / Double(text.utf16.count)
            }
        }
    }
}

// MARK: - 录音服务

/// 录音服务（用于跟读练习）
class RecordingService: NSObject, ObservableObject {
    static let shared = RecordingService()

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    @Published var isRecording: Bool = false
    @Published var isPlayingRecording: Bool = false
    @Published var recordingDuration: Double = 0.0

    private var recordingURL: URL?
    private var recordingStartTime: Date?

    override private init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    /// 开始录音
    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        recordingURL = audioFilename

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    /// 停止录音
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false

        // 计算录音时长
        if let startTime = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        recordingStartTime = nil
    }

    /// 播放录音
    func playRecording() {
        guard let url = recordingURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlayingRecording = true
        } catch {
            print("Failed to play recording: \(error)")
        }
    }

    /// 停止播放录音
    func stopPlayingRecording() {
        audioPlayer?.stop()
        isPlayingRecording = false
    }

    /// 删除录音
    func deleteRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension RecordingService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlayingRecording = false
        }
    }
}