//
//  PushNotificationManager.swift
//  OpenClaw
//
//  Manages APNs registration and notification permissions
//

import Foundation
import Combine
import UserNotifications
import UIKit

enum NotificationPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case provisional
}

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published private(set) var permissionStatus: NotificationPermissionStatus = .notDetermined
    @Published private(set) var deviceToken: String?
    @Published private(set) var registrationError: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Permission Handling
    
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .authorized:
            permissionStatus = .authorized
            // If already authorized, register for remote notifications
            await registerForRemoteNotifications()
        case .denied:
            permissionStatus = .denied
        case .provisional:
            permissionStatus = .provisional
            // If provisional, also register for remote notifications
            await registerForRemoteNotifications()
        case .ephemeral:
            permissionStatus = .authorized
            await registerForRemoteNotifications()
        @unknown default:
            permissionStatus = .notDetermined
        }
    }
    
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge, .provisional]
            )
            
            permissionStatus = granted ? .authorized : .denied
            
            if granted {
                await registerForRemoteNotifications()
                registerNotificationCategories()
            }
            
            return granted
        } catch {
            print("[PushNotification] Permission request error: \(error)")
            return false
        }
    }
    
    // MARK: - APNs Registration
    
    private func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        self.registrationError = nil
        print("[PushNotification] ========== DEVICE TOKEN ==========")
        print("[PushNotification] \(token)")
        print("[PushNotification] ==================================")
        
        // Register with OpenClaw Gateway
        Task {
            await GatewayNotificationService.shared.registerDevice(token: token)
        }
    }
    
    func handleRegistrationError(_ error: Error) {
        self.registrationError = error.localizedDescription
        print("[PushNotification] Registration error: \(error)")
    }
    
    // MARK: - Notification Categories
    
    private func registerNotificationCategories() {
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )
        
        let startChatAction = UNNotificationAction(
            identifier: "START_CHAT_ACTION",
            title: "Start Voice Chat",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 1 hour",
            options: []
        )
        
        // OpenClaw message category
        let messageCategory = UNNotificationCategory(
            identifier: "OPENCLAW_MESSAGE",
            actions: [replyAction, startChatAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Heartbeat alert category
        let heartbeatCategory = UNNotificationCategory(
            identifier: "OPENCLAW_HEARTBEAT",
            actions: [startChatAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Reminder category
        let reminderCategory = UNNotificationCategory(
            identifier: "OPENCLAW_REMINDER",
            actions: [startChatAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            messageCategory,
            heartbeatCategory,
            reminderCategory
        ])
    }
    
    // MARK: - Badge Management
    
    func clearBadge() async {
        UIApplication.shared.applicationIconBadgeNumber = 0
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
