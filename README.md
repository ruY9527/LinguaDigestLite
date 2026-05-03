# LinguaDigestLite

<p align="center">
  <img src="LinguaDigestLite/Resources/Assets.xcassets/AppIcon.appiconset/icon.png" alt="LinguaDigestLite Logo" width="120">
</p>

<p align="center">
  <strong>一款纯本地、原生沉浸式外刊阅读器 iOS 应用</strong>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#技术架构">技术架构</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#隐私说明">隐私说明</a>
</p>

---

## 功能特性

### 📰 RSS内容聚合
- **内置30+优质英语外刊RSS源**：BBC、The Guardian、NPR、MIT Technology Review、Nature、Scientific American、Harvard Business Review、The Economist 等
- **自定义订阅源**：支持用户手动添加RSS链接，或通过分享扩展导入
- **智能管理**：启用/禁用订阅源，设置更新频率
- **备注功能**：为订阅源添加自定义备注，方便管理

### 📖 沉浸式阅读体验
- **纯净排版**：简洁优雅的阅读界面，专注于内容本身
- **个性化设置**：
  - 字体大小调节（12-24pt）
  - 行间距调节（1.0-2.0倍）
  - 段间距调节
  - 页边距调整
- **主题切换**：日间模式、夜间模式、护眼模式
- **离线阅读**：文章缓存到本地，无网络也能阅读

### 🔍 即时查词
- **系统词典集成**：点击单词即可调用iOS系统词典查词
- **浮动释义卡片**：不打断阅读流程，快速查看释义
- **生词本添加**：一键添加到生词本，记录原文上下文

### 📚 生词本与学习
- **多分类支持**：生词可同时属于多个分类，方便从不同维度组织生词
- **分类管理**：
  - 7个默认分类：全部、科技、政治、经济、文化、日常、写作
  - 支持创建自定义分类文件夹
  - 10种颜色、20种图标可选
- **间隔重复算法（SRS）**：基于SM-2算法智能安排复习
- **掌握度追踪**：5级掌握程度（未学习 → 精通）
- **复习提醒**：本地通知提醒复习到期词汇
- **上下文记忆**：保存原文句子，加深记忆

### 🔤 本地离线词典
- **ECDICT集成**：内置英文词典，支持离线查词
- **多义词分组**：按词性分组展示释义，清晰明了
- **英文释义**：提供英文解释，助力沉浸式学习

### 🌐 翻译与理解
- **iOS 17.4+ 原生翻译**：长按选中句子，调用系统原生翻译（完全设备端执行，支持离线）
- **多翻译服务**：支持系统翻译、Google翻译、百度翻译、DeepL翻译
- **段落总结**：利用Apple Intelligence或第三方API

### 🎧 语音学习
- **TTS朗读**：使用AVSpeechSynthesizer进行文本朗读
- **语速调节**：0.5x - 2.0x 可调
- **多种音色**：美式/英式/澳式英语
- **跟读录音**：录音对比功能

---

## 技术架构

| 技术栈 | 说明 |
|--------|------|
| **开发语言** | Swift 5.9+ |
| **UI框架** | SwiftUI + UIKit (UITextView封装) |
| **架构模式** | MVVM |
| **数据存储** | SQLite + FileManager (纯本地) |
| **RSS解析** | 自定义XMLParser实现 |
| **NLP分析** | NaturalLanguage框架 |
| **词典数据** | ECDICT SQLite数据库 |
| **最低版本** | iOS 17.4+ (翻译功能) |

---

## 项目结构

