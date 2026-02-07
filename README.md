<p align="center">
  <img src="OpenClaw/Assets.xcassets/OpenClawLogo.imageset/openclaw-logo.png" alt="OpenClaw Logo" width="200"/>
</p>

<h1 align="center">OpenClaw</h1>

<p align="center">
  <strong>AI-Powered Voice Conversation iOS App</strong><br>
  Built with SwiftUI and ElevenLabs Conversational AI SDK
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS 17.0+"/>
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9"/>
  <img src="https://img.shields.io/badge/SwiftUI-5.0-purple.svg" alt="SwiftUI"/>
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License"/>
</p>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation](#installation)
- [ElevenLabs Agent Setup](#elevenlabs-agent-setup)
- [Backend Configuration](#backend-configuration)
- [App Configuration](#app-configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Tech Stack](#tech-stack)

---

## Overview

OpenClaw is a native iOS application that enables real-time voice conversations with AI agents powered by [ElevenLabs Conversational AI](https://elevenlabs.io/docs/conversational-ai). The app features a modern, immersive UI design with smooth animations, secure credential storage, and support for both public and private ElevenLabs agents.

## Features

- **Real-time Voice Conversations** - Talk naturally with AI agents using WebRTC technology
- **Text Messaging** - Optional text input for when voice isn't convenient
- **Private Agent Support** - Securely connect to private ElevenLabs agents with API key authentication
- **Live Transcription** - See conversation transcripts in real-time
- **Animated Voice Visualizer** - Beautiful orb animation that responds to agent state
- **Secure Credential Storage** - API keys stored safely in iOS Keychain
- **Network Monitoring** - Automatic detection of connectivity status
- **Dark Mode Design** - Elegant warm-toned dark interface inspired by Anthropic's design language

---

## Architecture

OpenClaw follows a clean MVVM (Model-View-ViewModel) architecture with clear separation of concerns.

```
OpenClaw/
├── App/
│   └── AppState.swift              # Global application state
├── Extensions/
│   └── Color+Theme.swift           # Color palette and theming
├── Features/
│   ├── Conversation/
│   │   ├── ConversationView.swift      # Main conversation UI
│   │   ├── ConversationViewModel.swift # Conversation business logic
│   │   ├── MessageBubbleView.swift     # Chat message component
│   │   └── OrbVisualizerView.swift     # Animated voice visualizer
│   └── Settings/
│       ├── SettingsView.swift          # Settings UI
│       └── SettingsViewModel.swift     # Settings business logic
├── Models/
│   └── ConversationTypes.swift     # Data models and types
├── Services/
│   ├── AudioSessionManager.swift   # Audio session configuration
│   ├── ConversationManager.swift   # ElevenLabs SDK wrapper
│   ├── KeychainManager.swift       # Secure credential storage
│   ├── NetworkMonitor.swift        # Connectivity monitoring
│   └── TokenService.swift          # API token management
├── Assets.xcassets                 # Images, colors, app icon
└── OpenClawApp.swift               # App entry point
```

### Key Components

| Component | Responsibility |
|-----------|----------------|
| **ConversationManager** | Singleton that wraps the ElevenLabs SDK, manages conversation lifecycle, and publishes state changes |
| **TokenService** | Handles authentication with ElevenLabs API for private agents |
| **KeychainManager** | Securely stores and retrieves API keys and agent IDs |
| **NetworkMonitor** | Monitors network connectivity using NWPathMonitor |
| **AudioSessionManager** | Configures AVAudioSession for voice conversations |

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ ConversationView│ ←→  │ConversationVM    │ ←→  │ConversationMgr  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                          ↓
                                                ┌─────────────────┐
                                                │  ElevenLabs SDK │
                                                │    (LiveKit)    │
                                                └─────────────────┘
```

---

## Requirements

- **iOS 17.0** or later
- **Xcode 15.0** or later
- **Swift 5.9** or later
- **ElevenLabs Account** with a configured AI agent

---

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/acidoom/OpenClaw-app.git
cd OpenClaw-app
```

### Step 2: Open in Xcode

```bash
open OpenClaw.xcodeproj
```

### Step 3: Install Dependencies

The project uses Swift Package Manager. Xcode will automatically resolve dependencies when you open the project.

**Dependencies:**
- [ElevenLabs Swift SDK](https://github.com/elevenlabs/elevenlabs-swift-sdk) - Conversational AI SDK
- LiveKit (transitive dependency) - WebRTC infrastructure

### Step 4: Configure Signing

1. Select the **OpenClaw** target in Xcode
2. Go to **Signing & Capabilities**
3. Select your **Team**
4. Update the **Bundle Identifier** if needed

### Step 5: Build and Run

1. Select your target device or simulator
2. Press `Cmd + R` to build and run

---

## ElevenLabs Agent Setup

This section walks you through creating and configuring an ElevenLabs Conversational AI agent from scratch.

### Step 1: Create an ElevenLabs Account

1. Go to [ElevenLabs](https://elevenlabs.io) and sign up
2. Verify your email and complete onboarding
3. You'll need at least the **Starter** plan for Conversational AI features

### Step 2: Create a New Agent

1. Navigate to **Conversational AI** in the left sidebar
2. Click **Create Agent** or **+ New Agent**
3. Choose a template or start from scratch

### Step 3: Configure Agent Settings

#### Basic Settings

| Setting | Description |
|---------|-------------|
| **Name** | Give your agent a memorable name (e.g., "OpenClaw Assistant") |
| **Language** | Select the primary language (English recommended) |
| **Voice** | Choose from ElevenLabs' voice library or clone your own |

#### System Prompt

Configure your agent's personality and behavior:

```
You are OpenClaw, a helpful AI assistant. You are friendly, concise, and helpful.
Keep your responses brief and conversational since this is a voice interface.
Avoid using markdown, bullet points, or formatting that doesn't work well in speech.
```

#### First Message

Set what the agent says when a conversation starts:

```
Hello! I'm OpenClaw, your AI assistant. How can I help you today?
```

### Step 4: Enable Custom LLM (Optional)

If you want to use your own LLM backend (like a local model or custom API):

1. Go to **Agent Settings** → **LLM**
2. Select **Custom LLM**
3. Configure the completion endpoint:

```
┌─────────────────────────────────────────────────────────────┐
│                    Custom LLM Setup                         │
├─────────────────────────────────────────────────────────────┤
│  Endpoint URL:  https://your-server.com/v1/chat/completions │
│  API Key:       your-api-key (if required)                  │
│  Model:         your-model-name                             │
└─────────────────────────────────────────────────────────────┘
```

The endpoint must be **OpenAI-compatible** and accept:
- `POST` requests with JSON body
- Messages in the format: `[{"role": "user", "content": "..."}]`
- Return streaming responses with `choices[0].delta.content`

### Step 5: Get Your Agent ID

1. After creating your agent, go to **Agent Settings**
2. Find the **Agent ID** (looks like: `agent_xxxxxxxxxxxx`)
3. Copy this ID - you'll need it for the app

### Step 6: Configure Agent Visibility

#### Public Agent (Recommended for Testing)

1. Go to **Agent Settings** → **Security**
2. Set visibility to **Public**
3. Anyone with the Agent ID can connect (no API key needed in the app)

#### Private Agent (Recommended for Production)

1. Set visibility to **Private**
2. You'll need an API key with `convai_write` permission
3. The app will authenticate via the token endpoint

---

## Backend Configuration

OpenClaw can connect to a custom backend for enhanced functionality. This is optional but useful for:
- Using your own LLM models
- Adding custom business logic
- Implementing user authentication
- Logging and analytics

### Setting Up a Funnel/Proxy Server

If you want to route requests through your own server (e.g., using Tailscale Funnel):

#### Option 1: Tailscale Funnel

1. **Install Tailscale** on your server:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   ```

2. **Enable Funnel**:
   ```bash
   tailscale funnel 443 8080
   ```

3. **Your endpoint** will be available at:
   ```
   https://your-machine.your-tailnet.ts.net
   ```

4. **Configure your LLM server** to listen on port 8080

#### Option 2: Custom Server with OpenAI-Compatible API

Create a server that implements the OpenAI chat completions API:

```python
# Example using FastAPI
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: list[Message]
    stream: bool = True

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    # Your LLM logic here
    # Return OpenAI-compatible streaming response
    pass
```

#### Option 3: Use Existing LLM Providers

You can point ElevenLabs to any OpenAI-compatible endpoint:

| Provider | Endpoint |
|----------|----------|
| OpenAI | `https://api.openai.com/v1/chat/completions` |
| Azure OpenAI | `https://{resource}.openai.azure.com/openai/deployments/{model}/chat/completions` |
| Anthropic (via proxy) | Use a proxy that converts to OpenAI format |
| Local (Ollama) | `http://localhost:11434/v1/chat/completions` |
| Local (LM Studio) | `http://localhost:1234/v1/chat/completions` |

### Connecting ElevenLabs to Your Backend

1. In ElevenLabs, go to **Agent Settings** → **LLM**
2. Select **Custom LLM**
3. Enter your endpoint URL
4. Add authentication headers if needed
5. Test the connection

---

## App Configuration

### Configuring the iOS App

1. Launch OpenClaw on your device
2. Tap the **gear icon** (⚙️) to open Settings

### For Public Agents

1. Enter your **Agent ID** in the Agent ID field
2. Leave **Private Agent** toggle OFF
3. Tap **Save**
4. Tap **Test Connection** to verify

### For Private Agents

1. Enter your **Agent ID**
2. Enable the **Private Agent** toggle
3. Enter your **API Key**
4. Tap **Save**
5. Tap **Test Connection** to verify

### Getting an API Key with Correct Permissions

1. Go to [ElevenLabs API Keys](https://elevenlabs.io/app/settings/api-keys)
2. Click **Create API Key**
3. **Important**: Enable the `convai_write` permission
4. Copy the key immediately (it won't be shown again)

```
┌─────────────────────────────────────────────────────────────┐
│                  API Key Permissions                        │
├─────────────────────────────────────────────────────────────┤
│  ☑ convai_write    - Required for conversation tokens       │
│  ☐ convai_read     - Optional, for reading agent config     │
│  ☐ text_to_speech  - Not needed for OpenClaw                │
└─────────────────────────────────────────────────────────────┘
```

### How Authentication Works

```
┌─────────────┐         ┌─────────────────┐         ┌─────────────┐
│  OpenClaw   │         │   ElevenLabs    │         │   LiveKit   │
│    App      │         │      API        │         │   Server    │
└──────┬──────┘         └────────┬────────┘         └──────┬──────┘
       │                         │                         │
       │  POST /token            │                         │
       │  (Agent ID + API Key)   │                         │
       │────────────────────────►│                         │
       │                         │                         │
       │  JWT Token              │                         │
       │◄────────────────────────│                         │
       │                         │                         │
       │  WebSocket Connect (JWT)                          │
       │──────────────────────────────────────────────────►│
       │                         │                         │
       │  Audio Streams (WebRTC)                           │
       │◄─────────────────────────────────────────────────►│
       │                         │                         │
```

---

## Usage

### Starting a Conversation

1. Ensure your agent is configured in Settings
2. Tap the **coral waveform button** to start
3. Grant microphone permission when prompted
4. Start speaking - the agent will respond

### Controls

| Control | Action |
|---------|--------|
| **Waveform Button** | Start/stop conversation |
| **Microphone Button** | Mute/unmute your voice |
| **Keyboard Button** | Toggle text input mode |

### Voice States

The orb visualizer indicates the current state:
- **Pulsing coral** - Agent is listening
- **Active animation** - Agent is speaking
- **Static gray** - Disconnected

---

## Troubleshooting

### Connection Timeout

```
Error: "Timed out"
```

**Causes & Solutions:**
- Check your internet connection (WiFi/Cellular)
- Verify your Agent ID is correct (no extra spaces)
- For private agents, ensure API key has `convai_write` permission
- Check if ElevenLabs services are operational

### 401 Authentication Error

```
Error: "missing_permissions" or "invalid authorization token"
```

**Solutions:**
1. Go to [ElevenLabs API Keys](https://elevenlabs.io/app/settings/api-keys)
2. Create a **new** API key with `convai_write` permission
3. Delete the old key from OpenClaw Settings
4. Enter the new key and save

### No Audio Output

**Checklist:**
- [ ] Device volume is up
- [ ] Silent mode is off
- [ ] App has microphone permission (Settings → OpenClaw → Microphone)
- [ ] Try restarting the conversation
- [ ] Check if other apps can play audio

### Agent Not Responding

**Checklist:**
- [ ] Agent is properly configured in ElevenLabs dashboard
- [ ] Agent has a valid voice selected
- [ ] If using Custom LLM, verify the endpoint is reachable
- [ ] Check ElevenLabs dashboard for error logs

### Custom LLM Not Working

If you're using a custom LLM endpoint:

1. **Test the endpoint manually:**
   ```bash
   curl -X POST https://your-endpoint/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"messages":[{"role":"user","content":"Hello"}],"stream":true}'
   ```

2. **Verify response format** matches OpenAI's streaming format

3. **Check CORS headers** if using a web-based proxy

4. **Verify SSL certificate** is valid (no self-signed certs in production)

---

## Tech Stack

| Technology | Purpose |
|------------|---------|
| **SwiftUI** | Declarative UI framework |
| **Combine** | Reactive state management |
| **ElevenLabs SDK** | Conversational AI integration |
| **LiveKit** | WebRTC infrastructure |
| **Security.framework** | Keychain credential storage |
| **Network.framework** | Connectivity monitoring |
| **AVFoundation** | Audio session management |

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [ElevenLabs](https://elevenlabs.io) for the Conversational AI SDK
- [LiveKit](https://livekit.io) for WebRTC infrastructure
- [Anthropic](https://anthropic.com) for design inspiration

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

<p align="center">
  Made with ❤️ for AI-powered voice interactions
</p>
