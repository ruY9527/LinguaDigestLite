## 一、重新定位：纯本地 · 原生沉浸式外刊阅读器
**产品名称（不变）**：LinguaDigestLite  
**核心转变**：从“平台聚合”转为“个人RSS阅读器 + 本地学习工具箱”。  
**核心价值**：你自主订阅外刊源 → App为你提供纯净排版、即时查词、全文翻译、语法学习、生词本等的阅读增强层，所有数据都在手机里，没有任何请求离开设备（除非直接获取文章原网页和调取第三方API，但由用户直接配置，非经过我们的服务器）。

## 二、第一版功限定与说明

- **内容获取**：App 内置知名外刊RSS源（或用户自行添加，存于本地），直接在设备上解析RSS/抓取原文，不经过任何中间服务器。
    
- **用户系统**：无需注册，所有数据本地存储。
    
- **跨设备同步**：无服务器同步，可在后续版本通过 iCloud 同步本地数据库文件。
    
- **AI功能**：通过集成苹果原生智能（Apple Intelligence 写作工具/翻译）、Core ML 本地模型、或让用户自带API Key（如 OpenAI、DeepL）来调用云端AI（直接由 App 到第三方 API，不经我们中转）。
    
- **词典**：完全本地离线词典 + iOS 系统词典。
## 三、核心功能模块（纯本地实现）
### 1. 内容获取与聚合

**实现方式**：

- **本地RSS引擎**：使用 Swift 中基于 `Foundation` 的 XMLParser 解析 RSS 2.0 / Atom，或使用成熟开源库如 `FeedKit`，直接抓取订阅源。
    
- **内置精选源库**：预置约30个优质英语外刊RSS（含《The Guardian》公开板块、《BBC News》、《NPR》、《Science Daily》、《Harvard Business Review》公开部分、《经济学人》部分摘要等）。用户可选择开启哪些。
    
- **手动添加**：用户输入RSS链接，或共享网页到App时，App尝试寻找页面内的RSS链接并添加。
    
- **原文全文提取**：
    
    - 对于摘要型RSS，利用 `WKWebView` 后台加载原文链接，并注入 JavaScript（Mozilla Readability 精简版，或自己实现的提取概括逻辑）提取正文内容。
        
    - 更简单且保护隐私：直接以 `SFSafariViewController` 展示原网页的 Reader 模式（Safari阅读模式），但这脱离了App内阅读器。我们仍希望导入到本地数据库，故采用 **`WKWebView` 离线抓取 + JS 脚本提取正文**，提取完成后文章存入本地数据库，用户阅读时完全离线。
        
    - 注意JS提取过程在后台 `WKWebView`（非界面显示）中运行，需注意内存和超时控制。
### 2. 沉浸式阅读器

- **渲染引擎**：使用 `UITextView` / `UITextKit` 进行富文本排版，或采用 `SwiftUI` 的 `Text` + `AttributedString`（但性能需测试）。 为支持大量交互（点击单词、高亮），建议**封装 `UIViewRepresentable` 包装 `UITextView`**，利用 `NSTextAttachment` 处理图片。
    
- **字体与定制**：嵌入经典英文字体（如 Charter, Georgia, Lora），支持动态字号以及行距、段距、边距调整，数据存 `UserDefaults`。
    
- **主题**：日间/夜间/护眼黄纸模式，影响背景色和字体颜色。
    
- **自动分页**：可选滚动/翻页模式，翻页基于 `UIPageViewController` 或手动计算高度切片。

### 3. 迅捷查词与词典

- **系统词典**：在可选择的文本上使用 `UIMenuController` 或 SwiftUI 的 `.contextMenu` 提供“查询”按钮，调用 `UIReferenceLibraryViewController` 展示苹果内置词典（牛津、英汉等）。
    
- **离线词典集成**：嵌入开源离线词库（如 `ecdict`、stardict 等），本地 SQLite 数据库存储，在阅读时点击单词弹出浮动窗，显示音标、释义、例句。使用 `FMDB` 或 `GRDB` 快速查询。
    
- **查词触发**：长按或点击单词时，通过 `UITextView` 的文本布局定位点击单词，查找本地词库展示。
    

### 4. 翻译与句子理解

**无服务器如何做到翻译？**

- **苹果内置翻译**（iOS 17.4+）：利用 `TranslationUI` 或 `NaturalLanguage` 框架的翻译功能，完全在设备端执行，支持系统语言间翻译。可在选中句子后触发，原汁原味离线翻译。
    
- **用户自定义翻译服务**：在设置中允许用户输入自己的 DeepL API Key 或 OpenAI API Key，App 直接向这些第三方 API 发送请求，不经我们服务器。API Key 加密存储在 Keychain。
    
    - 使用 DeepL / OpenAI 时，提示用户需自担费用和隐私。
        
