//
//  FontPickerView.swift
//  LinguaDigestLite
//
//  Extracted from SettingsView.swift
//

import SwiftUI

/// 字体选择视图
struct FontPickerView: View {
    @Binding var selectedFont: String?

    var body: some View {
        List {
            ForEach(ReadingSettings.standardFonts.sorted(by: { $0.key < $1.key }), id: \.key) { font in
                Button {
                    selectedFont = font.value
                } label: {
                    HStack {
                        if let customFontName = font.value {
                            Text(font.key)
                                .font(.custom(customFontName, size: 16))
                        } else {
                            Text(font.key)
                                .font(.system(size: 16))
                        }

                        Spacer()

                        if selectedFont == font.value {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(L("nav.selectFont"))
    }
}