```
LinguaDigestLite/
├── LinguaDigestLite/
│   ├── Models/
│   │   ├── Article.swift              # 文章模型
│   │   ├── Feed.swift                 # RSS源模型（含备注功能）
│   │   ├── Vocabulary.swift           # 生词模型（含SRS算法、多分类支持）
│   │   ├── VocabularyCategory.swift   # 生词分类模型
│   │   ├── ReadingSettings.swift      # 阅读设置
│   │   ├── RefreshLogEntry.swift      # 刷新日志模型
│   │   ├── SavedSentence.swift        # 收藏句子模型
│   │   └── DictionaryEntry.swift      # 词典条目模型
│   ├── Views/
│   │   ├── ArticleListView.swift      # 文章列表视图
│   │   ├── ReaderView.swift           # 沉浸式阅读器
│   │   ├── FeedListView.swift         # RSS源管理
│   │   ├── AddFeedSheetView.swift     # 添加订阅源
│   │   ├── VocabularyListView.swift   # 生词本（多分类管理）
│   │   ├── SettingsView.swift         # 设置页面
│   │   ├── RefreshLogView.swift       # 刷新日志查看
│   │   ├── SentenceDetailView.swift   # 句子详情
│   │   ├── ArticleReaderTextView.swift  # 阅读器文本视图（UIViewRepresentable）
│   │   ├── ReaderTextView.swift       # 自定义UITextView（长按菜单）
│   │   ├── CategoryViews.swift        # 分类列表与添加视图
│   │   ├── VocabularyRowView.swift    # 生词条目行视图
│   │   ├── SentenceRowView.swift      # 句子条目行视图
│   │   ├── ReviewView.swift           # 闪卡复习视图
│   │   ├── SentenceSaveSheet.swift    # 句子收藏表单
│   │   ├── SentenceTranslationSheet.swift # 翻译服务选择
│   │   ├── SystemDictionarySheetView.swift # 系统词典集成
│   │   ├── FontPickerView.swift       # 字体选择器
│   │   ├── ThemePickerView.swift      # 主题选择器
│   │   ├── VoicePickerView.swift      # 语音选择器
│   │   ├── VocabularyLevelPickerView.swift # 词汇等级选择器
│   │   ├── Components/
│   │   │   ├── ReaderMetaPill.swift   # 阅读器元数据胶囊标签
│   │   │   └── StatItem.swift         # 统计数据展示组件
│   │   └── DictionaryImport/
│   │       ├── DictionaryImportSheet.swift    # 词典导入界面
│   │       ├── DictionaryFormatGuideSheet.swift # 格式指南
│   │       └── DictionaryExportSheet.swift    # 词典导出界面
│   ├── ViewModels/
│   │   ├── ArticleViewModel.swift     # 文章数据管理
│   │   ├── FeedViewModel.swift        # RSS源数据管理
│   │   ├── VocabularyViewModel.swift  # 生词数据管理
│   │   ├── ReaderViewModel.swift      # 阅读器状态管理
│   │   ├── TextTranslationViewModel.swift # 文本翻译状态管理
│   │   └── SentenceViewModel.swift    # 句子数据管理
│   ├── Services/
│   │   ├── DatabaseManager.swift      # SQLite数据库初始化与迁移
│   │   ├── FeedStorage.swift          # RSS源 CRUD 操作
│   │   ├── ArticleStorage.swift       # 文章 CRUD 操作
│   │   ├── VocabularyStorage.swift    # 生词 CRUD 操作
│   │   ├── CategoryStorage.swift      # 分类 CRUD 操作
│   │   ├── SentenceStorage.swift      # 句子 CRUD 操作
│   │   ├── RefreshLogStorage.swift    # 刷新日志 CRUD 操作
│   │   ├── FeedService.swift          # RSS拉取服务
│   │   ├── RSSParser.swift            # XML解析器（XMLParserDelegate）
│   │   ├── HTMLContentExtractor.swift # HTML内容提取（BBC/Guardian/NPR等）
│   │   ├── HTMLEntityDecoder.swift    # HTML实体解码器
│   │   ├── DictionaryService.swift    # ECDICT词典查询服务
│   │   ├── DictionaryDatabaseManager.swift # 词典数据库管理
│   │   ├── DictionaryDownloadService.swift # 词典下载服务
│   │   ├── DictionaryImportService.swift  # 词典导入服务
│   │   ├── TranslationService.swift   # 翻译服务
│   │   ├── NotificationService.swift  # 本地通知服务
│   │   └── SpeechService.swift        # TTS/录音服务
│   ├── Utils/
│   │   ├── SQLiteHelper.swift         # SQLite辅助工具
│   │   └── L10n.swift                 # 国际化辅助
│   ├── Resources/
│   │   ├── Assets.xcassets/           # 应用图标和颜色资源
│   │   ├── en.lproj/                  # 英文本地化
│   │   └── zh-Hans.lproj/             # 中文本地化
│   ├── LinguaDigestLiteApp.swift      # 应用入口
│   └── Info.plist                     # 应用配置
├── LinguaDigestLite.xcodeproj/        # Xcode项目文件
├── sql/
│   └── schema.sql                     # 数据库Schema
├── download/                          # 词典下载缓存
└── README.md
```