- **句子结构解析（Grammar highlighting）**：
    
    - 采用苹果 **NaturalLanguage** 框架：`NLTagger` 可进行词性标注、识别句子边界、词元分析等。
        
    - 可标记名词短语、动词短语、从句尝试提取（虽然苹果NLP不直接给出句法树，但可以做简化分析）。
        
    - 若要真正解释长难句，只能通过用户配置的 GPT API 来做“语法解释”（仍是直接请求OpenAI，无后端）。
        
- **段落总结**：同样可由 Apple Intelligence 本地写作工具（若设备支持）调用 Summarize，或依靠 GPT API。
### 5. 生词本与间隔重复

- **纯本地存储**：使用 `Core Data` 或 `GRDB` 存储生词表，每个生词关联原文句子和来源文章。
    
- **SRS算法**：实现类似 Anki 的 SM-2 算法，本地计算下次复习时间，生成每日复习任务。
    
- **推送提醒**：用 `UserNotifications` 发送本地通知提醒复习。
    
- **复习界面**：卡片式，正面英文+发音，背面释义+原文例句，手势评价熟悉度。
    

### 6. 智能辅助阅读模式（本地NLP）

- **生词高亮**：根据用户设定的词汇等级（如牛津3000词外、四级/六级等）或内置分级词表，在渲染文章时，将该文章中超出范围的单词用下划线/背景高亮标出，点击可释义。
    
- **语法敏感高亮**：利用 `NLTagger` 识别各类词组（介词短语、动词短语、从句引导词等），用不同颜色标记，帮助读者快速识别句子骨架。
### 7. 文本语音 (TTS) 与跟读

- **系统TTS**：使用 `AVSpeechSynthesizer`，可设置音调、语速，选美/英/澳音色，完全离线。
    
- **跟读训练**：选择段落播放，用户点击录音，使用 `AVAudioRecorder` 录音后，可在本地对比音频波形（简易对比或分析基频）。不需上传，本地处理。
    

### 8. 数据管理

- **所有数据**：文章缓存、生词本、阅读进度、笔记、设置均存本地 SQLite（`GRDB`）或 `Core Data`。
    
- **iCloud 同步（可选后期）**：Core Data + CloudKit 可轻松实现多设备同步，完全无需管理服务器，且端到端加密。

## 四、纯客户端技术栈详述
### 1. 开发语言与UI

- Swift 5.9+，主框架 **SwiftUI**，部分复杂交互（阅读器核心）使用 `UIViewRepresentable` 嵌入 UIKit `UITextView`。
    
- 架构：**MVVM** + Combine，管理数据流。
    
- 导航：SwiftUI `NavigationStack` + 自定义 Router。
    

### 2. 本地存储

- **GRDB**（推荐）：高性能 SQLite 封装，支持 Combine 发布者，适合文章、生词等复杂关系查询。
    
- **Core Data**：若希望未来无缝启用 CloudKit 同步，可直接使用 Core Data（配合 `NSPersistentCloudKitContainer`）。前期开发稍慢但同步成本低。
    

### 3. RSS与全文抓取

- **FeedKit**：纯 Swift 解析 RSS/Atom/JSON Feed。
    
- **SwiftSoup**：用于解析 HTML、提取正文时分析 DOM。
    
- **WKWebView (hidden)**：加载文章原始 URL，注入 Readability.js 后获取处理后的 HTML 文本，再转回纯文本/基本 Markdown 存储。
    
    - 注意：需在后台 Task 中完成，限制并发数量；提取后关闭webview。
        
- **文章去重与更新**：对比文章 URL 或 GUID，避免重复缓存。
### 4. 词典与 NLP

- **UIReferenceLibraryViewController**：系统词典查询。
    
- **本地词库**：集成 `stardict` 或 `ECDICT`（开源英汉词典），转成 SQLite 数据库后放入 Bundle，通过 `GRDB` 查询。数据较大需考虑压缩或按需加载。
    
- **NaturalLanguage**：用于词性标注、语言识别、句子边界检测，构建语法高亮。
    
- **TranslationUI / TranslationSession**（iOS 17.4+）：系统离线翻译，避免网络请求。
    

### 5. 朗读与录音

- **AVSpeechSynthesizer**：系统TTS。
    
- **AVAudioRecorder** + **AVAudioPlayer**：录音与回放。
    
- 语音对比简要实现：提取录音和标准音频的基频曲线（使用 `AVAudioPCMBuffer` 分析），简易可视化，不需机器学习。
    

### 6. 可选AI集成（直连第三方API）

- **OpenAI**：用户提供 Key，App 直连 `api.openai.com`，进行句子解释、摘要等。使用 `URLSession` 异步请求，不经过其他服务器。
    
- **DeepL**：同样直连，进行翻译（高质量）。
    
