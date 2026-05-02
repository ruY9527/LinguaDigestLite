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
            .navigationTitle(L("nav.settings"))
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
            .alert(L("alert.importResult"), isPresented: $showingImportResult) {
                Button(L("common.ok"), role: .cancel) {}
            } message: {
                Text(importResult?.summary ?? L("alert.importComplete"))
            }
            .alert(L("alert.confirmClear"), isPresented: $showingClearConfirmation) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("common.clear"), role: .destructive) {
                    DictionaryService.shared.clearCustomEntries()
                }
            } message: {
                Text(L("alert.clearCustomDictMsg"))
            }
        }
    }
    
    /// 阅读设置部分
    private var readingSettingsSection: some View {
        Section(L("section.reading")) {
            // 字体大小
            VStack(alignment: .leading, spacing: 8) {
                Text(L("setting.fontSize"))
                
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
                Text(L("setting.lineSpacing"))
                
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
            Stepper(String(format: L("setting.paragraphSpacing"), Int(userSettings.readingSettings.paragraphSpacing)), value: $userSettings.readingSettings.paragraphSpacing, in: 8...24)
            
            // 边距
            Stepper(String(format: L("setting.pageMargin"), Int(userSettings.readingSettings.marginSize)), value: $userSettings.readingSettings.marginSize, in: 8...32)
            
            // 字体选择
            NavigationLink {
                FontPickerView(selectedFont: $userSettings.readingSettings.fontName)
            } label: {
                HStack {
                    Text(L("setting.font"))
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
                    Text(L("setting.readingTheme"))
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
        Section(L("section.tts")) {
            NavigationLink {
                VoicePickerView()
            } label: {
                HStack {
                    Text(L("setting.voice"))
                    Spacer()
                    Text(L("setting.americanEnglish"))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("setting.speechRate"))
                
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
        Section(L("section.learning")) {
            // 自动高亮生词
            Toggle(L("setting.autoHighlight"), isOn: $userSettings.readingSettings.autoHighlightNewWords)
            
            // 显示音标
            Toggle(L("setting.showPhonetic"), isOn: $userSettings.readingSettings.showPhonetic)
            
            // 词汇等级
            NavigationLink {
                VocabularyLevelPickerView(selectedLevel: $userSettings.readingSettings.vocabularyLevel)
            } label: {
                HStack {
                    Text(L("setting.vocabLevel"))
                    Spacer()
                    Text(userSettings.readingSettings.vocabularyLevel.displayName)
                        .foregroundColor(.secondary)
                }
            }
            
            // 每日复习提醒
            Toggle(L("setting.dailyReminder"), isOn: Binding(
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
                    L("setting.reminderTime"),
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
                    Text(L("setting.todayReview"))
                    Spacer()
                    let reviewCount = DatabaseManager.shared.fetchTodayReviewVocabulary(for: nil).count
                    Text(String(format: L("setting.reviewCountSuffix"), reviewCount))
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
                        Text(L("action.sendTestReminder"))
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    /// ECDICT 完整词典部分
    private var ecdictDictionarySection: some View {
        Section(L("section.ecdict")) {
            // 状态显示
            HStack {
                Text(L("setting.dictStatus"))
                Spacer()
                if DictionaryDatabaseManager.shared.isECDICTAvailable {
                    Text(L("status.ready"))
                        .foregroundColor(.green)
                } else {
                    Text(L("status.notFound"))
                        .foregroundColor(.orange)
                }
            }

            // 词条数量
            if DictionaryDatabaseManager.shared.isECDICTAvailable {
                HStack {
                    Text(L("setting.entryCount"))
                    Spacer()
                    Text(String(format: L("setting.entryCountSuffix"), DictionaryDatabaseManager.shared.ecdictEntryCount))
                        .foregroundColor(.secondary)
                }
            }

            // 说明
            Text(L("setting.ecdictDesc"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// 词典导入部分
    private var dictionaryImportSection: some View {
        Section(L("section.dictManagement")) {
            // 当前自定义词条数量
            HStack {
                Text(L("setting.customEntries"))
                Spacer()
                Text(String(format: L("setting.entryCountSuffix"), DictionaryService.shared.getCustomEntryCount()))
                    .foregroundColor(.secondary)
            }

            // 导入模式选择
            Picker(L("setting.importMode"), selection: $selectedImportMode) {
                ForEach(DictionaryImportMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            
            // 导入词典按钮
            Button {
                showingDictionaryImport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text(L("action.importDict"))
                }
            }
            
            // 导出词典按钮
            Button {
                showingExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(L("action.exportCustomDict"))
                }
            }
            .disabled(DictionaryService.shared.getCustomEntryCount() == 0)
            
            // 格式说明
            Button {
                showingImportFormatGuide = true
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text(L("action.dictFormatInfo"))
                }
            }
            
            // 清除自定义词条
            Button {
                showingClearConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(L("action.clearCustomEntries"))
                }
                .foregroundColor(.red)
            }
            .disabled(DictionaryService.shared.getCustomEntryCount() == 0)
            
            // 下载示例文件
            VStack(alignment: .leading, spacing: 12) {
                Text(L("section.downloadSample"))
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
        Section(L("section.about")) {
            HStack {
                Text(L("setting.version"))
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(L("setting.appName"))
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
                Text(L("action.resetAll"))
                    .foregroundColor(.red)
            }
        }
    }
    
    /// 字体显示名称
    private var fontDisplayName: String {
        if let fontName = userSettings.readingSettings.fontName {
            return ReadingSettings.standardFonts.first { $0.value == fontName }?.key ?? L("custom.font")
        }
        return L("default.font")
    }

    /// 朗读速度描述
    private var speechRateDescription: String {
        let rate = userSettings.readingSettings.speechRate
        if rate < 0.4 {
            return L("speed.slow")
        } else if rate < 0.55 {
            return L("speed.medium")
        } else if rate < 0.7 {
            return L("speed.fast")
        } else {
            return L("speed.veryFast")
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
        .navigationTitle(L("nav.selectFont"))
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
        .navigationTitle(L("nav.selectTheme"))
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
        .navigationTitle(L("nav.selectVoice"))
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
        .navigationTitle(L("setting.vocabLevel"))
    }
    
    /// 等级描述
    private func levelDescription(_ level: VocabularyLevel) -> String {
        switch level {
        case .beginner:
            return L("level.beginner")
        case .elementary:
            return L("level.elementary")
        case .intermediate:
            return L("level.intermediate")
        case .advanced:
            return L("level.advanced")
        case .expert:
            return L("level.expert")
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
                    
                    Text(L("sheet.importDict"))
                        .font(.headline)

                    Text(L("sheet.importDesc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // 导入模式说明
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: L("sheet.importModeLabel"), importMode.rawValue))
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
                        Text(L("action.selectFile"))
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
                        Text(L("label.selectedFile"))
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
                                Text(isImporting ? L("action.importing") : L("action.startImport"))
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
            .navigationTitle(L("nav.importDict"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
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
            return L("importMode.merge")
        case .overwrite:
            return L("importMode.overwrite")
        case .addOnly:
            return L("importMode.addOnly")
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
                        Text(L("format.json"))
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
                        Text(L("format.csv"))
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
                        Text(L("format.txt"))
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
                        Text(L("section.fieldDesc"))
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            fieldRow("word", L("field.required"), L("field.word"))
                            fieldRow("phonetic", L("field.optional"), L("field.phonetic"))
                            fieldRow("partOfSpeech", L("field.optional"), L("field.pos"))
                            fieldRow("definition", L("field.required"), L("field.definition"))
                            fieldRow("example", L("field.optional"), L("field.example"))
                            fieldRow("frequency", L("field.optional"), L("field.frequency"))
                            fieldRow("level", L("field.optional"), L("field.level"))
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    // 注意事项
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("section.notes"))
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("note.fullDefinition"))
                            Text(L("note.csvQuotes"))
                            Text(L("note.txtSeparator"))
                            Text(L("note.ipaPhonetic"))
                            Text(L("note.largeFileWait"))
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle(L("action.dictFormatInfo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
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
                .foregroundColor(required == L("field.required") ? .red : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(required == L("field.required") ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1))
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
                    
                    Text(L("action.exportCustomDict"))
                        .font(.headline)
                    
                    Text(L("sheet.exportDesc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // 词条数量显示
                VStack {
                    Text(L("label.customEntryCount"))
                        .font(.subheadline)
                    
                    Text(String(format: L("setting.entryCountSuffix"), DictionaryService.shared.getCustomEntryCount()))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                // 格式选择
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("label.exportFormat"))
                        .font(.headline)

                    Picker(L("setting.exportFormat"), selection: $selectedFormat) {
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
                        Text(isExporting ? L("action.exporting") : L("action.exportAndShare"))
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
            .navigationTitle(L("nav.exportDict"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
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
