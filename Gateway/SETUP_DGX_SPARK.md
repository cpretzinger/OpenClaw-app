# iOS Push Notifications Plugin for OpenClaw Gateway

Complete step-by-step guide to configure push notifications on your DGX Spark server using OpenClaw's plugin system.

---

## Architecture

This plugin integrates with OpenClaw Gateway via:
- **Plugin System** — Loaded as an OpenClaw extension
- **Hooks** — Responds to heartbeat and agent events  
- **HTTP Endpoints** — Device registration and manual notifications
- **Tool Extension** — Extends `system.notify` to support iOS

---

## Prerequisites

- SSH access to your DGX Spark server
- Apple Developer Account (paid membership)
- OpenClaw Gateway already running on DGX Spark

---

## Part 1: Generate APNs Key (Apple Developer Portal)

### Step 1.1: Log in to Apple Developer Portal

1. Open [https://developer.apple.com/account](https://developer.apple.com/account)
2. Sign in with your Apple ID

### Step 1.2: Create APNs Authentication Key

1. Go to **Certificates, Identifiers & Profiles**
2. In the left sidebar, click **Keys**
3. Click the **"+"** button to create a new key
4. Enter Key Name: `OpenClaw iOS Push`
5. Check the box for **Apple Push Notifications service (APNs)**
6. Click **Continue**
7. Click **Register**

### Step 1.3: Download the Key

⚠️ **IMPORTANT: You can only download this file ONCE!**

1. Click **Download** to get the `.p8` file
2. Save it somewhere safe (e.g., `AuthKey_ABC123DEFG.p8`)
3. **Note down the Key ID** shown on the page (10 characters, e.g., `ABC123DEFG`)

### Step 1.4: Get Your Team ID

1. Go to [Membership Details](https://developer.apple.com/account/#/membership)
2. Find and copy your **Team ID** (10 characters, e.g., `TEAM123456`)

---

## Part 2: Transfer Key to DGX Spark

### Step 2.1: Create Directory on DGX Spark

```bash
# SSH into your DGX Spark
ssh your-username@your-dgx-spark-ip

# Create directory for APNs key
mkdir -p ~/.config/openclaw/keys
chmod 700 ~/.config/openclaw/keys
```

### Step 2.2: Transfer the .p8 Key File

From your local Mac terminal:

```bash
# Replace with your actual values
scp ~/Downloads/AuthKey_ABC123DEFG.p8 your-username@your-dgx-spark-ip:~/.config/openclaw/keys/
```

### Step 2.3: Secure the Key File

On DGX Spark:

```bash
chmod 600 ~/.config/openclaw/keys/AuthKey_*.p8
```

---

## Part 3: Install the Plugin

### Step 3.1: Create Plugin Directory

```bash
# On DGX Spark
mkdir -p ~/.openclaw/extensions/ios-push-notifications
cd ~/.openclaw/extensions/ios-push-notifications
```

### Step 3.2: Transfer Plugin Files

From your Mac terminal:

```bash
# Transfer all plugin files
scp "/Users/antaresgryczan/Library/Mobile Documents/com~apple~CloudDocs/Xcode aps/OpenClaw/OpenClaw/Gateway/"*.ts your-username@your-dgx-spark:~/.openclaw/extensions/ios-push-notifications/

scp "/Users/antaresgryczan/Library/Mobile Documents/com~apple~CloudDocs/Xcode aps/OpenClaw/OpenClaw/Gateway/openclaw.plugin.json" your-username@your-dgx-spark:~/.openclaw/extensions/ios-push-notifications/
```

### Step 3.3: Install Dependencies

On DGX Spark:

```bash
cd ~/.openclaw/extensions/ios-push-notifications

# Create package.json
cat > package.json << 'EOF'
{
  "name": "ios-push-notifications",
  "version": "1.0.0",
  "dependencies": {
    "jsonwebtoken": "^9.0.0"
  }
}
EOF

# Install dependencies
npm install
```

### Step 3.4: Verify Plugin Structure

```bash
ls -la ~/.openclaw/extensions/ios-push-notifications/
```

You should see:
```
openclaw.plugin.json
index.ts
apns-notifier.ts
ios-hooks.ts
package.json
node_modules/
```

---

## Part 4: Configure the Plugin

### Step 4.1: Edit Gateway Config

Open your OpenClaw Gateway configuration:

```bash
nano ~/.openclaw/gateway.config.json
```

### Step 4.2: Add Plugin Configuration

Add or update the `plugins` section:

```json
{
  "plugins": {
    "load": {
      "paths": ["~/.openclaw/extensions/ios-push-notifications"]
    },
    "entries": {
      "ios-push-notifications": {
        "enabled": true,
        "config": {
          "apns": {
            "keyPath": "/home/YOUR_USERNAME/.config/openclaw/keys/AuthKey_ABC123DEFG.p8",
            "keyId": "ABC123DEFG",
            "teamId": "TEAM123456",
            "bundleId": "carc.ai.OpenClaw",
            "sandbox": true
          },
          "notifications": {
            "enabled": true,
            "onHeartbeat": true,
            "onAgentMessage": false,
            "quietHoursStart": "22:00",
            "quietHoursEnd": "08:00"
          },
          "hooks": {
            "enabled": true,
            "authToken": "your-secret-token-here"
          }
        }
      }
    }
  }
}
```

### Step 4.3: Replace Values

Replace in the config:
- `YOUR_USERNAME` → your actual DGX Spark username
- `ABC123DEFG` → your Key ID from Apple
- `TEAM123456` → your Team ID from Apple
- `carc.ai.OpenClaw` → your iOS app's bundle identifier
- `your-secret-token-here` → a secure random token for webhook auth

### Step 4.4: Generate Auth Token (Optional but Recommended)

```bash
# Generate a secure token
openssl rand -hex 32
```

Copy the output and use it as `authToken` in the config.

---

## Part 5: Restart Gateway

```bash
openclaw gateway restart
```

Check logs for successful initialization:

```bash
openclaw gateway logs | grep "iOS Push"
```

You should see:
```
[iOS Push] Activating plugin...
[iOS Push] APNs initialized (Sandbox)
[iOS Push] HTTP hooks registered
[iOS Push] Event listeners registered
[iOS Push] Extended system.notify tool
[iOS Push] Plugin activated successfully
```

---

## Part 6: Test the Setup

### Step 6.1: Check Plugin Status

```bash
openclaw plugins list
```

Should show `ios-push-notifications` as enabled.

### Step 6.2: Test Device Registration

From your Mac terminal:

```bash
curl -X POST https://your-dgx-spark.ts.net/hooks/ios-device \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secret-token-here" \
  -d '{
    "action": "register",
    "device_token": "test123456789",
    "device_name": "Test Device"
  }'
```

Expected response:
```json
{
  "status": "registered",
  "message": "Device registered successfully. Total devices: 1"
}
```

### Step 6.3: Test Notification

```bash
curl -X POST https://your-dgx-spark.ts.net/hooks/ios-notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secret-token-here" \
  -d '{
    "title": "Test Notification",
    "body": "Hello from OpenClaw!",
    "category": "OPENCLAW_MESSAGE"
  }'
```

### Step 6.4: List Devices

```bash
curl https://your-dgx-spark.ts.net/hooks/ios-devices \
  -H "Authorization: Bearer your-secret-token-here"
```

---

## Part 7: Configure iOS App

### Step 7.1: Set Gateway Endpoint

1. Open OpenClaw iOS app
2. Go to **Settings**
3. Set **OpenClaw Endpoint** to: `https://your-dgx-spark.ts.net`
4. Set **Gateway Hook Token** to: `your-secret-token-here`

### Step 7.2: Enable Notifications

1. In Settings, find **Notifications** section
2. Tap **Enable Notifications**
3. Allow notifications when prompted
4. The app will automatically register with the Gateway

---

## Part 8: Using system.notify with iOS

Once configured, agents can send iOS notifications using the extended `system.notify` tool:

```
system.notify({
  title: "Reminder",
  message: "Don't forget your meeting!",
  platform: "ios"  // or "all" for both macOS and iOS
})
```

---

## Configuration Reference

### Plugin Config Schema

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `apns.keyPath` | string | Yes | - | Path to .p8 key file |
| `apns.keyId` | string | Yes | - | Key ID from Apple |
| `apns.teamId` | string | Yes | - | Team ID from Apple |
| `apns.bundleId` | string | No | `carc.ai.OpenClaw` | App bundle identifier |
| `apns.sandbox` | boolean | No | `true` | Use sandbox environment |
| `notifications.enabled` | boolean | No | `true` | Enable notifications |
| `notifications.onHeartbeat` | boolean | No | `true` | Notify on heartbeat alerts |
| `notifications.onAgentMessage` | boolean | No | `false` | Notify on agent messages |
| `notifications.quietHoursStart` | string | No | - | Quiet hours start (HH:MM) |
| `notifications.quietHoursEnd` | string | No | - | Quiet hours end (HH:MM) |
| `hooks.enabled` | boolean | No | `true` | Enable HTTP webhooks |
| `hooks.authToken` | string | No | - | Bearer token for auth |

### HTTP Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/hooks/ios-device` | POST | Register/unregister device |
| `/hooks/ios-notify` | POST | Send notification |
| `/hooks/ios-devices` | GET | List registered devices |

---

## Troubleshooting

### Plugin Not Loading

```bash
# Check plugin is in correct location
ls ~/.openclaw/extensions/ios-push-notifications/

# Check for syntax errors in config
openclaw config validate
```

### APNs Initialization Failed

- Verify key path is correct and file exists
- Check Key ID and Team ID are correct (10 characters each)
- Ensure .p8 file has read permissions

### Notifications Not Received

1. Check device is registered: `GET /hooks/ios-devices`
2. Verify `notifications.enabled` is `true`
3. Check quiet hours settings
4. Ensure `sandbox: true` for development builds

### Authentication Errors

- Verify `authToken` matches between config and iOS app
- Include `Authorization: Bearer <token>` header in requests

---

## Security Checklist

- [ ] APNs .p8 key has `chmod 600` permissions
- [ ] Key file is NOT in git repository
- [ ] Auth token is set and sufficiently random
- [ ] Quiet hours configured to prevent night notifications
- [ ] Gateway config file has restricted permissions

---

## Quick Reference

| Item | Value/Location |
|------|----------------|
| Bundle ID | `carc.ai.OpenClaw` |
| Plugin Directory | `~/.openclaw/extensions/ios-push-notifications/` |
| APNs Key Location | `~/.config/openclaw/keys/AuthKey_XXX.p8` |
| Gateway Config | `~/.openclaw/gateway.config.json` |
| Webhook: Register | `POST /hooks/ios-device` |
| Webhook: Notify | `POST /hooks/ios-notify` |
| Webhook: List | `GET /hooks/ios-devices` |
