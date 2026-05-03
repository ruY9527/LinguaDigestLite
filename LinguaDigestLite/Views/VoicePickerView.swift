//
//  VoicePickerView.swift
//  LinguaDigestLite
//
//  Extracted from SettingsView.swift
//

import SwiftUI

/// 语音选择视图
struct VoicePickerView: View {
    @State private var selectedVoiceIndex: Int = 0

    let voices = SpeechService.voiceOptions()

    var body: some View {
        List {
            ForEach(0..<voices.count, id: \.self) { index in
                Button {
                    selectedVoiceIndex = index
                    // 保存语音设置
                } label: {
                    HStack {
                        Text(voices[index].name)

                        Spacer()

                        if selectedVoiceIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }

                        // 试听按钮
                        Button {
                            SpeechService.shared.speakWord("Hello", voice: voices[index].voice)
                        } label: {
                            Image(systemName: "speaker.wave.3")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(L("nav.selectVoice"))
    }
}
