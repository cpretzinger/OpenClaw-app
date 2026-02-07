# OpenClaw Architecture

This document provides a deep dive into the architecture and design decisions of OpenClaw.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Pattern](#architecture-pattern)
3. [Layer Diagram](#layer-diagram)
4. [Core Components](#core-components)
5. [Data Flow](#data-flow)
6. [State Management](#state-management)
7. [Dependency Graph](#dependency-graph)
8. [Security Architecture](#security-architecture)
9. [Network Layer](#network-layer)
10. [Audio Pipeline](#audio-pipeline)
11. [Design Decisions](#design-decisions)

---

## Overview

OpenClaw is built using modern iOS development practices with SwiftUI and Combine. The app follows a clean architecture approach with clear separation between UI, business logic, and data layers.

```
┌─────────────────────────────────────────────────────────────┐
│                      OpenClaw App                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   SwiftUI   │  │   Combine   │  │  ElevenLabs SDK     │  │
│  │   Views     │  │   Streams   │  │  (LiveKit/WebRTC)   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      iOS Platform                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ Security │ │ Network  │ │AVFounda- │ │   UIKit      │   │
│  │ Framework│ │ Framework│ │  tion    │ │  (hosting)   │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture Pattern

### MVVM (Model-View-ViewModel)

OpenClaw implements the MVVM pattern with reactive bindings via Combine:

```
┌─────────────────────────────────────────────────────────────┐
│                         VIEW                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ConversationView.swift                              │   │
│  │  SettingsView.swift                                  │   │
│  │  MessageBubbleView.swift                             │   │
│  │  OrbVisualizerView.swift                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           │ @StateObject / @Published       │
│                           ▼                                 │
│                      VIEW MODEL                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ConversationViewModel.swift                         │   │
│  │  SettingsViewModel.swift                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           │ Service calls                   │
│                           ▼                                 │
│                        MODEL                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ConversationTypes.swift                             │   │
│  │  Service Layer (Managers)                            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

| Principle | Implementation |
|-----------|----------------|
| **Single Responsibility** | Each class/struct has one clear purpose |
| **Dependency Injection** | Services accessed via singletons with clear interfaces |
| **Reactive Updates** | Combine publishers drive UI updates |
| **Immutable State** | `@Published` properties with private setters |

---

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐  │
│  │ ConversationView│ │  SettingsView   │ │ Components   │  │
│  │                 │ │                 │ │ (Orb, Bubble)│  │
│  └────────┬────────┘ └────────┬────────┘ └──────────────┘  │
│           │                   │                             │
├───────────┼───────────────────┼─────────────────────────────┤
│           ▼                   ▼                             │
│                    BUSINESS LOGIC LAYER                     │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐  │
│  │ Conversation    │ │   Settings      │ │   AppState   │  │
│  │   ViewModel     │ │   ViewModel     │ │              │  │
│  └────────┬────────┘ └────────┬────────┘ └──────────────┘  │
│           │                   │                             │
├───────────┼───────────────────┼─────────────────────────────┤
│           ▼                   ▼                             │
│                      SERVICE LAYER                          │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────────┐ │
│  │ Conversation │ │   Token      │ │    Keychain         │ │
│  │   Manager    │ │   Service    │ │    Manager          │ │
│  └──────┬───────┘ └──────┬───────┘ └──────────┬──────────┘ │
│         │                │                     │            │
│  ┌──────┴───────┐ ┌──────┴───────┐ ┌──────────┴──────────┐ │
│  │ AudioSession │ │   Network    │ │                     │ │
│  │   Manager    │ │   Monitor    │ │                     │ │
│  └──────────────┘ └──────────────┘ └─────────────────────┘ │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                     EXTERNAL LAYER                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              ElevenLabs Swift SDK                    │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌──────────────┐   │   │
│  │  │ Conversation│ │TokenService │ │ LiveKit Room │   │   │
│  │  └─────────────┘ └─────────────┘ └──────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. ConversationManager

The central hub for managing voice conversations.

```swift
@MainActor
final class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    @Published private(set) var conversation: Conversation?
    @Published private(set) var state: AppConversationState
    @Published private(set) var messages: [ConversationMessage]
    @Published private(set) var agentState: AgentMode
    @Published private(set) var isMuted: Bool
}
```

**Responsibilities:**
- Wraps ElevenLabs SDK `Conversation` object
- Manages conversation lifecycle (start, end, mute)
- Publishes state changes to subscribers
- Handles message deduplication
- Bridges SDK states to app-specific states

**State Machine:**
```
         ┌──────────┐
         │   IDLE   │◄────────────────────┐
         └────┬─────┘                     │
              │ startConversation()       │
              ▼                           │
         ┌──────────┐                     │
         │CONNECTING│                     │
         └────┬─────┘                     │
              │ success                   │ endConversation()
              ▼                           │
         ┌──────────┐                     │
         │  ACTIVE  │─────────────────────┤
         └────┬─────┘                     │
              │ error/disconnect          │
              ▼                           │
    ┌─────────┴─────────┐                 │
    ▼                   ▼                 │
┌───────┐          ┌─────────┐            │
│ ENDED │          │  ERROR  │────────────┘
└───────┘          └─────────┘
```

### 2. TokenService

Handles authentication for private ElevenLabs agents.

```swift
actor TokenService {
    static let shared = TokenService()

    func fetchToken(agentId: String, apiKey: String) async throws -> String
}
```

**API Flow:**
```
┌─────────────┐     POST /v1/convai/conversation/token     ┌─────────────┐
│ TokenService│ ──────────────────────────────────────────►│ ElevenLabs  │
│             │     Headers: xi-api-key                    │    API      │
│             │◄────────────────────────────────────────── │             │
└─────────────┘     Response: { "token": "jwt..." }        └─────────────┘
```

### 3. KeychainManager

Secure credential storage using iOS Keychain.

```swift
final class KeychainManager {
    static let shared = KeychainManager()

    func saveAgentId(_ id: String) throws
    func getAgentId() throws -> String
    func saveElevenLabsApiKey(_ key: String) throws
    func getElevenLabsApiKey() throws -> String
    func clearAll() throws
}
```

**Security Properties:**
- Data encrypted at rest by iOS
- Protected by device passcode/biometrics
- Not included in backups (configurable)
- Isolated per app (sandboxed)

### 4. NetworkMonitor

Real-time network connectivity monitoring.

```swift
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool
    @Published private(set) var connectionType: ConnectionType
}
```

**Connection Types:**
- `.wifi` - Connected via WiFi
- `.cellular` - Connected via cellular data
- `.unknown` - Connection type undetermined
- `.none` - No connection

### 5. AudioSessionManager

Configures AVAudioSession for voice conversations.

```swift
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    func configureForConversation() throws
    func deactivate() throws
}
```

**Audio Configuration:**
```
Category: .playAndRecord
Mode: .voiceChat
Options: [.defaultToSpeaker, .allowBluetooth]
```

---

## Data Flow

### Starting a Conversation

```
┌────────────┐    ┌────────────────┐    ┌───────────────────┐    ┌─────────────┐
│    User    │    │ Conversation   │    │   Conversation    │    │  ElevenLabs │
│            │    │   ViewModel    │    │     Manager       │    │     SDK     │
└─────┬──────┘    └───────┬────────┘    └─────────┬─────────┘    └──────┬──────┘
      │                   │                       │                      │
      │ Tap Start         │                       │                      │
      │──────────────────►│                       │                      │
      │                   │                       │                      │
      │                   │ startConversation()   │                      │
      │                   │──────────────────────►│                      │
      │                   │                       │                      │
      │                   │                       │ [Private Agent?]     │
      │                   │                       │──────┐               │
      │                   │                       │      │ fetchToken()  │
      │                   │                       │◄─────┘               │
      │                   │                       │                      │
      │                   │                       │ ElevenLabs.start()   │
      │                   │                       │─────────────────────►│
      │                   │                       │                      │
      │                   │                       │    Conversation      │
      │                   │                       │◄─────────────────────│
      │                   │                       │                      │
      │                   │  state = .active      │                      │
      │                   │◄──────────────────────│                      │
      │                   │                       │                      │
      │  UI Update        │                       │                      │
      │◄──────────────────│                       │                      │
      │                   │                       │                      │
```

### Message Flow

```
┌──────────────┐    ┌────────────────────┐    ┌─────────────┐
│  ElevenLabs  │    │ ConversationManager│    │     View    │
│     SDK      │    │                    │    │             │
└──────┬───────┘    └─────────┬──────────┘    └──────┬──────┘
       │                      │                      │
       │ $messages update     │                      │
       │─────────────────────►│                      │
       │                      │                      │
       │                      │ Deduplicate          │
       │                      │ messages             │
       │                      │                      │
       │                      │ @Published           │
       │                      │ messages update      │
       │                      │─────────────────────►│
       │                      │                      │
       │                      │                      │ Render
       │                      │                      │ MessageBubbles
       │                      │                      │
```

---

## State Management

### Global State

```swift
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isConfigured: Bool
    @Published var hasCompletedOnboarding: Bool
}
```

### View-Specific State

Each ViewModel manages its own state with `@Published` properties:

```swift
@MainActor
final class ConversationViewModel: ObservableObject {
    // UI State
    @Published var showSettings = false
    @Published var showTextInput = false
    @Published var textInput = ""
    @Published var showError = false
    @Published var errorMessage: String?

    // Derived from ConversationManager
    var state: AppConversationState { manager.state }
    var messages: [ConversationMessage] { manager.messages }
    var agentState: AgentMode { manager.agentState }
    var isMuted: Bool { manager.isMuted }
}
```

### State Propagation

```
ConversationManager (@Published)
         │
         │ Combine sink
         ▼
ConversationViewModel (objectWillChange)
         │
         │ SwiftUI binding
         ▼
ConversationView (re-render)
```

---

## Dependency Graph

```
                          ┌─────────────────┐
                          │   OpenClawApp   │
                          └────────┬────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
             ┌──────────┐  ┌──────────────┐  ┌──────────┐
             │ AppState │  │Conversation  │  │ Settings │
             │          │  │    View      │  │   View   │
             └──────────┘  └──────┬───────┘  └────┬─────┘
                                  │               │
                                  ▼               ▼
                          ┌──────────────┐  ┌──────────────┐
                          │ Conversation │  │   Settings   │
                          │  ViewModel   │  │  ViewModel   │
                          └──────┬───────┘  └──────┬───────┘
                                 │                 │
                    ┌────────────┼─────────────────┤
                    ▼            ▼                 ▼
             ┌──────────┐ ┌─────────────┐  ┌─────────────┐
             │ Network  │ │Conversation │  │  Keychain   │
             │ Monitor  │ │   Manager   │  │  Manager    │
             └──────────┘ └──────┬──────┘  └─────────────┘
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
             ┌──────────┐ ┌──────────┐ ┌──────────┐
             │  Token   │ │  Audio   │ │ Keychain │
             │ Service  │ │ Session  │ │ Manager  │
             └──────────┘ └──────────┘ └──────────┘
                    │
                    ▼
             ┌──────────────────┐
             │  ElevenLabs SDK  │
             └──────────────────┘
```

---

## Security Architecture

### Credential Storage

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS Keychain                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Service: "com.openclaw.credentials"                 │   │
│  │  ┌─────────────────┐  ┌─────────────────────────┐   │   │
│  │  │ agent_id        │  │ elevenlabs_api_key      │   │   │
│  │  │ (kSecClass:     │  │ (kSecClass:             │   │   │
│  │  │  GenericPassword│  │  GenericPassword)       │   │   │
│  │  └─────────────────┘  └─────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Protection: kSecAttrAccessibleWhenUnlocked                │
│  Encryption: AES-256-GCM (hardware-backed)                 │
└─────────────────────────────────────────────────────────────┘
```

### API Key Handling

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│   User      │     │  Keychain   │     │  TokenService   │
│   Input     │────►│  (stored)   │────►│  (used once)    │
└─────────────┘     └─────────────┘     └────────┬────────┘
                                                  │
                                                  ▼
                                         ┌─────────────────┐
                                         │  JWT Token      │
                                         │  (short-lived)  │
                                         └─────────────────┘
```

**Security Measures:**
1. API keys never logged or displayed
2. Keys stored encrypted in Keychain
3. Tokens are short-lived JWTs
4. No keys in source code or bundles

---

## Network Layer

### Connection Flow

```
┌─────────────┐                              ┌─────────────────┐
│   App       │                              │   ElevenLabs    │
│             │                              │   Services      │
└──────┬──────┘                              └────────┬────────┘
       │                                              │
       │  1. POST /token (API Key)                    │
       │─────────────────────────────────────────────►│
       │                                              │
       │  2. JWT Token                                │
       │◄─────────────────────────────────────────────│
       │                                              │
       │  3. WebSocket Connect (JWT)                  │
       │═════════════════════════════════════════════►│
       │                                              │
       │  4. LiveKit Room Join                        │
       │◄════════════════════════════════════════════►│
       │                                              │
       │  5. WebRTC Audio Streams                     │
       │◄═══════════════════════════════════════════►│
       │                                              │
```

### Protocol Stack

```
┌─────────────────────────────────────┐
│           Application               │
│  (Voice data, transcripts, events)  │
├─────────────────────────────────────┤
│           LiveKit Protocol          │
│  (Room, participants, tracks)       │
├─────────────────────────────────────┤
│              WebRTC                 │
│  (ICE, DTLS, SRTP)                  │
├─────────────────────────────────────┤
│           WebSocket                 │
│  (Signaling)                        │
├─────────────────────────────────────┤
│           TLS 1.3                   │
├─────────────────────────────────────┤
│           TCP/UDP                   │
└─────────────────────────────────────┘
```

---

## Audio Pipeline

### Voice Input/Output Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      Audio Pipeline                         │
│                                                             │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│  │  Mic    │───►│ AVAudio │───►│ LiveKit │───►│ WebRTC  │  │
│  │         │    │ Session │    │  Track  │    │ Encoder │  │
│  └─────────┘    └─────────┘    └─────────┘    └────┬────┘  │
│                                                     │       │
│                                                     ▼       │
│                                              ┌──────────┐   │
│                                              │ Network  │   │
│                                              └────┬─────┘   │
│                                                   │         │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐       │         │
│  │ Speaker │◄───│ AVAudio │◄───│ LiveKit │◄──────┘         │
│  │         │    │ Session │    │  Track  │                  │
│  └─────────┘    └─────────┘    └─────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Audio Session Configuration

```swift
Category: .playAndRecord
├── Enables simultaneous input and output
├── Allows voice processing
└── Mixes with other audio (optional)

Mode: .voiceChat
├── Optimized for voice communication
├── Echo cancellation enabled
├── Automatic gain control
└── Noise suppression

Options:
├── .defaultToSpeaker - Routes to speaker by default
├── .allowBluetooth - Enables Bluetooth headsets
└── .allowBluetoothA2DP - High-quality Bluetooth audio
```

---

## Design Decisions

### Why MVVM?

| Alternative | Reason Not Chosen |
|-------------|-------------------|
| MVC | Poor separation of concerns at scale |
| VIPER | Over-engineered for this app size |
| TCA | Learning curve, dependency on third-party |
| **MVVM** | ✅ Native SwiftUI support, simple, scalable |

### Why Singleton Services?

Services like `ConversationManager` are singletons because:
1. **Single Source of Truth** - One conversation at a time
2. **Lifecycle Management** - Lives for app duration
3. **Simple Access** - No dependency injection needed
4. **State Sharing** - Multiple views observe same state

### Why Combine over async/await for State?

| Use Case | Technology | Reason |
|----------|------------|--------|
| UI State | Combine | SwiftUI's `@Published` integration |
| One-shot API | async/await | Cleaner syntax for single operations |
| Streams | Combine | SDK exposes Combine publishers |

### Why Keychain over UserDefaults?

| Data | Storage | Reason |
|------|---------|--------|
| API Keys | Keychain | Encrypted, secure |
| Agent ID | Keychain | Sensitive identifier |
| Preferences | UserDefaults | Non-sensitive settings |

---

## Future Considerations

### Potential Improvements

1. **Dependency Injection Container** - For testability
2. **Offline Support** - Message queuing when disconnected
3. **Multiple Conversations** - History and resumption
4. **Widget Extension** - Quick-start conversations
5. **watchOS Companion** - Voice on Apple Watch

### Scalability Path

```
Current (Single Agent)          Future (Multi-Agent)
        │                               │
        ▼                               ▼
┌───────────────┐               ┌───────────────┐
│ Conversation  │               │ Conversation  │
│   Manager     │               │   Repository  │
│ (singleton)   │               │ (multi-agent) │
└───────────────┘               └───────┬───────┘
                                        │
                                ┌───────┴───────┐
                                ▼               ▼
                        ┌───────────┐   ┌───────────┐
                        │  Agent A  │   │  Agent B  │
                        │  Session  │   │  Session  │
                        └───────────┘   └───────────┘
```

---

<p align="center">
  <em>Architecture documentation for OpenClaw v1.0</em>
</p>
