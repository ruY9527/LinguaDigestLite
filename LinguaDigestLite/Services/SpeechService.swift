//
//  SpeechService.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//  语音朗读服务 - 支持全文朗读、分段朗读、高亮追踪、后台播放
//

import Foundation
import AVFoundation
import Combine
import NaturalLanguage

/// 语音朗读服务
class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - 状态发布
    
    /// 是否正在朗读
    @Published var isSpeaking: Bool = false
    
    /// 是否暂停
    @Published var isPaused: Bool = false
    
    /// 当前朗读的字符范围
    @Published var currentWordRange: NSRange?
    
    /// 朗读进度（0-1）
    @Published var speakingProgress: Double = 0.0
    
    /// 当前朗读的句子索引（分段朗读模式）
    @Published var currentSentenceIndex: Int = 0
    
    /// 当前朗读的句子文本
    @Published var currentSentenceText: String?
    
    /// 总句子数
    @Published var totalSentences: Int = 0
    
    /// 朗读模式
    @Published var speakingMode: SpeakingMode = .fullText

    private var currentUtterance: AVSpeechUtterance?
    private var speakText: String?
    
    /// 分段朗读时的句子列表
    private var sentences: [String] = []
    
    /// 朗读设置
    private var settings: SpeechSettings = SpeechSettings()
    
    /// 朗读完成回调
    private var onCompletion: (() -> Void)?
    
    /// 每个句子朗读完成回调（用于高亮）
    private var onSentenceComplete: ((Int) -> Void)?

    override private init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    // MARK: - 音频会话设置
    
    private func setupAudioSession() {
        do {
            // 支持后台播放
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    // MARK: - 朗读模式
    
    enum SpeakingMode {
        case fullText       // 全文朗读
        case sentence       // 分段朗读（按句子）
        case paragraph      // 分段朗读（按段落）
    }

    // MARK: - 朗读设置
    
    struct SpeechSettings {
        var voice: AVSpeechSynthesisVoice?
        var rate: Float = 0.5
        var pitch: Float = 1.0
        var volume: Float = 1.0
        var delayBetweenSentences: Double = 0.3  // 句子间隔（秒）
        
        static let `default` = SpeechSettings(
            voice: AVSpeechSynthesisVoice(language: "en-US"),
            rate: 0.5,
            pitch: 1.0,
            volume: 1.0
        )
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

    /// 朗读文本（全文模式）
    func speak(_ text: String, settings: SpeechSettings? = nil, onCompletion: (() -> Void)? = nil) {
        stop()
        
        self.settings = settings ?? SpeechSettings.default
        self.onCompletion = onCompletion
        self.speakingMode = .fullText
        self.speakText = text

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = self.settings.voice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = self.settings.rate
        utterance.pitchMultiplier = self.settings.pitch
        utterance.volume = self.settings.volume
        utterance.preUtteranceDelay = 0

        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    /// 分段朗读（按句子）
    func speakBySentences(_ text: String, settings: SpeechSettings? = nil, onSentenceComplete: ((Int) -> Void)? = nil, onCompletion: (() -> Void)? = nil) {
        stop()
        
        self.settings = settings ?? SpeechSettings.default
        self.onSentenceComplete = onSentenceComplete
        self.onCompletion = onCompletion
        self.speakingMode = .sentence
        self.speakText = text
        
        // 使用 NLP 分割句子
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        sentences = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            sentences.append(sentence)
            return true
        }
        
        totalSentences = sentences.count
        currentSentenceIndex = 0
        
        if !sentences.isEmpty {
            speakSentenceAtIndex(0)
        }
    }
    
    /// 朗读指定句子
    private func speakSentenceAtIndex(_ index: Int) {
        guard index < sentences.count else {
            // 所有句子朗读完成
            finishSpeaking()
            return
        }
        
        currentSentenceIndex = index
        currentSentenceText = sentences[index]
        
        let utterance = AVSpeechUtterance(string: sentences[index])
        utterance.voice = settings.voice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = settings.rate
        utterance.pitchMultiplier = settings.pitch
        utterance.volume = settings.volume
        utterance.preUtteranceDelay = index == 0 ? 0 : settings.delayBetweenSentences
        
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }
    
    /// 朗读下一句
    func speakNextSentence() {
        guard speakingMode == .sentence, currentSentenceIndex < sentences.count - 1 else { return }
        stop()
        speakSentenceAtIndex(currentSentenceIndex + 1)
    }
    
    /// 朗读上一句
    func speakPreviousSentence() {
        guard speakingMode == .sentence, currentSentenceIndex > 0 else { return }
        stop()
        speakSentenceAtIndex(currentSentenceIndex - 1)
    }
    
    /// 从指定句子开始朗读
    func speakFromSentence(_ index: Int) {
        guard speakingMode == .sentence, index >= 0, index < sentences.count else { return }
        stop()
        speakSentenceAtIndex(index)
    }
    
    /// 朗读完成处理
    private func finishSpeaking() {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.speakingProgress = 1.0
            self.currentWordRange = nil
            self.currentSentenceText = nil
            
            if let completion = self.onCompletion {
                completion()
            }
        }
    }

    /// 朗读文本段落
    func speakParagraph(_ text: String, settings: SpeechSettings? = nil) {
        speak(text, settings: settings)
    }

    /// 朗读单词（用于查词）
    func speakWord(_ word: String, voice: AVSpeechSynthesisVoice? = nil, rate: Float = 0.4) {
        // 单词朗读不影响当前朗读状态
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice ?? settings.voice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        
        // 使用单独的 synthesizer 避免干扰主朗读
        let wordSynthesizer = AVSpeechSynthesizer()
        wordSynthesizer.speak(utterance)
    }

    /// 停止朗读
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        currentWordRange = nil
        speakingProgress = 0.0
        currentSentenceIndex = 0
        currentSentenceText = nil
        sentences = []
        onCompletion = nil
        onSentenceComplete = nil
    }

    /// 暂停朗读
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    /// 继续朗读
    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
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
        options.append(("爱尔兰英语", AVSpeechSynthesisVoice(language: "en-IE")))
        options.append(("南非英语", AVSpeechSynthesisVoice(language: "en-ZA")))

        // 添加系统其他可用语音
        for voice in voices {
            let name = voiceDisplayName(voice)
            if !options.contains { $0.name == name } {
                options.append((name, voice))
            }
        }

        return options
    }
    
    /// 获取特定语言的语音标识符
    static func voiceIdentifier(forLocale locale: String) -> String? {
        switch locale {
        case "en-US":
            return "com.apple.voice.compact.en-US"
        case "en-GB":
            return "com.apple.voice.compact.en-GB"
        case "en-AU":
            return "com.apple.voice.compact.en-AU"
        default:
            return nil
        }
    }
    
    /// 速度描述
    static func rateDescription(_ rate: Float) -> String {
        if rate < 0.35 {
            return "很慢"
        } else if rate < 0.45 {
            return "慢"
        } else if rate < 0.55 {
            return "适中"
        } else if rate < 0.65 {
            return "较快"
        } else {
            return "快"
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.isPaused = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            // 分段朗读模式：继续下一个句子
            if self.speakingMode == .sentence && self.currentSentenceIndex < self.sentences.count - 1 {
                // 回调当前句子完成
                if let callback = self.onSentenceComplete {
                    callback(self.currentSentenceIndex)
                }
                
                // 更新进度
                self.speakingProgress = Double(self.currentSentenceIndex + 1) / Double(self.totalSentences)
                
                // 朗读下一句
                self.speakSentenceAtIndex(self.currentSentenceIndex + 1)
            } else {
                // 全文朗读完成或分段朗读全部完成
                self.isSpeaking = false
                self.isPaused = false
                self.currentWordRange = nil
                self.speakingProgress = 1.0
                
                // 分段朗读最后一句完成回调
                if self.speakingMode == .sentence, let callback = self.onSentenceComplete {
                    callback(self.currentSentenceIndex)
                }
                
                if let completion = self.onCompletion {
                    completion()
                }
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = false
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordRange = characterRange

            // 计算进度（全文模式）
            if self.speakingMode == .fullText, let text = self.speakText {
                self.speakingProgress = Double(characterRange.location + characterRange.length) / Double(text.utf16.count)
            }
            
            // 分段模式：进度基于句子索引
            if self.speakingMode == .sentence {
                let sentenceProgress = Double(self.currentSentenceIndex) / Double(self.totalSentences)
                let intraProgress = Double(characterRange.location + characterRange.length) / Double(self.currentSentenceText?.utf16.count ?? 1)
                self.speakingProgress = sentenceProgress + intraProgress / Double(self.totalSentences)
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.currentWordRange = nil
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