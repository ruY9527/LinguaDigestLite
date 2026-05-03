//
//  ReviewView.swift
//  LinguaDigestLite
//
//  Extracted from VocabularyListView.swift
//

import SwiftUI

/// 复习视图
struct ReviewView: View {
    @ObservedObject var viewModel: VocabularyViewModel

    @State private var showingAnswer: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 进度指示
                progressHeader

                // 单词卡片
                wordCard

                // 评分按钮
                ratingButtons
            }
            .padding()
            .navigationTitle(L("nav.review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.endReview()
                    } label: {
                        Text(L("action.end"))
                    }
                }
            }
        }
    }

    /// 进度头部
    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text(String(format: L("review.progress"), viewModel.reviewCompletedCount, viewModel.todayReviewWords.count))
                .font(.headline)

            ProgressView(value: Double(viewModel.reviewCompletedCount), total: Double(viewModel.todayReviewWords.count))
                .progressViewStyle(.linear)
        }
    }

    /// 单词卡片
    private var wordCard: some View {
        VStack(spacing: 16) {
            if let word = viewModel.currentReviewWord {
                // 单词（正面）- 可点击显示答案
                Button {
                    showingAnswer = true
                } label: {
                    Text(word.word)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // 提示文字
                if !showingAnswer {
                    Text(L("review.tapToSeeDef"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 音标
                if let phonetic = word.phonetic {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                // 朗读按钮
                Button {
                    viewModel.speakWord(word.word)
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }

                Divider()
                    .padding(.vertical, 8)

                // 答案（背面）
                if showingAnswer {
                    VStack(alignment: .leading, spacing: 8) {
                        // 词性
                        if let pos = word.partOfSpeech, !pos.isEmpty {
                            Text(DictionaryService.displayNameForPartOfSpeech(pos))
                                .font(.subheadline)
                                .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(pos)))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(6)
                        }

                        // 释义 - 按词性分组展示
                        Text(L("section.definitionLabel"))
                            .font(.headline)

                        if let grouped = word.groupedDefinitions, !grouped.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(grouped.enumerated()), id: \.offset) { groupIndex, group in
                                    VStack(alignment: .leading, spacing: 6) {
                                        if groupIndex > 0 {
                                            Divider()
                                        }
                                        Text(DictionaryService.displayNameForPartOfSpeech(group.pos))
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)).opacity(0.15))
                                            .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)))
                                            .cornerRadius(4)

                                        ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, def in
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("\(index + 1).")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(.blue)
                                                    .frame(minWidth: 20, alignment: .trailing)
                                                Text(def)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else if let savedDef = word.definition, !savedDef.isEmpty {
                            definitionListView(savedDef)
                        } else if let offlineDef = DictionaryService.shared.getDefinition(for: word.word) {
                            definitionListView(offlineDef)
                        } else {
                            Text(L("review.noDef"))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        // 英文释义
                        if let englishDef = word.englishDefinition, !englishDef.isEmpty {
                            let normalizedDef = englishDef.replacingOccurrences(of: "\\n", with: "\n")
                            Text(L("section.englishDefLabel"))
                                .font(.headline)
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(normalizedDef)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 100)
                        }
                        // 原文上下文
                        if let context = word.contextSnippet, !context.isEmpty {
                            Text(L("section.originalLabel"))
                                .font(.headline)
                            Text(context)
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button {
                        showingAnswer = true
                    } label: {
                        Text(L("action.showAnswer"))
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            } else {
                Text(L("review.completed"))
                    .font(.title)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    /// 评分按钮
    private var ratingButtons: some View {
        Group {
            if showingAnswer && viewModel.currentReviewWord != nil {
                VStack(spacing: 12) {
                    Text(L("review.ratePrompt"))
                        .font(.headline)

                    HStack(spacing: 8) {
                        ForEach([0, 1, 2, 3, 4, 5], id: \.self) { quality in
                            Button {
                                viewModel.completeCurrentReview(quality: quality)
                                showingAnswer = false
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(quality)")
                                        .font(.title3)
                                        .fontWeight(.bold)

                                    Text(ratingDescription(quality))
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .frame(width: 50, height: 60)
                                .background(ratingColor(quality))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if viewModel.currentReviewWord == nil {
                // 复习完成
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text(L("review.allDone"))
                        .font(.title2)

                    Button {
                        viewModel.endReview()
                    } label: {
                        Text(L("action.backToVocab"))
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            } else {
                // 跳过按钮
                Button {
                    viewModel.skipCurrentReview()
                    showingAnswer = false
                } label: {
                    Text(L("common.skip"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// 评分描述
    private func ratingDescription(_ quality: Int) -> String {
        switch quality {
        case 0: return L("rating.forget")
        case 1: return L("rating.familiar")
        case 2: return L("rating.barely")
        case 3: return L("rating.correct")
        case 4: return L("rating.easy")
        case 5: return L("rating.perfect")
        default: return ""
        }
    }

    /// 评分颜色
    private func ratingColor(_ quality: Int) -> Color {
        switch quality {
        case 0: return .red.opacity(0.2)
        case 1: return .red.opacity(0.3)
        case 2: return .orange.opacity(0.3)
        case 3: return .yellow.opacity(0.3)
        case 4: return .green.opacity(0.3)
        case 5: return .blue.opacity(0.3)
        default: return .gray.opacity(0.2)
        }
    }

    private func definitionListView(_ definition: String) -> some View {
        let items = DictionaryService.shared.splitDefinitions(definition)
        return Group {
            if items.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.blue)
                                .frame(minWidth: 20, alignment: .trailing)
                            Text(item)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(definition)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
