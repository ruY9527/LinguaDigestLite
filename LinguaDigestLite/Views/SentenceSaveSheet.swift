//
//  SentenceSaveSheet.swift
//  LinguaDigestLite
//
//  Extracted from ReaderView.swift
//

import SwiftUI

/// 句子收藏弹窗
struct SentenceSaveSheet: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editableTranslation: String = ""
    @State private var editableNotes: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 可滚动内容区
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 原文
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("sheet.originalText"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(viewModel.pendingSentence)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                        }

                        // 翻译
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("sentence.translation"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(L("sentence.translationPlaceholder"), text: $editableTranslation, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(10)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(10)
                        }

                        // 备注
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("sentence.notes"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(L("sentence.notesPlaceholder"), text: $editableNotes, axis: .vertical)
                                .lineLimit(1...3)
                                .padding(10)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(10)
                        }

                        // 分类
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("section.addToCategory"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.selectableCategoriesForWord, id: \.id) { category in
                                        Button {
                                            viewModel.toggleCategorySelectionForSentence(category)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: category.icon)
                                                    .font(.caption2)
                                                Text(category.name)
                                                    .font(.caption)
                                                if viewModel.isCategorySelectedForSentence(category) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.caption2)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                viewModel.isCategorySelectedForSentence(category)
                                                    ? Color(hex: category.color)
                                                    : Color(hex: category.color).opacity(0.2)
                                            )
                                            .foregroundColor(
                                                viewModel.isCategorySelectedForSentence(category)
                                                    ? .white
                                                    : Color(hex: category.color)
                                            )
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }

                // 保存按钮（固定在底部）
                Button {
                    viewModel.confirmSaveSentence(
                        translation: editableTranslation.isEmpty ? nil : editableTranslation,
                        notes: editableNotes.isEmpty ? nil : editableNotes,
                        categoryIds: Array(viewModel.selectedCategoryIdsForSentence)
                    )
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "bookmark.fill")
                        Text(L("sentence.save"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle(L("action.saveSentence"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        viewModel.cancelSaveSentence()
                        dismiss()
                    }
                }
            }
            .onAppear {
                editableTranslation = viewModel.pendingTranslation ?? ""
            }
            .onDisappear {
                NotificationCenter.default.post(name: .clearTextSelection, object: nil)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
