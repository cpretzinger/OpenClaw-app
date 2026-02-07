//
//  GatewayNotificationService.swift
//  OpenClaw
//
//  Registers iOS device with OpenClaw Gateway for push notifications
//

import Foundation
import UIKit

actor GatewayNotificationService {
    static let shared = GatewayNotificationService()
    
    private var isRegistered = false
    private var lastRegisteredToken: String?
    
    /// OpenClaw Gateway URL (from settings or default)
    private var gatewayURL: String? {
        try? KeychainManager.shared.get(.openClawEndpoint)
    }
    
    /// Hook token for webhook authentication
    private var hookToken: String? {
        try? KeychainManager.shared.get(.gatewayHookToken)
    }
    
    // MARK: - Device Registration
    
    /// Register device token with OpenClaw Gateway
    func registerDevice(token: String) async {
        guard token != lastRegisteredToken else {
            print("[GatewayNotification] Already registered with this token")
            return
        }
        
        guard let baseURL = gatewayURL, !baseURL.isEmpty else {
            print("[GatewayNotification] Gateway URL not configured")
            return
        }
        
        // Use the webhook endpoint to register the device
        guard let url = URL(string: "\(baseURL)/hooks/ios-device") else {
            print("[GatewayNotification] Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // Add hook token authentication
        if let hookToken = hookToken {
            request.setValue("Bearer \(hookToken)", forHTTPHeaderField: "Authorization")
        }
        
        let deviceName = await MainActor.run { UIDevice.current.name }
        let deviceModel = await MainActor.run { UIDevice.current.model }
        let osVersion = await MainActor.run { UIDevice.current.systemVersion }
        
        let body: [String: Any] = [
            "action": "register",
            "device_token": token,
            "device_name": deviceName,
            "device_model": deviceModel,
            "os_version": osVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "bundle_id": Bundle.main.bundleIdentifier ?? "com.openclaw.app"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("[GatewayNotification] Device registered with Gateway")
                    lastRegisteredToken = token
                    isRegistered = true
                } else {
                    print("[GatewayNotification] Registration failed: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("[GatewayNotification] Registration error: \(error)")
        }
    }
    
    /// Unregister device from Gateway
    func unregisterDevice() async {
        guard let token = lastRegisteredToken,
              let baseURL = gatewayURL,
              let url = URL(string: "\(baseURL)/hooks/ios-device") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        if let hookToken = hookToken {
            request.setValue("Bearer \(hookToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "action": "unregister",
            "device_token": token
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: request)
            lastRegisteredToken = nil
            isRegistered = false
            print("[GatewayNotification] Device unregistered")
        } catch {
            print("[GatewayNotification] Unregister error: \(error)")
        }
    }
    
    /// Check if device is currently registered
    func getRegistrationStatus() -> Bool {
        isRegistered
    }
    
    /// Get the last registered token (masked for privacy)
    func getMaskedToken() -> String? {
        guard let token = lastRegisteredToken else { return nil }
        return String(token.prefix(8)) + "..." + String(token.suffix(8))
    }
}
