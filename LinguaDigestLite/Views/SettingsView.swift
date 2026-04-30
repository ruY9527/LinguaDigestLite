//
//  SettingsView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI
import UniformTypeIdentifiers

/// 设置视图
struct SettingsView: View {
    @ObservedObject var userSettings = UserSettings.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var importService = DictionaryImportService.shared

    @State private var showingFontPicker: Bool = false
    @State private var showingThemePicker: Bool = false

    // 词典导入相关状态
    @State private var showingDictionaryImport: Bool = false
    @State private var showingImportFormatGuide: Bool = false
    @State private var showingImportResult: Bool = false
    @State private var importResult: DictionaryImportResult?
    @State private var selectedImportMode: DictionaryImportMode = .enhance
    @State private var showingExportSheet: Bool = false
    @State private var showingClearConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // 阅读设置
                readingSettingsSection

                // 语音设置
                speechSettingsSection

                // 学习设置
                learningSettingsSection
                
                // ECDICT 完整词典
                ecdictDictionarySection

                // 词典导入设置
                dictionaryImportSection

                // 关于
                aboutSection
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingDictionaryImport) {
                DictionaryImportSheet(
                    importMode: selectedImportMode,
                    onImportComplete: { result in
                        importResult = result
                        showingImportResult = true
                    }
                )
            }
            .sheet(isPresented: $showingImportFormatGuide) {
                DictionaryFormatGuideSheet()
            }
            .sheet(isPresented: $showingExportSheet) {
                DictionaryExportSheet()
            }
            .alert("导入结果", isPresented: $showingImportResult) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(importResult?.summary ?? "导入完成")
            }
            .alert("确认清除", isPresented: $showingClearConfirmation) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    DictionaryService.shared.clearCustomEntries()
                }
            } message: {
                Text("确定要清除所有自定义词条吗？此操作不可撤销。")
            }
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
                get: { userSettings.reminderSettings.dailyReviewEnabled },
                set: { newValue in
                    if newValue {
                        // 开启提醒时请求权限
                        NotificationService.shared.requestAuthorization { granted, error in
                            if granted {
                                userSettings.reminderSettings.dailyReviewEnabled = true
                                // 设置通知
                                let reviewCount = DatabaseManager.shared.fetchTodayReviewVocabulary(for: nil).count
                                NotificationService.shared.setDailyReviewReminderWithCount(
                                    hour: userSettings.reminderSettings.reminderHour,
                                    minute: userSettings.reminderSettings.reminderMinute,
                                    enabled: true,
                                    reviewCount: reviewCount
                                ) { _ in }
                            } else {
                                print("通知权限被拒绝: \(error?.localizedDescription ?? "unknown")")
                            }
                        }
                    } else {
                        userSettings.reminderSettings.dailyReviewEnabled = false
                        NotificationService.shared.cancelDailyReviewReminder()
                    }
                }
            ))
            
            if userSettings.reminderSettings.dailyReviewEnabled {
                // 提醒时间选择
                DatePicker(
                    "提醒时间",
                    selection: Binding(
                        get: {
                            let calendar = Calendar.current
                            var components = DateComponents()
                            components.hour = userSettings.reminderSettings.reminderHour
                            components.minute = userSettings.reminderSettings.reminderMinute
                            return calendar.date(from: components) ?? Date()
                        },
                        set: { newDate in
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: newDate)
                            let minute = calendar.component(.minute, from: newDate)
                            userSettings.reminderSettings.reminderHour = hour
                            userSettings.reminderSettings.reminderMinute = minute
                            // 更新通知
                            let reviewCount = DatabaseManager.shared.fetchTodayReviewVocabulary(for: nil).count
                            NotificationService.shared.setDailyReviewReminderWithCount(
                                hour: hour,
                                minute: minute,
                                enabled: true,
                                reviewCount: reviewCount
                            ) { _ in }
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                
                // 显示今日待复习数量
                HStack {
                    Text("今日待复习")
                    Spacer()
                    let reviewCount = DatabaseManager.shared.fetchTodayReviewVocabulary(for: nil).count
                    Text("\(reviewCount) 词")
                        .foregroundColor(reviewCount > 0 ? .orange : .secondary)
                }
                
                // 测试提醒按钮
                Button {
                    NotificationService.shared.sendTestNotification { success in
                        if success {
                            print("测试通知已发送，5秒后收到")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                        Text("发送测试提醒")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    /// ECDICT 完整词典部分
    private var ecdictDictionarySection: some View {
        Section("ECDICT 完整词典") {
            // 状态显示
            HStack {
                Text("词典状态")
                Spacer()
                if DictionaryDatabaseManager.shared.isECDICTAvailable {
                    Text("已就绪")
                        .foregroundColor(.green)
                } else {
                    Text("未找到")
                        .foregroundColor(.orange)
                }
            }

            // 词条数量
            if DictionaryDatabaseManager.shared.isECDICTAvailable {
                HStack {
                    Text("词条数量")
                    Spacer()
                    Text("\(DictionaryDatabaseManager.shared.ecdictEntryCount.formatted()) 条")
                        .foregroundColor(.secondary)
                }
            }

            // 说明
            Text("ECDICT 是开源英汉词典，包含 77 万+词条，支持音标、词性、中文释义。词典已内置在应用中，离线可用。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// 词典导入部分
    private var dictionaryImportSection: some View {
        Section("词典管理") {
            // 当前自定义词条数量
            HStack {
                Text("自定义词条")
                Spacer()
                Text("\(DictionaryService.shared.getCustomEntryCount()) 条")
                    .foregroundColor(.secondary)
            }
            
            // 导入模式选择
            Picker("导入模式", selection: $selectedImportMode) {
                ForEach(DictionaryImportMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            
            // 导入词典按钮
            Button {
                showingDictionaryImport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("导入词典")
                }
            }
            
            // 导出词典按钮
            Button {
                showingExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出自定义词典")
                }
            }
            .disabled(DictionaryService.shared.getCustomEntryCount() == 0)
            
            // 格式说明
            Button {
                showingImportFormatGuide = true
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text("词典格式说明")
                }
            }
            
            // 清除自定义词条
            Button {
                showingClearConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清除自定义词条")
                }
                .foregroundColor(.red)
            }
            .disabled(DictionaryService.shared.getCustomEntryCount() == 0)
            
            // 下载示例文件
            VStack(alignment: .leading, spacing: 12) {
                Text("下载示例词典文件")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Button {
                        downloadSampleFile(format: .json)
                    } label: {
                        Label("JSON", systemImage: "doc.text")
                    }
                    
                    Button {
                        downloadSampleFile(format: .csv)
                    } label: {
                        Label("CSV", systemImage: "doc.text")
                    }
                    
                    Button {
                        downloadSampleFile(format: .txt)
                    } label: {
                        Label("TXT", systemImage: "doc.text")
                    }
                }
            }
        }
    }
    
    /// 下载示例文件
    private func downloadSampleFile(format: DictionaryFileFormat) {
        if let fileURL = DictionaryImportService.shared.generateSampleDictionary(format: format) {
            // 分享文件
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let rootViewController = windowScene.windows.first?.rootViewController
                rootViewController?.present(activityVC, animated: true)
            }
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

// MARK: - 词典导入相关视图

/// 词典导入弹窗
struct DictionaryImportSheet: View {
    let importMode: DictionaryImportMode
    let onImportComplete: (DictionaryImportResult) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker: Bool = false
    @State private var selectedFileURL: URL?
    @State private var isImporting: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 说明
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("导入自定义词典")
                        .font(.headline)
                    
                    Text("支持 JSON、CSV、TXT 格式的词典文件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // 导入模式说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前导入模式: \(importMode.rawValue)")
                        .font(.headline)
                    
                    Text(importModeDescription(importMode))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 选择文件按钮
                Button {
                    showingFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("选择词典文件")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // 已选文件显示
                if let fileURL = selectedFileURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已选择文件:")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading) {
                                Text(fileURL.lastPathComponent)
                                    .font(.subheadline)
                                Text(fileURL.pathExtension.uppercased())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                selectedFileURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                        
                        // 导入按钮
                        Button {
                            importFile(url: fileURL)
                        } label: {
                            HStack {
                                if isImporting {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text(isImporting ? "正在导入..." : "开始导入")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isImporting ? Color.gray : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(isImporting)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("导入词典")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: DictionaryImportService.shared.supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    selectedFileURL = urls.first
                case .failure(let error):
                    print("选择文件失败: \(error)")
                }
            }
        }
    }
    
    /// 导入模式说明
    private func importModeDescription(_ mode: DictionaryImportMode) -> String {
        switch mode {
        case .enhance:
            return "添加新词，已有词条会合并释义"
        case .overwrite:
            return "完全替换已有词条的释义"
        case .addOnly:
            return "只添加不存在的词条，跳过已有词条"
        }
    }
    
    /// 导入文件
    private func importFile(url: URL) {
        isImporting = true
        
        DictionaryImportService.shared.importDictionary(
            from: url,
            mode: importMode
        ) { result in
            isImporting = false
            onImportComplete(result)
            dismiss()
        }
    }
}

/// 词典格式说明弹窗
struct DictionaryFormatGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // JSON 格式示例
                    VStack(alignment: .leading, spacing: 12) {
                        Text("JSON 格式（推荐）")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("""
                        [
                          {
                            "word": "hello",
                            "phonetic": "həˈləʊ",
                            "partOfSpeech": "int.",
                            "definition": "你好；喂",
                            "example": "Hello, how are you?",
                            "frequency": 5,
                            "level": "CET4"
                          }
                        ]
                        """)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    // CSV 格式示例
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CSV 格式")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("""
                        word,phonetic,partOfSpeech,definition,example,frequency,level
                        hello,həˈləʊ,int.,你好；喂,Hello how are you,5,CET4
                        """)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    // TXT 格式示例
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TXT 格式（简单格式）")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("""
                        hello|həˈləʊ|int.|你好；喂|Hello how are you
                        """)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    // 字段说明
                    VStack(alignment: .leading, spacing: 12) {
                        Text("字段说明")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            fieldRow("word", "必填", "单词本身")
                            fieldRow("phonetic", "可选", "音标（美式）")
                            fieldRow("partOfSpeech", "可选", "词性（n./v./adj.等）")
                            fieldRow("definition", "必填", "中文释义，多个用分号分隔")
                            fieldRow("example", "可选", "例句")
                            fieldRow("frequency", "可选", "词频等级（1-5）")
                            fieldRow("level", "可选", "词汇等级（CET4/CET6/GRE）")
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    // 注意事项
                    VStack(alignment: .leading, spacing: 12) {
                        Text("注意事项")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 每个词条的释义会完整展示，建议用分号分隔多个释义")
                            Text("• CSV 格式中的释义如果包含逗号，请用双引号包裹")
                            Text("• TXT 格式使用竖线 | 分隔字段")
                            Text("• 音标建议使用 IPA 国际音标格式")
                            Text("• 导入大文件时可能需要一些时间，请耐心等待")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("词典格式说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func fieldRow(_ name: String, _ required: String, _ description: String) -> some View {
        HStack {
            Text(name)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.blue)
            
            Text(required)
                .font(.caption)
                .foregroundColor(required == "必填" ? .red : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(required == "必填" ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1))
                .cornerRadius(4)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

/// 词典导出弹窗
struct DictionaryExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: DictionaryFileFormat = .json
    @State private var isExporting: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 说明
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("导出自定义词典")
                        .font(.headline)
                    
                    Text("将您导入的自定义词条导出为文件，方便备份或分享")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // 词条数量显示
                VStack {
                    Text("当前自定义词条数量:")
                        .font(.subheadline)
                    
                    Text("\(DictionaryService.shared.getCustomEntryCount()) 条")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                // 格式选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择导出格式:")
                        .font(.headline)
                    
                    Picker("导出格式", selection: $selectedFormat) {
                        ForEach([DictionaryFileFormat.json, .csv, .txt], id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                
                // 导出按钮
                Button {
                    exportDictionary()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text(isExporting ? "正在导出..." : "导出并分享")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isExporting ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(isExporting || DictionaryService.shared.getCustomEntryCount() == 0)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("导出词典")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// 导出词典
    private func exportDictionary() {
        isExporting = true
        
        if let fileURL = DictionaryImportService.shared.exportCustomDictionary(format: selectedFormat) {
            isExporting = false
            
            // 分享文件
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let rootViewController = windowScene.windows.first?.rootViewController
                rootViewController?.present(activityVC, animated: true) {
                    dismiss()
                }
            }
        } else {
            isExporting = false
        }
    }
}
