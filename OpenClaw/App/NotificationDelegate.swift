//
//  NotificationDelegate.swift
//  OpenClaw
//
//  Handles notification presentation and user interactions
//

import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Foreground Presentation
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner and play sound even when app is in foreground
        return [.banner, .sound, .badge]
    }
    
    // MARK: - User Response Handling
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Extract OpenClaw-specific data from notification payload
        let openclawData = userInfo["openclaw"] as? [String: Any]
        let notificationType = openclawData?["type"] as? String
        let context = openclawData?["context"] as? String
        let message = openclawData?["message"] as? String
        
        await MainActor.run {
            switch actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                // User tapped the notification
                handleNotificationTap(type: notificationType, context: context, message: message)
                
            case "START_CHAT_ACTION":
                // User tapped "Start Voice Chat" action
                AppState.shared.pendingAction = .startConversation(context: context)
                
            case "REPLY_ACTION":
                // User replied from notification
                if let textResponse = response as? UNTextInputNotificationResponse {
                    handleQuickReply(text: textResponse.userText, context: context)
                }
                
            case "SNOOZE_ACTION":
                // User snoozed the notification
                scheduleSnooze(originalNotification: response.notification)
                
            case UNNotificationDismissActionIdentifier:
                // User dismissed the notification
                print("[NotificationDelegate] Notification dismissed")
                
            default:
                print("[NotificationDelegate] Unknown action: \(actionIdentifier)")
            }
        }
    }
    
    // MARK: - Private Handlers
    
    private func handleNotificationTap(type: String?, context: String?, message: String?) {
        switch type {
        case "start_conversation":
            AppState.shared.pendingAction = .startConversation(context: context)
        case "show_message":
            if let message = message {
                AppState.shared.pendingAction = .showMessage(message)
            }
        case "open_settings":
            AppState.shared.pendingAction = .openSettings
        default:
            // Default action: start conversation
            AppState.shared.pendingAction = .startConversation(context: nil)
        }
    }
    
    private func handleQuickReply(text: String, context: String?) {
        AppState.shared.pendingAction = .sendMessage(text, context: context)
    }
    
    private func scheduleSnooze(originalNotification: UNNotification) {
        let content = originalNotification.request.content.mutableCopy() as! UNMutableNotificationContent
        content.title = "Reminder: \(content.title)"
        
        // Schedule for 1 hour later
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationDelegate] Failed to schedule snooze: \(error)")
            } else {
                print("[NotificationDelegate] Snoozed notification for 1 hour")
            }
        }
    }
}
