/**
 * iOS Push Notifications Plugin for OpenClaw Gateway
 * 
 * This plugin provides the send_ios_notification tool for sending
 * push notifications to iOS devices via APNs.
 * 
 * Installation on DGX Spark:
 *   1. Copy this folder to ~/.openclaw/extensions/ios-push-notifications/
 *   2. Compile TypeScript: npx tsc (or use the pre-compiled JS files)
 *   3. Configure in ~/.openclaw/openclaw.json
 *   4. Restart gateway: openclaw gateway restart
 * 
 * Configuration in openclaw.json:
 *   "plugins": {
 *     "load": {
 *       "paths": ["/home/antares/.openclaw/extensions/ios-push-notifications"]
 *     },
 *     "entries": {
 *       "ios-push-notifications": {
 *         "enabled": true,
 *         "config": {
 *           "apns": {
 *             "keyPath": "/path/to/AuthKey_XXXXXX.p8",
 *             "keyId": "YOUR_KEY_ID",
 *             "teamId": "YOUR_TEAM_ID",
 *             "bundleId": "carc.ai.OpenClaw",
 *             "sandbox": true
 *           }
 *         }
 *       }
 *     }
 *   }
 */

import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { emptyPluginConfigSchema } from "openclaw/plugin-sdk";
import { ApnsNotifier } from "./apns-notifier.js";

interface ApnsConfig {
  keyPath: string;
  keyId: string;
  teamId: string;
  bundleId: string;
  sandbox?: boolean;
}

interface PluginConfig {
  apns?: ApnsConfig;
}

const plugin = {
  id: "ios-push-notifications",
  name: "iOS Push Notifications",
  description: "Send push notifications to iOS devices via APNs",
  configSchema: emptyPluginConfigSchema(),
  
  register(api: OpenClawPluginApi) {
    const pluginConfig = (api as any).pluginConfig as PluginConfig | undefined;
    
    console.log("[ios-push-notifications] pluginConfig:", JSON.stringify(pluginConfig, null, 2));
    
    if (pluginConfig?.apns) {
      console.log("[ios-push-notifications] Found APNs config, initializing...");
      
      const notifier = new ApnsNotifier({
        keyPath: pluginConfig.apns.keyPath,
        keyId: pluginConfig.apns.keyId,
        teamId: pluginConfig.apns.teamId,
        bundleId: pluginConfig.apns.bundleId,
        sandbox: pluginConfig.apns.sandbox ?? true,
      });
      
      api.registerTool({
        name: "send_ios_notification",
        description: "Send a push notification to an iOS device. Use this to alert the user on their iPhone.",
        parameters: {
          type: "object",
          properties: {
            deviceToken: {
              type: "string",
              description: "The APNs device token for the target iOS device (64 character hex string)",
            },
            title: {
              type: "string",
              description: "The notification title (shown prominently)",
            },
            body: {
              type: "string",
              description: "The notification body text (shown below the title)",
            },
            badge: {
              type: "number",
              description: "Optional badge number to display on the app icon",
            },
            sound: {
              type: "string",
              description: "Optional sound name (default: 'default')",
            },
          },
          required: ["deviceToken", "title", "body"],
        },
        execute: async (params: {
          deviceToken: string;
          title: string;
          body: string;
          badge?: number;
          sound?: string;
        }) => {
          console.log("[ios-push-notifications] ========== EXECUTE CALLED ==========");
          console.log("[ios-push-notifications] Params:", JSON.stringify(params, null, 2));
          try {
            await notifier.send(params.deviceToken, {
              title: params.title,
              body: params.body,
              badge: params.badge,
              sound: params.sound ?? "default",
            });
            console.log("[ios-push-notifications] SUCCESS!");
            return { success: true, message: "Notification sent successfully" };
          } catch (error) {
            console.error("[ios-push-notifications] ERROR:", error);
            const errorMessage = error instanceof Error ? error.message : "Unknown error";
            return { success: false, error: errorMessage };
          }
        },
      });
      
      console.log("[ios-push-notifications] Plugin registered successfully with tool: send_ios_notification");
    } else {
      console.warn("[ios-push-notifications] No APNs configuration found in pluginConfig");
    }
  },
};

export default plugin;
