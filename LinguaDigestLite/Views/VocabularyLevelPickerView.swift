//
//  VocabularyLevelPickerView.swift
//  LinguaDigestLite
//
//  Extracted from SettingsView.swift
//

import SwiftUI

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
