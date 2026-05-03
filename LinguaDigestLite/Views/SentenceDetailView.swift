//
//  SentenceDetailView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

/// 句子详情/编辑 Sheet
struct SentenceDetailView: View {
    let sentence: SavedSentence
    @ObservedObject var sentenceViewModel: SentenceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editableTranslation: String
    @State private var editableNotes: String

    init(sentence: SavedSentence, sentenceViewModel: SentenceViewModel) {
        self.sentence = sentence
        self.sentenceViewModel = sentenceViewModel
        self._editableTranslation = State(initialValue: sentence.translation ?? "")
        self._editableNotes = State(initialValue: sentence.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // 原文
                Section(L("sheet.originalText")) {
                    Text(sentence.sentence)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 翻译
                Section(L("sentence.translation")) {
                    TextField(L("sentence.translationPlaceholder"), text: $editableTranslation, axis: .vertical)
                        .lineLimit(2...6)
                }

                // 备注
                Section(L("sentence.notes")) {
                    TextEditor(text: $editableNotes)
                        .frame(minHeight: 60)
                        .overlay(
                            Group {
                                if editableNotes.isEmpty {
                                    Text(L("sentence.notesPlaceholder"))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                // 来源信息
                Section(L("sentence.source")) {
                    if let title = sentence.articleTitle {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                            Text(title)
                                .foregroundColor(.primary)
                        }
                    }

                    if let source = sentence.source {
                        HStack {
                            Image(systemName: "newspaper")
                                .foregroundColor(.secondary)
                            Text(source)
                                .foregroundColor(.secondary)
                        }
                    }

                    if sentence.articleId != nil {
                        Button {
                            sentenceViewModel.jumpToSource(for: sentence)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.forward.app")
                                Text(L("sentence.jumpToSource"))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }

                // 分类
                Section(L("section.addToCategory")) {
                    let categories = sentenceViewModel.categories.filter { !$0.isAllCategory && sentence.categoryIds.contains($0.id) }
                    if categories.isEmpty {
                        Text(L("empty.noCategory"))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(categories, id: \.id) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                Text(category.name)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                // 信息
                Section {
                    HStack {
                        Text(L("sentence.createdAt"))
                        Spacer()
                        Text(sentence.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(L("nav.sentenceDetail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("sentence.save")) {
                        var updated = sentence
                        updated.translation = editableTranslation.isEmpty ? nil : editableTranslation
                        updated.notes = editableNotes.isEmpty ? nil : editableNotes
                        sentenceViewModel.updateSentence(updated)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