---

## 快速开始

### 环境要求
- macOS 14.0+
- Xcode 15.0+
- iOS 17.4+ 设备或模拟器 (翻译功能需要)

### 编译运行

1. **克隆仓库**
   ```bash
   git clone https://github.com/yourusername/LinguaDigestLite.git
   cd LinguaDigestLite
   ```

2. **打开项目**
   ```bash
   open LinguaDigestLite.xcodeproj
   ```

3. **运行应用**
   - 选择目标设备（模拟器或真机）
   - 点击运行按钮 (⌘R) 或选择 Product > Run

---

## 内置RSS源列表

应用预置了以下优质英语外刊RSS源：

| 类别 | 来源 |
|------|------|
| **科技** | BBC Technology, The Guardian Tech, NPR Tech, MIT Tech Review, Ars Technica, Wired, TechCrunch |
| **科学** | Science Daily, Nature, Scientific American |
| **商业** | Harvard Business Review, The Economist |
| **世界新闻** | BBC World, NPR World, The Guardian World |
| **文化** | NPR Culture, The Guardian Books, Smithsonian Magazine |
| **健康** | NPR Health, BBC Health |
| **环境** | The Guardian Environment |
| **政治** | NPR Politics |
| **体育** | BBC Sport |
| **艺术** | The Guardian Art and Design |
| **旅行** | BBC Travel |
| **未来** | BBC Future |
| **心理** | Psychology Today |

---

## 核心功能详解

### 生词本分类系统

支持创建自定义分类文件夹管理生词：
- **多分类支持**：每个生词可同时属于多个分类
- **默认分类**：全部、科技、政治、经济、文化、日常、写作
- **自定义创建**：自定义名称、描述、颜色和图标
- **分类统计**：查看各分类下的生词数量
- **灵活切换**：快速在不同分类间切换

### SRS间隔重复算法

采用经典的 **SM-2 算法** 智能安排复习：
```
复习质量评分 (0-5):
0 = 完全忘记
1 = 错误但感觉熟悉
2 = 错误但记得意思
3 = 正确但费劲
4 = 正确略有迟疑
5 = 完美回忆

间隔计算:
- 第1次: 1天
- 第2次: 6天
- 之后: interval = previous_interval × ease_factor
```

### 阅读主题

| 主题 | 背景色 | 适用场景 |
|------|--------|----------|
| 日间模式 | 纯白 | 日间阅读 |
| 夜间模式 | 深灰 | 夜间护眼 |
| 护眼模式 | 米黄色 | 长时间阅读 |

---

## 隐私说明

LinguaDigestLite 是一款**纯本地应用**，高度重视用户隐私：

- ✅ **无用户注册**：无需账户，打开即用
- ✅ **纯本地存储**：所有数据存储在用户设备上
- ✅ **无后端服务器**：应用不经过任何中间服务器
- ✅ **用户控制API**：如需使用AI功能，用户自行配置API Key直接调用第三方服务
- ✅ **数据不上传**：阅读记录、生词本、笔记等敏感数据永不离开设备

