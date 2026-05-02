//
//  AddFeedSheetView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

/// 添加RSS源弹窗视图
struct AddFeedSheetView: View {
    @ObservedObject var feedViewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var url: String = ""
    @State private var notes: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L("feed.info")) {
                    TextField(L("feed.nameOptional"), text: $title)
                        .textContentType(.name)

                    TextField(L("feed.url"), text: $url)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .submitLabel(.done)
                }
                
                Section(L("feed.notes")) {
                    TextField(L("feed.notesPlaceholder"), text: $notes)
                        .textContentType(.name)
                    Text(L("feed.notesHint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView(L("status.adding"))
                            Spacer()
                        }
                    } else {
                        Button {
                            addFeed()
                        } label: {
                            HStack {
                                Spacer()
                                Text(L("common.add"))
                                    .fontWeight(.semibold)
                                    .foregroundColor(url.isEmpty ? .gray : .blue)
                                Spacer()
                            }
                        }
                        .disabled(url.isEmpty || isLoading)

                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text(L("common.cancel"))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }

                Section(L("section.exampleFeeds")) {
                    ForEach(suggestedFeeds, id: \.url) { feed in
                        Button {
                            url = feed.url
                            title = feed.title
                            notes = feed.notes
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feed.title)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(feed.url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if !feed.notes.isEmpty {
                                        Text(feed.notes)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("nav.addFeed"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(L("alert.addFailed"), isPresented: $showError) {
                Button(L("common.ok"), role: .cancel) { }
            } message: {
                Text(errorMessage ?? L("error.unknown"))
            }
        }
    }

    private func addFeed() {
        guard !url.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            let notesText = notes.isEmpty ? nil : notes
            await feedViewModel.addFeed(title: title, feedUrl: url, notes: notesText)

            await MainActor.run {
                isLoading = false

                if let error = feedViewModel.errorMessage {
                    errorMessage = error
                    showError = true
                } else {
                    dismiss()
                }
            }
        }
    }

    /// 推荐的RSS源（带备注）
    private let suggestedFeeds = [
        (title: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml", notes: L("feed.note.bbc")),
        (title: "The Guardian", url: "https://www.theguardian.com/world/rss", notes: L("feed.note.guardian")),
        (title: "NPR News", url: "https://feeds.npr.org/1004/rss.xml", notes: L("feed.note.npr")),
        (title: "TechCrunch", url: "https://techcrunch.com/feed/", notes: L("feed.note.tc")),
        (title: "Wired", url: "https://www.wired.com/feed/rss", notes: L("feed.note.wired")),
        (title: "MIT Technology Review", url: "https://www.technologyreview.com/feed/", notes: L("feed.note.mit"))
    ]
}