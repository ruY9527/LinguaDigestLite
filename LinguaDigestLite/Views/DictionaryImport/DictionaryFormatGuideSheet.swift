//
//  DictionaryFormatGuideSheet.swift
//  LinguaDigestLite
//
//  Extracted from SettingsView.swift
//

import SwiftUI

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
