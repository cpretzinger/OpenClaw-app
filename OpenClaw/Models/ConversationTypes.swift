//
//  ConversationTypes.swift
//  OpenClaw
//
//  Type definitions for conversation handling
//

import Foundation

// MARK: - Message Types

/// Represents a message in the conversation
struct ConversationMessage: Identifiable, Equatable {
    let id: String
    let source: MessageSource
    let message: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, source: MessageSource, message: String, timestamp: Date = Date()) {
        self.id = id
        self.source = source
        self.message = message
        self.timestamp = timestamp
    }
}

/// The source of a message
enum MessageSource: String, Equatable {
    case user
    case ai
    case system
}

/// The current mode/state of the agent
enum AgentMode: String, Equatable {
    case listening
    case speaking
}
