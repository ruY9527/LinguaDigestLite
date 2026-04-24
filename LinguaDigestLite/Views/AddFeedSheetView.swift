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
                Section("RSS源信息") {
                    TextField("名称（可选）", text: $title)
                        .textContentType(.name)

                    TextField("RSS链接", text: $url)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .submitLabel(.done)
                }
                
                Section("备注") {
                    TextField("添加备注（可选）", text: $notes)
                        .textContentType(.name)
                    Text("可以为这个订阅源添加备注，方便识别和分类")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("正在添加...")
                            Spacer()
                        }
                    } else {
                        Button {
                            addFeed()
                        } label: {
                            HStack {
                                Spacer()
                                Text("添加")
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
                                Text("取消")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }

                Section("示例RSS源") {
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
            .navigationTitle("添加订阅源")
            .navigationBarTitleDisplayMode(.inline)
            .alert("添加失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "未知错误")
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
        (title: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml", notes: "英国广播公司新闻"),
        (title: "The Guardian", url: "https://www.theguardian.com/world/rss", notes: "英国卫报世界新闻"),
        (title: "NPR News", url: "https://feeds.npr.org/1004/rss.xml", notes: "美国国家公共电台"),
        (title: "TechCrunch", url: "https://techcrunch.com/feed/", notes: "科技创业新闻"),
        (title: "Wired", url: "https://www.wired.com/feed/rss", notes: "科技文化杂志"),
        (title: "MIT Technology Review", url: "https://www.technologyreview.com/feed/", notes: "麻省理工科技评论")
    ]
}