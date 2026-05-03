//
//  SentenceRowView.swift
//  LinguaDigestLite
//
//  Extracted from VocabularyListView.swift
//

import SwiftUI

/// 句子行视图
struct SentenceRowView: View {
    let sentence: SavedSentence
    let categories: [VocabularyCategory]
    let onSpeak: () -> Void
    let onJumpToSource: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        // 句子文本
                        Text(sentence.sentence)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)

                        // 翻译
                        if let translation = sentence.translation, !translation.isEmpty {
                            Text(translation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(isExpanded ? nil : 2)
                        }

                        // 来源和分类
                        HStack(spacing: 8) {
                            if let title = sentence.articleTitle {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                    Text(title)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .foregroundColor(.secondary)
                            }

                            if !categories.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(Array(categories.prefix(2)), id: \.id) { category in
                                        Text(category.name)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: category.color).opacity(0.15))
                                            .foregroundColor(Color(hex: category.color))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }

                        if !isExpanded {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.down.circle")
                                    .foregroundColor(.secondary)
                                Text(L("vocab.showDef"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .buttonStyle(.plain)

                // 发音按钮
                Button {
                    onSpeak()
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // 展开内容
            if isExpanded {
                Divider()

                // 备注
                if let notes = sentence.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("sentence.notes"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(8)
                }

                // 跳转到原文按钮
                if sentence.articleId != nil {
                    Button {
                        onJumpToSource()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text(L("sentence.jumpToSource"))
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isExpanded ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isExpanded ? Color.blue.opacity(0.18) : Color.gray.opacity(0.08), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
