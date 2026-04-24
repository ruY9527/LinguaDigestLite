//
//  SettingsView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

/// 设置视图
struct SettingsView: View {
    @ObservedObject var userSettings = UserSettings.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var showingFontPicker: Bool = false
    @State private var showingThemePicker: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                // 阅读设置
                readingSettingsSection
                
                // 语音设置
                speechSettingsSection
                
                // 学习设置
                learningSettingsSection
                
                // 关于
                aboutSection
            }
            .navigationTitle("设置")
        }
    }
    
    /// 阅读设置部分
    private var readingSettingsSection: some View {
        Section("阅读设置") {
            // 字体大小
            VStack(alignment: .leading, spacing: 8) {
                Text("字体大小")
                
                HStack {
                    Text("A")
                        .font(.caption)
                    
                    Slider(value: $userSettings.readingSettings.fontSize, in: 12...28, step: 1)
                    
                    Text("A")
                        .font(.title2)
                }
                
                Text("\(Int(userSettings.readingSettings.fontSize)) pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 行间距
            VStack(alignment: .leading, spacing: 8) {
                Text("行间距")
                
                HStack {
                    ForEach([1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { spacing in
                        Button {
                            userSettings.readingSettings.lineHeight = spacing
                        } label: {
                            Text("\(spacing, specifier: "%.2f")")
                                .font(.subheadline)
                                .padding(8)
                                .background(
                                    userSettings.readingSettings.lineHeight == spacing
                                        ? Color.blue.opacity(0.2)
                                        : Color.clear
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // 段落间距
            Stepper("段落间距: \(Int(userSettings.readingSettings.paragraphSpacing))", value: $userSettings.readingSettings.paragraphSpacing, in: 8...24)
            
            // 边距
            Stepper("页面边距: \(Int(userSettings.readingSettings.marginSize))", value: $userSettings.readingSettings.marginSize, in: 8...32)
            
            // 字体选择
            NavigationLink {
                FontPickerView(selectedFont: $userSettings.readingSettings.fontName)
            } label: {
                HStack {
                    Text("字体")
                    Spacer()
                    Text(fontDisplayName)
                        .foregroundColor(.secondary)
                }
            }
            
            // 主题选择
            NavigationLink {
                ThemePickerView(selectedTheme: $userSettings.readingSettings.theme)
            } label: {
                HStack {
                    Text("阅读主题")
                    Spacer()
                    
                    Circle()
                        .fill(Color(hex: userSettings.readingSettings.theme.backgroundColor))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
            }
        }
    }
    
    /// 语音设置部分
    private var speechSettingsSection: some View {
        Section("语音朗读") {
            NavigationLink {
                VoicePickerView()
            } label: {
                HStack {
                    Text("语音")
                    Spacer()
                    Text("美式英语")
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("朗读速度")
                
                HStack {
                    Image(systemName: "tortoise")
                        .foregroundColor(.gray)
                    
                    Slider(value: $userSettings.readingSettings.speechRate, in: 0.3...0.8, step: 0.1)
                    
                    Image(systemName: "hare")
                        .foregroundColor(.gray)
                }
                
                Text(speechRateDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// 学习设置部分
    private var learningSettingsSection: some View {
        Section("学习设置") {
            // 自动高亮生词
            Toggle("自动高亮生词", isOn: $userSettings.readingSettings.autoHighlightNewWords)
            
            // 显示音标
            Toggle("显示音标", isOn: $userSettings.readingSettings.showPhonetic)
            
            // 词汇等级
            NavigationLink {
                VocabularyLevelPickerView(selectedLevel: $userSettings.readingSettings.vocabularyLevel)
            } label: {
                HStack {
                    Text("词汇等级")
                    Spacer()
                    Text(userSettings.readingSettings.vocabularyLevel.displayName)
                        .foregroundColor(.secondary)
                }
            }
            
            // 每日复习提醒
            Toggle("每日复习提醒", isOn: Binding(
                get: { false },
                set: { _ in }
            ))
        }
    }
    
    /// 关于部分
    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("应用名称")
                Spacer()
                Text("LinguaDigestLite")
                    .foregroundColor(.secondary)
            }
            
            Link(destination: URL(string: "https://github.com")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                userSettings.resetToDefaults()
            } label: {
                Text("重置所有设置")
                    .foregroundColor(.red)
            }
        }
    }
    
    /// 字体显示名称
    private var fontDisplayName: String {
        if let fontName = userSettings.readingSettings.fontName {
            return ReadingSettings.standardFonts.first { $0.value == fontName }?.key ?? "自定义"
        }
        return "系统字体"
    }

    /// 朗读速度描述
    private var speechRateDescription: String {
        let rate = userSettings.readingSettings.speechRate
        if rate < 0.4 {
            return "慢速"
        } else if rate < 0.55 {
            return "适中"
        } else if rate < 0.7 {
            return "快速"
        } else {
            return "极快"
        }
    }
}

/// 字体选择视图
struct FontPickerView: View {
    @Binding var selectedFont: String?
    
    var body: some View {
        List {
            ForEach(ReadingSettings.standardFonts.sorted(by: { $0.key < $1.key }), id: \.key) { font in
                Button {
                    selectedFont = font.value
                } label: {
                    HStack {
                        if let customFontName = font.value {
                            Text(font.key)
                                .font(.custom(customFontName, size: 16))
                        } else {
                            Text(font.key)
                                .font(.system(size: 16))
                        }
                        
                        Spacer()
                        
                        if selectedFont == font.value {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("选择字体")
    }
}

/// 主题选择视图
struct ThemePickerView: View {
    @Binding var selectedTheme: ReadingTheme
    
    var body: some View {
        List {
            ForEach(ReadingTheme.allCases, id: \.self) { theme in
                Button {
                    selectedTheme = theme
                } label: {
                    HStack {
                        // 主题预览
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: theme.backgroundColor))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("A")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: theme.textColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        
                        Text(theme.displayName)
                        
                        Spacer()
                        
                        if selectedTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("选择主题")
    }
}

/// 语音选择视图
struct VoicePickerView: View {
    @State private var selectedVoiceIndex: Int = 0
    
    let voices = SpeechService.voiceOptions()
    
    var body: some View {
        List {
            ForEach(0..<voices.count, id: \.self) { index in
                Button {
                    selectedVoiceIndex = index
                    // 保存语音设置
                } label: {
                    HStack {
                        Text(voices[index].name)
                        
                        Spacer()
                        
                        if selectedVoiceIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                        
                        // 试听按钮
                        Button {
                            SpeechService.shared.speakWord("Hello", voice: voices[index].voice)
                        } label: {
                            Image(systemName: "speaker.wave.3")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("选择语音")
    }
}

/// 词汇等级选择视图
struct VocabularyLevelPickerView: View {
    @Binding var selectedLevel: VocabularyLevel
    
    var body: some View {
        List {
            ForEach(VocabularyLevel.allCases, id: \.self) { level in
                Button {
                    selectedLevel = level
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.displayName)
                            
                            Text(levelDescription(level))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedLevel == level {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("词汇等级")
    }
    
    /// 等级描述
    private func levelDescription(_ level: VocabularyLevel) -> String {
        switch level {
        case .beginner:
            return "基础词汇，适合初学者"
        case .elementary:
            return "初级词汇，适合有一定基础的学习者"
        case .intermediate:
            return "中级词汇，适合中级学习者"
        case .advanced:
            return "高级词汇，适合高级学习者"
        case .expert:
            return "全词表，适合专业学习者"
        }
    }
}
