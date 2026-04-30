//
//  LinguaDigestLiteApp.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

@main
struct LinguaDigestLiteApp: App {
    init() {
        // 初始化通知服务
        setupNotifications()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onReceive(NotificationCenter.default.publisher(for: .didTapReviewReminder)) { _ in
                    // 用户点击了复习提醒通知，可以导航到复习页面
                    print("用户点击了复习提醒通知")
                }
        }
    }
    
    /// 设置通知
    private func setupNotifications() {
        // 请求通知权限
        NotificationService.shared.requestAuthorization { granted, error in
            if granted {
                print("通知权限已授予")
                
                // 如果用户已启用每日提醒，重新设置通知
                if UserSettings.shared.reminderSettings.dailyReviewEnabled {
                    let reviewCount = DatabaseManager.shared.fetchTodayReviewVocabulary(for: nil).count
                    
                    NotificationService.shared.setDailyReviewReminderWithCount(
                        hour: UserSettings.shared.reminderSettings.reminderHour,
                        minute: UserSettings.shared.reminderSettings.reminderMinute,
                        enabled: true,
                        reviewCount: reviewCount
                    ) { success in
                        print("每日提醒通知已设置: \(success)")
                    }
                }
            } else {
                print("通知权限未授予: \(error?.localizedDescription ?? "unknown")")
            }
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
