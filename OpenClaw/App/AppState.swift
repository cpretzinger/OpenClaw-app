//
//  AppState.swift
//  OpenClaw
//
//  Global application state management
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published private(set) var isConfigured: Bool = false
    @Published var showOnboarding: Bool = false
    
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
}
