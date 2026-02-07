//
//  ConversationViewModel.swift
//  OpenClaw
//
//  ViewModel for the main conversation interface
//

import Foundation
import Combine

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var showSettings = false
    @Published var showTextInput = false
    @Published var textInput = ""
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let conversationManager = ConversationManager.shared
    private let networkMonitor = NetworkMonitor.shared
    private let keychainManager = KeychainManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Forwarded Properties
    
    var state: AppConversationState {
        conversationManager.state
    }
    
    var messages: [ConversationMessage] {
        conversationManager.messages
    }
    
    var agentState: AgentMode {
        conversationManager.agentState
    }
    
    var isMuted: Bool {
        conversationManager.isMuted
    }
    
    var isConnected: Bool {
        state == .active
    }
    
    var isNetworkAvailable: Bool {
        networkMonitor.isConnected
    }
    
    var connectionStatus: String {
        switch state {
        case .idle:
            return "Ready"
        case .connecting:
            return "Connecting..."
        case .active:
            return "Connected"
        case .ended(let reason):
            return "Ended: \(reason)"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var statusColor: StatusColor {
        switch state {
        case .idle:
            return .neutral
        case .connecting:
            return .connecting
        case .active:
            return .connected
        case .ended, .error:
            return .disconnected
        }
    }
    
    enum StatusColor {
        case neutral, connecting, connected, disconnected
    }
    
    // MARK: - Init
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Forward state changes from ConversationManager
        conversationManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Forward network changes
        networkMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    func startConversation() async {
        print("[OpenClaw] >>>>>> startConversation() CALLED <<<<<<")
        
        guard isNetworkAvailable else {
            print("[OpenClaw] No network, aborting")
            showErrorMessage("No network connection available")
            return
        }
        
        print("[OpenClaw] Network OK, checking API key...")
        
        // Check if we have API key for private agent, otherwise use public
        let hasKey = keychainManager.hasApiKey()
        let storedKey = try? keychainManager.getElevenLabsApiKey()
        print("[OpenClaw] ========== START CONVERSATION ==========")
        print("[OpenClaw] Has API Key: \(hasKey)")
        print("[OpenClaw] Stored key length: \(storedKey?.count ?? 0)")
        
        do {
            
            if hasKey {
                print("[OpenClaw] Using PRIVATE conversation flow")
                try await conversationManager.startPrivateConversation()
            } else {
                print("[OpenClaw] Using PUBLIC conversation flow")
                try await conversationManager.startConversation()
            }
        } catch {
            print("[OpenClaw] Start conversation error: \(error)")
            showErrorMessage(error.localizedDescription)
        }
    }
    
    func endConversation() async {
        await conversationManager.endConversation()
    }
    
    func toggleMute() async {
        await conversationManager.toggleMute()
    }
    
    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await conversationManager.sendTextMessage(text)
        textInput = ""
    }
    
    func toggleTextInput() {
        showTextInput.toggle()
    }
    
    // MARK: - Helpers
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
