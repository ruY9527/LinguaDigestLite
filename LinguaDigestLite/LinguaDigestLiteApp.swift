//
//  LinguaDigestLiteApp.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

@main
struct LinguaDigestLiteApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

/// 主标签视图
struct MainTabView: View {
    @StateObject private var articleViewModel = ArticleViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var vocabularyViewModel = VocabularyViewModel()
    
    var body: some View {
        TabView {
            // 文章列表
            ArticleListView(viewModel: articleViewModel, feedViewModel: feedViewModel)
                .tabItem {
                    Label("文章", systemImage: "newspaper.fill")
                }
            
            // RSS源管理
            FeedListView(viewModel: feedViewModel)
                .tabItem {
                    Label("订阅", systemImage: "link.circle.fill")
                }
            
            // 生词本
            VocabularyListView(viewModel: vocabularyViewModel)
                .tabItem {
                    Label("生词本", systemImage: "book.fill")
                }
            
            // 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
    }
}