---

## 未来计划

- [ ] iCloud 同步支持
- [ ] 更多阅读主题
- [ ] 生词自动高亮（基于词汇等级）
- [ ] 长难句语法解析
- [ ] 用户自定义 API Key (OpenAI/DeepL)
- [ ] iPad 优化适配
- [ ] Widget 快捷入口
- [ ] Apple Watch 生词复习

---

## 最近更新

### v1.4.0 (2026-05-03) - 代码架构优化

对5个超大文件进行拆分重构，提升代码可维护性和可读性：

| 文件 | 重构前 | 重构后 | 缩减 |
|------|--------|--------|------|
| SettingsView.swift | 1083行 | ~501行 | -54% |
| FeedService.swift | 1249行 | ~203行 | -84% |
| VocabularyListView.swift | 1502行 | ~458行 | -69% |
| ReaderView.swift | 1685行 | ~419行 | -75% |
| DatabaseManager.swift | 1012行 | ~230行 | -77% |

**新增27个文件：**

- **Services层拆分**：DatabaseManager 的 CRUD 操作按实体拆分为独立文件（FeedStorage、ArticleStorage、VocabularyStorage、CategoryStorage、SentenceStorage、RefreshLogStorage），DatabaseManager 仅保留初始化与迁移逻辑
- **FeedService拆分**：RSS解析逻辑提取为 RSSParser，HTML内容提取独立为 HTMLContentExtractor，HTML实体解码独立为 HTMLEntityDecoder
- **Views层拆分**：ReaderView 的 UIViewRepresentable 封装、系统词典、句子保存/翻译等Sheet拆分为独立文件；VocabularyListView 的分类管理、条目行视图、复习视图独立提取；SettingsView 的字体/主题/语音/词汇等级选择器及词典导入相关视图独立提取
- **组件化**：新增 Components/ 目录存放可复用UI组件（StatItem、ReaderMetaPill），新增 DictionaryImport/ 目录存放词典导入相关视图
- **Xcode项目同步**：所有新文件已添加到 .pbxproj 构建目标

### v1.3.0 (2026-05-03)
- ✨ **原生句子翻译**：长按选中句子，调用 iOS 17.4+ 系统原生翻译（完全设备端，支持离线）
- ✨ 多翻译服务支持：系统翻译、Google翻译、百度翻译、DeepL翻译
- 🔧 重构翻译功能代码，翻译逻辑与阅读器解耦

### v1.2.0 (2026-05-03)
- ✨ 生词本多分类支持：生词可同时属于多个分类
- ✨ ECDICT离线词典集成，支持离线查词和多义词分组
- ✨ 新增刷新日志功能，可查看RSS源更新历史
- ✨ 优化文章列表空状态显示
- 🐛 修复生词分类切换时数据刷新的问题

### v1.1.0 (2026-04-24)
- ✨ 新增生词本分类功能，支持自定义分类文件夹
- ✨ 新增RSS源备注功能，用户可为订阅源添加自定义备注
- 🐛 修复SettingsView中语音速度滑块绑定错误
- 🐛 修复FontPickerView中nil字体处理
- 🐛 修复SpeechService中录音文件路径字符串插值错误

---

## 许可证

MIT License

---

## 致谢

感谢以下优秀的RSS源提供者：
- [BBC News](https://www.bbc.co.uk/news)
- [The Guardian](https://www.theguardian.com/)
- [NPR](https://www.npr.org/)
- [MIT Technology Review](https://www.technologyreview.com/)
- [Nature](https://www.nature.com/)
- [Harvard Business Review](https://hbr.org/)
- 以及所有其他列出的内容提供商

---

<p align="center">
  Made with ❤️ for language learners
</p>