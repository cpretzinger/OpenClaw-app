//
//  ConversationManager.swift
//  OpenClaw
//
//  Wraps the ElevenLabs SDK Conversation class for voice interactions
//

import Foundation
import Combine
import ElevenLabs

enum AppConversationState: Equatable {
    case idle
    case connecting
    case active
    case ended(String)
    case error(String)
    
    static func == (lhs: AppConversationState, rhs: AppConversationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.connecting, .connecting), (.active, .active):
            return true
        case (.ended(let a), .ended(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
final class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    @Published private(set) var conversation: Conversation?
    
    @Published private(set) var state: AppConversationState = .idle
    @Published private(set) var messages: [ConversationMessage] = []
    @Published private(set) var agentState: AgentMode = .listening
    @Published private(set) var isMuted: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared
    private let audioSessionManager = AudioSessionManager.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start a conversation with a public agent (using agent ID only)
    func startConversation() async throws {
        guard state == .idle || state.isEndedOrError else {
            print("[OpenClaw] Already in state: \(state), skipping")
            return
        }
        
        state = .connecting
        print("[OpenClaw] State: connecting")
        
        // Note: Let the ElevenLabs SDK manage the audio session
        // Our custom configuration can conflict with LiveKit's AudioManager
        
        let agentId: String
        do {
            agentId = try keychainManager.getAgentId()
            print("[OpenClaw] Got agent ID: \(agentId.prefix(8))...")
        } catch {
            state = .error("Agent ID not configured")
            print("[OpenClaw] Error: Agent ID not configured")
            throw error
        }
        
        do {
            print("[OpenClaw] Calling ElevenLabs.startConversation...")
            let config = ConversationConfig()
            conversation = try await ElevenLabs.startConversation(
                agentId: agentId,
                config: config
            )
            print("[OpenClaw] Conversation started, setting up bindings")
            setupConversationBindings()
            state = .active
            print("[OpenClaw] State: active")
        } catch {
            state = .error("Connection failed: \(error.localizedDescription)")
            print("[OpenClaw] Connection failed: \(error)")
            throw error
        }
    }
    
    /// Start a conversation with a private agent (using conversation token)
    func startPrivateConversation() async throws {
        print("[OpenClaw] startPrivateConversation() called")
        guard state == .idle || state.isEndedOrError else {
            print("[OpenClaw] Already in state: \(state), skipping private")
            return
        }
        
        state = .connecting
        print("[OpenClaw] State: connecting (private)")
        
        // Note: Let the ElevenLabs SDK manage the audio session
        // Our custom configuration can conflict with LiveKit's AudioManager
        
        let agentId: String
        let apiKey: String
        
        do {
            agentId = try keychainManager.getAgentId()
            apiKey = try keychainManager.getElevenLabsApiKey()
            print("[OpenClaw] Got credentials - Agent: \(agentId.prefix(8))..., API Key: \(apiKey.prefix(8))...")
        } catch {
            print("[OpenClaw] Credentials error: \(error)")
            state = .error("Credentials not configured")
            throw error
        }
        
        do {
            print("[OpenClaw] Fetching conversation token...")
            let token = try await TokenService.shared.fetchToken(agentId: agentId, apiKey: apiKey)
            print("[OpenClaw] Got token: \(token.prefix(50))...")
            
            let config = ConversationConfig()
            print("[OpenClaw] Starting conversation with token...")
            // Use the conversationToken method for private agents
            conversation = try await ElevenLabs.startConversation(
                conversationToken: token,
                config: config
            )
            setupConversationBindings()
            state = .active
            print("[OpenClaw] Private conversation active!")
        } catch {
            print("[OpenClaw] Private connection failed: \(error)")
            state = .error("Connection failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func endConversation() async {
        await conversation?.endConversation()
        conversation = nil
        cancellables.removeAll()
        messages = []
        agentState = .listening
        isMuted = false
        state = .idle
    }
    
    func toggleMute() async {
        guard let conversation else { return }
        try? await conversation.toggleMute()
        isMuted = conversation.isMuted
    }
    
    func sendTextMessage(_ text: String) async {
        guard let conversation else { return }
        try? await conversation.sendMessage(text)
    }
    
    // MARK: - Private Methods
    
    private func setupConversationBindings() {
        guard let conversation else { return }
        
        // Observe conversation state
        conversation.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sdkState in
                print("[OpenClaw] SDK state changed: \(sdkState)")
                switch sdkState {
                case .active:
                    self?.state = .active
                case .ended(let reason):
                    self?.state = .ended("\(reason)")
                case .error(let err):
                    self?.state = .error(err.localizedDescription)
                case .idle:
                    self?.state = .idle
                case .connecting:
                    self?.state = .connecting
                @unknown default:
                    print("[OpenClaw] Unknown SDK state")
                    break
                }
            }
            .store(in: &cancellables)
        
        // Observe messages - deduplicate by content + role
        conversation.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sdkMessages in
                print("[OpenClaw] ========== Messages Update ==========")
                print("[OpenClaw] Raw SDK messages: \(sdkMessages.count)")
                for (i, msg) in sdkMessages.enumerated() {
                    print("[OpenClaw] [\(i)] id=\(msg.id) role=\(msg.role) content=\"\(msg.content.prefix(30))...\"")
                }
                
                // Deduplicate by content + role combination
                var seen = Set<String>()
                var uniqueMessages: [ConversationMessage] = []
                
                for msg in sdkMessages {
                    let key = "\(msg.role)-\(msg.content)"
                    if !seen.contains(key) {
                        seen.insert(key)
                        uniqueMessages.append(ConversationMessage(
                            id: msg.id,
                            source: msg.role == .user ? .user : .ai,
                            message: msg.content
                        ))
                    } else {
                        print("[OpenClaw] SKIPPED duplicate: \(msg.content.prefix(30))...")
                    }
                }
                
                print("[OpenClaw] Unique messages: \(uniqueMessages.count)")
                self?.messages = uniqueMessages
            }
            .store(in: &cancellables)
        
        // Observe agent state
        conversation.$agentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sdkAgentState in
                switch sdkAgentState {
                case .listening:
                    self?.agentState = .listening
                case .speaking:
                    self?.agentState = .speaking
                case .thinking:
                    self?.agentState = .listening
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Observe mute state
        conversation.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] muted in
                print("[OpenClaw] Mute state changed: \(muted)")
                self?.isMuted = muted
            }
            .store(in: &cancellables)
    }
}

// MARK: - State Helpers

extension AppConversationState {
    var isEndedOrError: Bool {
        switch self {
        case .ended, .error:
            return true
        default:
            return false
        }
    }
}
