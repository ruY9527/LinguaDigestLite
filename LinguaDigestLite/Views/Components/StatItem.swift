//
//  StatItem.swift
//  LinguaDigestLite
//
//  Extracted from VocabularyListView.swift
//

import SwiftUI

/// 统计项
struct StatItem: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
