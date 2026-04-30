//
//  ReadingSettings.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// 阅读设置
struct ReadingSettings: Codable {
    var fontSize: CGFloat
    var lineHeight: CGFloat
    var paragraphSpacing: CGFloat
    var marginSize: CGFloat
    var theme: ReadingTheme
    var fontName: String?
    var autoHighlightNewWords: Bool
    var vocabularyLevel: VocabularyLevel
    var showPhonetic: Bool
    var speechRate: Float // 朗读速度 0.3-0.8

    init() {
        self.fontSize = 17
        self.lineHeight = 1.5
        self.paragraphSpacing = 12
        self.marginSize = 16
        self.theme = .light
        self.autoHighlightNewWords = true
        self.vocabularyLevel = .intermediate
        self.showPhonetic = true
        self.speechRate = 0.5
    }

    static let standardFonts = [
        "System": nil,
        "Georgia": "Georgia",
        "Charter": "Charter",
        "Lora": "Lora-Regular",
        "Palatino": "Palatino",
        "Times New Roman": "TimesNewRomanPSMT"
    ]
}

/// 每日复习提醒设置
struct ReminderSettings: Codable {
    /// 是否启用每日复习提醒
    var dailyReviewEnabled: Bool
    
    /// 提醒时间（小时，0-23）
    var reminderHour: Int
    
    /// 提醒时间（分钟，0-59）
    var reminderMinute: Int
    
    /// 提醒标题
    var reminderTitle: String
    
    init() {
        self.dailyReviewEnabled = false
        self.reminderHour = 9      // 默认早上9点
        self.reminderMinute = 0
        self.reminderTitle = "每日复习提醒"
    }
    
    /// 提醒时间字符串
    var reminderTimeString: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }
    
    /// 设置提醒时间
    func setTime(hour: Int, minute: Int) -> ReminderSettings {
        var newSettings = self
        newSettings.reminderHour = max(0, min(23, hour))
        newSettings.reminderMinute = max(0, min(59, minute))
        return newSettings
    }
}

/// 阅读主题
enum ReadingTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case sepia = "sepia"
    case green = "green"
    
    var displayName: String {
        switch self {
        case .light: return "日间模式"
        case .dark: return "夜间模式"
        case .sepia: return "护眼黄纸"
        case .green: return "护眼绿"
        }
    }
    
    var backgroundColor: String {
        switch self {
        case .light: return "#FFFFFF"
        case .dark: return "#1C1C1E"
        case .sepia: return "#F4ECD8"
        case .green: return "#E8F5E9"
        }
    }
    
    var textColor: String {
        switch self {
        case .light: return "#000000"
        case .dark: return "#FFFFFF"
        case .sepia: return "#5B4636"
        case .green: return "#2E7D32"
        }
    }
}

/// 词汇等级
enum VocabularyLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case elementary = "elementary"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "初学者 (Oxford 1000)"
        case .elementary: return "初级 (Oxford 2000)"
        case .intermediate: return "中级 (Oxford 3000)"
        case .advanced: return "高级 (Oxford 5000)"
        case .expert: return "专家级 (全词表)"
        }
    }
    
    /// 返回已知词汇表名称
    var knownWordsSetName: String {
        switch self {
        case .beginner: return "oxford_1000"
        case .elementary: return "oxford_2000"
        case .intermediate: return "oxford_3000"
        case .advanced: return "oxford_5000"
        case .expert: return "all_words"
        }
    }
}

/// 用户设置管理
class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard
    private let readingSettingsKey = "readingSettings"
    private let reminderSettingsKey = "reminderSettings"

    @Published var readingSettings: ReadingSettings {
        didSet {
            saveReadingSettings()
        }
    }
    
    @Published var reminderSettings: ReminderSettings {
        didSet {
            saveReminderSettings()
        }
    }

    private init() {
        if let data = defaults.data(forKey: readingSettingsKey),
           let settings = try? JSONDecoder().decode(ReadingSettings.self, from: data) {
            self.readingSettings = settings
        } else {
            self.readingSettings = ReadingSettings()
        }
        
        if let data = defaults.data(forKey: reminderSettingsKey),
           let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) {
            self.reminderSettings = settings
        } else {
            self.reminderSettings = ReminderSettings()
        }
    }

    private func saveReadingSettings() {
        guard let data = try? JSONEncoder().encode(readingSettings) else { return }
        defaults.set(data, forKey: readingSettingsKey)
    }
    
    private func saveReminderSettings() {
        guard let data = try? JSONEncoder().encode(reminderSettings) else { return }
        defaults.set(data, forKey: reminderSettingsKey)
    }

    func resetToDefaults() {
        readingSettings = ReadingSettings()
        reminderSettings = ReminderSettings()
    }
    
    /// 切换每日提醒开关
    func toggleDailyReminder(_ enabled: Bool) {
        reminderSettings.dailyReviewEnabled = enabled
    }
    
    /// 设置提醒时间
    func setReminderTime(hour: Int, minute: Int) {
        reminderSettings.reminderHour = max(0, min(23, hour))
        reminderSettings.reminderMinute = max(0, min(59, minute))
    }
}