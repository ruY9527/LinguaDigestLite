//
//  SentenceTranslationSheet.swift
//  LinguaDigestLite
//
//  Extracted from ReaderView.swift
//

import SwiftUI

/// 句子翻译弹窗
struct SentenceTranslationSheet: View {
    @ObservedObject var viewModel: TextTranslationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 原文显示
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("sheet.originalText"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(viewModel.selectedText ?? "")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.horizontal)

                Divider()

                // 翻译服务选择
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("sheet.translationServices"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.availableServices, id: \.self) { serviceType in
                                Button {
                                    viewModel.translateWithService(serviceType)
                                } label: {
                                    HStack {
                                        Image(systemName: iconForService(serviceType))
                                            .font(.title2)
                                            .foregroundColor(colorForService(serviceType))

                                        Text(serviceType.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        Image(systemName: "arrow.up.right.square")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // 提示信息
                Text(L("hint.translationRedirect"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle(L("nav.sentenceTranslation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        dismiss()
                        viewModel.close()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func iconForService(_ serviceType: TranslationServiceType) -> String {
        switch serviceType {
        case .system:
            return "character.bubble"
        case .google:
            return "globe"
        case .baidu:
            return "translate"
        case .deepL:
            return "doc.text"
        }
    }

    private func colorForService(_ serviceType: TranslationServiceType) -> Color {
        switch serviceType {
        case .system:
            return .blue
        case .google:
            return .green
        case .baidu:
            return .orange
        case .deepL:
            return .purple
        }
    }
}
