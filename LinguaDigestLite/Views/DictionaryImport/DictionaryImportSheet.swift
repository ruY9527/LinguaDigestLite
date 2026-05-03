//
//  DictionaryImportSheet.swift
//  LinguaDigestLite
//
//  Extracted from SettingsView.swift
//

import SwiftUI
import UniformTypeIdentifiers

/// 词典导入弹窗
struct DictionaryImportSheet: View {
    let importMode: DictionaryImportMode
    let onImportComplete: (DictionaryImportResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker: Bool = false
    @State private var selectedFileURL: URL?
    @State private var isImporting: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 说明
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)

                    Text(L("sheet.importDict"))
                        .font(.headline)

                    Text(L("sheet.importDesc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // 导入模式说明
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: L("sheet.importModeLabel"), importMode.rawValue))
                        .font(.headline)

                    Text(importModeDescription(importMode))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // 选择文件按钮
                Button {
                    showingFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(L("action.selectFile"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // 已选文件显示
                if let fileURL = selectedFileURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("label.selectedFile"))
                            .font(.headline)

                        HStack {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading) {
                                Text(fileURL.lastPathComponent)
                                    .font(.subheadline)
                                Text(fileURL.pathExtension.uppercased())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                selectedFileURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)

                        // 导入按钮
                        Button {
                            importFile(url: fileURL)
                        } label: {
                            HStack {
                                if isImporting {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text(isImporting ? L("action.importing") : L("action.startImport"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isImporting ? Color.gray : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(isImporting)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle(L("nav.importDict"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: DictionaryImportService.shared.supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    selectedFileURL = urls.first
                case .failure(let error):
                    print("选择文件失败: \(error)")
                }
            }
        }
    }

    /// 导入模式说明
    private func importModeDescription(_ mode: DictionaryImportMode) -> String {
        switch mode {
        case .enhance:
            return L("importMode.merge")
        case .overwrite:
            return L("importMode.overwrite")
        case .addOnly:
            return L("importMode.addOnly")
        }
    }

    /// 导入文件
    private func importFile(url: URL) {
        isImporting = true

        DictionaryImportService.shared.importDictionary(
            from: url,
            mode: importMode
        ) { result in
            isImporting = false
            onImportComplete(result)
            dismiss()
        }
    }
}
