# OpenClaw Gateway - iOS Push Notifications Module

This module extends the OpenClaw Gateway to support iOS push notifications via Apple Push Notification service (APNs).

## Files

| File | Description |
|------|-------------|
| `apns-notifier.ts` | Core APNs client with JWT authentication and HTTP/2 |
| `ios-hooks.ts` | Webhook handlers for device registration and notification sending |

## Prerequisites

1. **Apple Developer Account** with push notification capability
2. **APNs Authentication Key** (.p8 file) from Apple Developer Portal
3. **Node.js 16+** with npm/yarn

## Setup

### 1. Install Dependencies

```bash
npm install jsonwebtoken
# TypeScript types (optional)
npm install -D @types/jsonwebtoken @types/node
```

### 2. Configure Environment Variables

Create a `.env` file or set these environment variables:

```bash
# Required
APNS_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
APNS_KEY_ID=XXXXXXXXXX          # From Apple Developer Portal
APNS_TEAM_ID=YYYYYYYYYY         # From Apple Developer Portal

# Optional
APNS_BUNDLE_ID=com.openclawapp.voice # Your app's bundle ID
APNS_SANDBOX=true               # true for development, false for production
```

### 3. Integrate with Your Gateway

#### Option A: Express.js

```typescript
import express from 'express';
import { createAPNsNotifier } from './apns-notifier';
import { createIOSHooksRouter } from './ios-hooks';

const app = express();
app.use(express.json());

// Initialize APNs
const apns = createAPNsNotifier();

// Create routes
const iosHooks = createIOSHooksRouter(apns);

// Register endpoints
app.post('/hooks/ios-device', iosHooks.postDevice);
app.post('/hooks/ios-notify', iosHooks.postNotify);
app.get('/hooks/ios-devices', iosHooks.getDevices);

app.listen(3000);
```

#### Option B: Direct Integration

```typescript
import { createAPNsNotifier, APNsNotifier } from './apns-notifier';
import { handleIOSDevice, handleIOSNotify } from './ios-hooks';

const apns = createAPNsNotifier();

// In your webhook handler:
async function handleWebhook(path: string, body: any) {
    switch (path) {
        case '/hooks/ios-device':
            return handleIOSDevice(apns, body);
        case '/hooks/ios-notify':
            return handleIOSNotify(apns, body);
    }
}
```

## API Endpoints

### POST /hooks/ios-device

Register or unregister an iOS device.

**Request:**
```json
{
    "action": "register",
    "device_token": "abc123...",
    "device_name": "iPhone 15 Pro",
    "device_model": "iPhone",
    "os_version": "17.4",
    "app_version": "1.0.0"
}
```

**Response:**
```json
{
    "status": "registered",
    "message": "Device registered successfully. Total devices: 1"
}
```

### POST /hooks/ios-notify

Send a push notification to registered devices.

**Request (to all devices):**
```json
{
    "title": "OpenClaw",
    "body": "You have a new message",
    "category": "OPENCLAW_MESSAGE",
    "data": {
        "type": "start_conversation",
        "context": "notification"
    }
}
```

**Request (to specific device):**
```json
{
    "title": "Reminder",
    "body": "Don't forget your meeting!",
    "device_token": "abc123..."
}
```

**Response:**
```json
{
    "status": "sent",
    "devices_notified": 1
}
```

### GET /hooks/ios-devices

List registered devices (tokens are masked for security).

**Response:**
```json
{
    "count": 2,
    "devices": [
        {
            "token": "abc12345...xyz98765",
            "deviceName": "iPhone 15 Pro",
            "registeredAt": "2024-01-15T10:30:00Z",
            "lastSeenAt": "2024-01-15T12:45:00Z"
        }
    ]
}
```

## Integration with Heartbeat

To send notifications from the Gateway heartbeat system:

```typescript
import { getAPNsNotifier } from './apns-notifier';

// In your heartbeat handler:
async function onHeartbeatAlert(message: string, context?: string) {
    const apns = getAPNsNotifier();
    await apns.sendHeartbeatAlert(message, context);
}
```

## Integration with system.notify Tool

Extend the existing `system.notify` tool to support iOS:

```typescript
import { systemNotifyWithIOS } from './ios-hooks';
import { getAPNsNotifier } from './apns-notifier';

// In your tool handler:
async function handleSystemNotify(params: {
    title: string;
    message: string;
    platform?: 'macos' | 'ios' | 'all';
}) {
    return systemNotifyWithIOS(
        getAPNsNotifier(),
        params,
        existingMacOSNotifyFunction  // Your existing macOS notify
    );
}
```

## Notification Categories

The iOS app supports these notification categories:

| Category | Actions Available |
|----------|-------------------|
| `OPENCLAW_MESSAGE` | Reply, Start Voice Chat |
| `OPENCLAW_HEARTBEAT` | Start Voice Chat, Snooze 1 hour |
| `OPENCLAW_REMINDER` | Start Voice Chat, Snooze 1 hour |

## Custom Data Payload

The `data` field in notifications is passed to the iOS app under the `openclaw` key:

```json
{
    "aps": { "..." },
    "openclaw": {
        "type": "start_conversation",
        "context": "heartbeat",
        "custom_field": "value"
    }
}
```

Supported `type` values:
- `start_conversation` - Opens app and starts voice chat
- `show_message` - Shows an alert with the message
- `open_settings` - Opens the settings screen

## Security

- **Hook Token**: Add authentication to protect your webhooks
- **Device Tokens**: Stored in memory only (add persistence for production)
- **APNs Key**: Keep your .p8 file secure, never commit to git

## Troubleshooting

### "BadDeviceToken" Error
- Device token may be invalid or expired
- Make sure you're using the right environment (sandbox vs production)
- The device token format should be lowercase hex

### "Unregistered" Error
- User has uninstalled the app or disabled notifications
- Device is automatically removed from registry

### Connection Errors
- Check your network/firewall allows outbound connections to Apple's APNs servers
- Sandbox: `api.sandbox.push.apple.com:443`
- Production: `api.push.apple.com:443`

### JWT Token Errors
- Verify your Key ID and Team ID are correct
- Ensure the .p8 file hasn't been modified
- Check the key hasn't been revoked in Apple Developer Portal
