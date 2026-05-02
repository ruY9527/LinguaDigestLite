//
//  NotificationService.swift
//  LinguaDigestLite
//
//  每日复习提醒通知服务
//

import Foundation
import UserNotifications
import UIKit

/// 每日复习提醒通知服务
class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    /// 通知标识符
    private let dailyReviewNotificationId = "dailyReviewReminder"
    
    /// 通知权限状态
    private(set) var isAuthorized: Bool = false
    
    override private init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - 权限请求
    
    /// 请求通知权限
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
        
        notificationCenter.requestAuthorization(options: options) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted, error)
            }
        }
    }
    
    /// 检查当前权限状态
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - 每日复习提醒
    
    /// 设置每日复习提醒
    /// - Parameters:
    ///   - hour: 提醒时间（小时，0-23）
    ///   - minute: 提醒时间（分钟，0-59）
    ///   - enabled: 是否启用
    func setDailyReviewReminder(hour: Int, minute: Int, enabled: Bool, completion: @escaping (Bool) -> Void) {
        // 先取消现有提醒
        cancelDailyReviewReminder()
        
        if !enabled {
            completion(true)
            return
        }
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "每日复习提醒"
        content.body = "今天有一些生词需要复习，快来巩固一下吧！"
        content.sound = .default
        content.badge = 1
        
        // 创建每日重复的时间触发器
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: dailyReviewNotificationId,
            content: content,
            trigger: trigger
        )
        
        // 添加通知
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("设置每日提醒失败: \(error)")
                    completion(false)
                } else {
                    print("每日复习提醒已设置: \(hour):\(minute)")
                    completion(true)
                }
            }
        }
    }
    
    /// 设置带有待复习数量的每日提醒
    func setDailyReviewReminderWithCount(hour: Int, minute: Int, enabled: Bool, reviewCount: Int, completion: @escaping (Bool) -> Void) {
        cancelDailyReviewReminder()
        
        if !enabled || reviewCount == 0 {
            completion(true)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "每日复习提醒"
        content.body = "今天有 \(reviewCount) 个生词待复习，快来巩固记忆吧！"
        content.sound = .default
        content.badge = NSNumber(value: reviewCount)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: dailyReviewNotificationId,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    /// 取消每日复习提醒
    func cancelDailyReviewReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [dailyReviewNotificationId])
    }
    
    /// 更新提醒内容（刷新待复习数量）
    func updateReminderContent(reviewCount: Int) {
        checkAuthorizationStatus { status in
            if status == .authorized {
                // 获取当前设置的提醒时间
                self.notificationCenter.getPendingNotificationRequests { requests in
                    for request in requests where request.identifier == self.dailyReviewNotificationId {
                        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                            let hour = trigger.dateComponents.hour ?? 9
                            let minute = trigger.dateComponents.minute ?? 0
                            
                            self.setDailyReviewReminderWithCount(
                                hour: hour,
                                minute: minute,
                                enabled: true,
                                reviewCount: reviewCount,
                                completion: { _ in }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 即时通知（测试用）
    
    /// 发送即时测试通知
    func sendTestNotification(completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "复习提醒测试"
        content.body = "这是一条测试通知，提醒功能正常工作！"
        content.sound = .default
        
        // 5秒后触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "testNotification",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    /// 发送即时复习提醒（待复习数量 > 0 时）
    func sendImmediateReviewReminder(reviewCount: Int, completion: @escaping (Bool) -> Void) {
        if reviewCount == 0 {
            completion(true)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "生词复习"
        content.body = "你有 \(reviewCount) 个生词等待复习"
        content.sound = .default
        content.badge = NSNumber(value: reviewCount)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "immediateReviewReminder",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    // MARK: - 清除通知
    
    /// 清除所有通知
    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    /// 清除应用图标徽章
    func clearBadge() {
        notificationCenter.removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    // MARK: - 获取待发送通知
    
    /// 获取待发送的通知列表
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
    
    /// 检查每日提醒是否已设置
    func isDailyReminderSet(completion: @escaping (Bool, Int, Int) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                for request in requests where request.identifier == self.dailyReviewNotificationId {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        let hour = trigger.dateComponents.hour ?? 0
                        let minute = trigger.dateComponents.minute ?? 0
                        completion(true, hour, minute)
                        return
                    }
                }
                completion(false, 0, 0)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// 应用在前台时收到通知的处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在前台也显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    /// 用户点击通知的处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        
        // 根据通知类型处理
        if identifier == dailyReviewNotificationId {
            // 用户点击了复习提醒，可以跳转到复习页面
            // 这里可以发送通知或调用回调
            NotificationCenter.default.post(name: .didTapReviewReminder, object: nil)
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didTapReviewReminder = Notification.Name("didTapReviewReminder")
    static let vocabularyDidChange = Notification.Name("vocabularyDidChange")
}
