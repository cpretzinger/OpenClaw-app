//
//  AppState.swift
//  OpenClaw
//
//  Global application state management
//

import Foundation
import Combine

// MARK: - Deep Link Actions

enum DeepLinkAction: Equatable {
    case startConversation(context: String?)
    case showMessage(String)
    case sendMessage(String, context: String?)
    case openSettings
    
    static func == (lhs: DeepLinkAction, rhs: DeepLinkAction) -> Bool {
        switch (lhs, rhs) {
        case (.startConversation(let a), .startConversation(let b)):
            return a == b
        case (.showMessage(let a), .showMessage(let b)):
            return a == b
        case (.sendMessage(let m1, let c1), .sendMessage(let m2, let c2)):
            return m1 == m2 && c1 == c2
        case (.openSettings, .openSettings):
            return true
        default:
            return false
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published private(set) var isConfigured: Bool = false
    @Published var showOnboarding: Bool = false
    
    // Notification state
    @Published var notificationPermission: NotificationPermissionStatus = .notDetermined
    @Published var pendingAction: DeepLinkAction?
    
    let keychainManager = KeychainManager.shared
    let networkMonitor = NetworkMonitor.shared
    
    private init() {
        checkConfiguration()
    }
    
    func checkConfiguration() {
        isConfigured = keychainManager.hasAgentId()
        showOnboarding = !isConfigured
    }
    
    func markConfigured() {
        isConfigured = true
        showOnboarding = false
    }
    
    // MARK: - Notification Handling
    
    func clearPendingAction() {
        pendingAction = nil
    }
    
    func updateNotificationPermission(_ status: NotificationPermissionStatus) {
        notificationPermission = status
    }
}
