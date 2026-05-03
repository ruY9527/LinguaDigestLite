//
//  DictionaryExportSheet.swift
//  LinguaDigestLite
//
//  Extracted from SettingsView.swift
//

import SwiftUI

/// 词典导出弹窗
struct DictionaryExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: DictionaryFileFormat = .json
    @State private var isExporting: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 说明
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text(L("action.exportCustomDict"))
                        .font(.headline)

                    Text(L("sheet.exportDesc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // 词条数量显示
                VStack {
                    Text(L("label.customEntryCount"))
                        .font(.subheadline)

                    Text(String(format: L("setting.entryCountSuffix"), DictionaryService.shared.getCustomEntryCount()))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                // 格式选择
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("label.exportFormat"))
                        .font(.headline)

                    Picker(L("setting.exportFormat"), selection: $selectedFormat) {
                        ForEach([DictionaryFileFormat.json, .csv, .txt], id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // 导出按钮
                Button {
                    exportDictionary()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text(isExporting ? L("action.exporting") : L("action.exportAndShare"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isExporting ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(isExporting || DictionaryService.shared.getCustomEntryCount() == 0)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(L("nav.exportDict"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    /// 导出词典
    private func exportDictionary() {
        isExporting = true

        if let fileURL = DictionaryImportService.shared.exportCustomDictionary(format: selectedFormat) {
            isExporting = false

            // 分享文件
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let rootViewController = windowScene.windows.first?.rootViewController
                rootViewController?.present(activityVC, animated: true) {
                    dismiss()
                }
            }
        } else {
            isExporting = false
        }
    }
}
