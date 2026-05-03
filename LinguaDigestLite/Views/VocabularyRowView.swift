//
//  VocabularyRowView.swift
//  LinguaDigestLite
//
//  Extracted from VocabularyListView.swift
//

import SwiftUI

/// 生词行视图
struct VocabularyRowView: View {
    let vocabulary: Vocabulary
    let categories: [VocabularyCategory]
    let onSpeak: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        headerRow
                        metadataRow

                        if !isExpanded {
                            exampleSection
                            reviewSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .buttonStyle(.plain)

                speakButton
            }

            if isExpanded {
                definitionSection
                englishDefinitionSection
                exampleSection
                reviewSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(cardBackground)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(vocabulary.word)
                        .font(.headline)

                    if let phonetic = vocabulary.phonetic {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let partOfSpeech = vocabulary.partOfSpeech {
                    Text(DictionaryService.displayNameForPartOfSpeech(partOfSpeech))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Spacer()

            if !categories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(categories.prefix(2)), id: \.id) { category in
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.caption2)
                            Text(category.name)
                                .font(.caption2)
                        }
                        .foregroundColor(Color(hex: category.color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: category.color).opacity(0.15))
                        .cornerRadius(4)
                    }

                    if categories.count > 2 {
                        Text("+\(categories.count - 2)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(4)
                    }
                }
            }

            masteryIndicator
        }
    }

    @ViewBuilder
    private var metadataRow: some View {
        let totalDefs = totalDefinitionCount
        if totalDefs > 0 {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    .foregroundColor(isExpanded ? .blue : .secondary)

                Text(isExpanded ? L("vocab.expandDef") : L("vocab.showDef"))
                    .font(.caption)
                    .foregroundColor(isExpanded ? .blue : .secondary)

                if !isExpanded {
                    Text(String(format: L("vocab.totalDefs"), totalDefs))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(6)
                }

                Spacer()
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)

                Text(L("vocab.noDef"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
    }

    private var totalDefinitionCount: Int {
        if let grouped = vocabulary.groupedDefinitions, !grouped.isEmpty {
            return grouped.reduce(0) { $0 + $1.definitions.count }
        }
        return definitionItems.count
    }

    @ViewBuilder
    private var definitionSection: some View {
        if isExpanded {
            if let grouped = vocabulary.groupedDefinitions, !grouped.isEmpty {
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
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.blue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(10)
            } else if !definitionItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(definitionItems.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.blue)
                                .frame(minWidth: 20, alignment: .trailing)
                            Text(item)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.blue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private var englishDefinitionSection: some View {
        if isExpanded, let englishDef = vocabulary.englishDefinition, !englishDef.isEmpty {
            let normalizedDef = englishDef.replacingOccurrences(of: "\\n", with: "\n")
            VStack(alignment: .leading, spacing: 4) {
                Text(L("section.chineseDef"))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ScrollView(.vertical, showsIndicators: true) {
                    Text(normalizedDef)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var exampleSection: some View {
        if let example = vocabulary.contextSnippet {
            VStack(alignment: .leading, spacing: 4) {
                if isExpanded {
                    Text(L("section.originalContext"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(example)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(isExpanded ? 3 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var reviewSection: some View {
        if vocabulary.reviewCount > 0 {
            Text(String(format: L("vocab.nextReview"), vocabulary.nextReviewDescription))
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }

    private var speakButton: some View {
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isExpanded ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isExpanded ? Color.blue.opacity(0.18) : Color.gray.opacity(0.08), lineWidth: 1)
            )
    }

    private var definitionItems: [String] {
        guard let definition = vocabulary.definition, !definition.isEmpty else {
            return []
        }
        return DictionaryService.shared.splitDefinitions(definition)
    }

    /// 掌握程度指示器
    private var masteryIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < vocabulary.masteredLevel ? masteryColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    /// 掌握程度颜色
    private var masteryColor: Color {
        switch vocabulary.masteredLevel {
        case 0: return .gray
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}
