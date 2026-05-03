//
//  ThemePickerView.swift
//  LinguaDigestLite
//
//  Extracted from SettingsView.swift
//

import SwiftUI

/// 主题选择视图
struct ThemePickerView: View {
    @Binding var selectedTheme: ReadingTheme

    var body: some View {
        List {
            ForEach(ReadingTheme.allCases, id: \.self) { theme in
                Button {
                    selectedTheme = theme
                } label: {
                    HStack {
                        // 主题预览
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: theme.backgroundColor))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("A")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: theme.textColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )

                        Text(theme.displayName)

                        Spacer()

                        if selectedTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(L("nav.selectTheme"))
    }
}