- **Keychain**：用 `KeychainAccess` 或 `Security` 框架安全存储API Key。
    
- **本地提示模板**：内置精心设计的 Prompt，可通过 App 内编辑，让用户自定义“语法解析”风格。
### 7. 安全与隐私

- 所有网络请求（抓取文章、查翻译）均从设备直接发出，除必备的第三方 API 调用外无任何数据外传。
    
- 用户数据全本地，不上传任何使用者行为。
    
- 提供给用户的RSS源列表硬编码在App内，可动态更新（如通过 GitHub gist 定期下载一个源列表 JSON，但也算网络请求，可设计为手动刷新，不经常做，且直接从 GitHub 下载，非我们控制）。
## 五、特色实现细节（纯客户端）
### 1. “点击查词不打断阅读” 的浮动窗

- 重写 `UITextView` 的点击手势，利用 `layoutManager` 和 `textContainer` 找到点击字符，通过 `tokenizer` 确定单词范围。
    
- 在单词上方展示一个自定义 `UIHostingController` 控制的 SwiftUI 浮动卡片，毛玻璃效果，显示离线词库释义。点击外部消失。
    
- 卡片底部有“朗读”“加入生词本”等按钮。
    

### 2. 语法高亮的渲染性能

- 文本内容在后台用 `NLTag` 标注，生成 `[NSRange: GrammarType]` 映射。
    
- 构建 `NSAttributedString` 时，给对应范围添加 `.underlineColor` 和 `.underlineStyle` 等，或使用自定义属性渲染装饰线（利用 `NSLayoutManager` 的 `drawUnderline` 重载）。为避免长文阻塞主线程，将标注和分析放在 `DispatchQueue.global` 中分批执行，渲染时分页。
    

### 3. 文章缓存与离线阅读

- 第一次点击文章时，触发抓取全文（如果 RSS 无全文）。使用 `URLSession` 下载 HTML，在后台 `WKWebView` 执行提取脚本，获得纯内容、图片 URL 列表。
    
- 下载所有图片（`Kingfisher` 或手动缓存）存储到本地文件系统。
    
- 将处理后的 Markdown 或 HTML 片段存入数据库，之后阅读完全离线。
### 4. 无 AI 情况下的智能生词提取

- 预置《牛津3000词》《学术词汇表》等文本列表，属于本地的 `Set<String>`。
    
- 对文章进行 tokenization 和词形还原（`NLTag`），过滤掉已知词，提取出低频词即为生词候选，展示时自动高亮。
## 六、第一版开发路线图（纯本地）

**阶段一 核心阅读体验**

- 搭建 SwiftUI 主框架，实现 RSS 源管理（内置 + 添加）。
    
- XML 解析拉取列表，进入文章以`SFSafariViewController`临时阅读（降级方案），同时后台抓取全文存储。
    
- 实现简单阅读器（UITextView），支持字体大小、主题切换。
    
- 系统词典 + 本地离线词库基础查词（弹出系统 UIReferenceLibraryViewController）。
    

**阶段二 学习功能**

- 生词本（Core Data/GRDB），生词添加、SRS复习卡片。
    
- 离线翻译（iOS 17.4+ 内置翻译）选中句子翻译。
    
- 语音朗读（AVSpeechSynthesizer）与跟读录音对比简易版。
    
- 根据词表生词自动高亮。
    

**阶段三 高质量自选AI集成**

- 用户API Key设置，直连 OpenAI 进行句子解释/段落摘要，支持流式输出。
    
- 键盘/菜单中的“Explain grammar”按钮。
    
- 优化全文抓取成功率，处理 JavaScript-heavy 网站。
    

**阶段四（持续打磨）- 体验优化与同步**

- 动态字体与 iPad 适配。
    
- iCloud 同步（通过 Core Data）。
    
- 阅读统计本地图表。

## 七、需要留意的挑战及对策

- **抓取全文稳定性**：不同网站反爬，JS注入可能被阻。对策：主要依赖开放 RSS 源全文输出；对于只有摘要的，提供“在 Safari 中打开”按钮作为后备；并努力为主流大站编写专门的提取规则（如 The Guardian 开放文章结构清晰）。
    
- **离线词典体积**：高质量英汉词典可能上百MB。第一版可先用系统词典 + 精简词库（只包含释义，无例句），后续可选下载完整词库。
    
- **iOS版本依赖**：内置离线翻译需 iOS 17.4+，可降级为使用用户自己的第三方API或系统翻译（在线）。指定最低支持 iOS 16，通过条件判断提供。
    
- **无后端更新源列表**：RSS源有时会失效，第一版可允许用户手动编辑或共享从网上找到的新源。未来通过一个公开的 GitHub 仓库存放推荐源 JSON，App 定期（用户允许时）从 GitHub 直接拉取更新，不依赖自建服务。