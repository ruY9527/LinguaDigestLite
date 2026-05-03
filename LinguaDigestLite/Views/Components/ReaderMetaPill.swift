//
//  ReaderMetaPill.swift
//  LinguaDigestLite
//
//  Extracted from ReaderView.swift
//

import SwiftUI

/// 阅读器元数据标签
struct ReaderMetaPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(Capsule())
    }
}
