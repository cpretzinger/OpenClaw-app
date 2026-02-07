/**
 * iOS Webhook Handlers for OpenClaw Gateway
 * 
 * Provides webhook endpoints for:
 *   POST /hooks/ios-device   - Register/unregister iOS devices
 *   POST /hooks/ios-notify   - Send push notifications to iOS devices
 * 
 * Usage with Express:
 *   import { createIOSHooksRouter } from './ios-hooks';
 *   app.use('/hooks', createIOSHooksRouter(apnsNotifier));
 * 
 * Usage with Fastify:
 *   import { registerIOSHooks } from './ios-hooks';
 *   registerIOSHooks(fastify, apnsNotifier);
 */

import { APNsNotifier, NotificationPayload } from './apns-notifier';

// ============================================================================
// Types
// ============================================================================

export interface DeviceRegistrationRequest {
    action: 'register' | 'unregister';
    device_token: string;
    device_name?: string;
    device_model?: string;
    os_version?: string;
    app_version?: string;
    bundle_id?: string;
}

export interface NotifyRequest {
    title?: string;
    body?: string;
    message?: string;  // Alias for body
    subtitle?: string;
    category?: 'OPENCLAW_MESSAGE' | 'OPENCLAW_HEARTBEAT' | 'OPENCLAW_REMINDER';
    badge?: number;
    data?: Record<string, any>;
    // Target specific device(s) - if not provided, sends to all
    device_token?: string;
    device_tokens?: string[];
}

export interface HookResponse {
    status: string;
    message?: string;
    error?: string;
    devices_notified?: number;
    results?: any;
}

// ============================================================================
// Handler Functions
// ============================================================================

/**
 * Handle iOS device registration/unregistration
 */
export async function handleIOSDevice(
    apns: APNsNotifier,
    body: DeviceRegistrationRequest,
    authToken?: string
): Promise<{ status: number; body: HookResponse }> {
    
    // Validate required fields
    if (!body.device_token) {
        return {
            status: 400,
            body: { status: 'error', error: 'device_token is required' }
        };
    }

    switch (body.action) {
        case 'register':
            apns.registerDevice(body.device_token, {
                deviceName: body.device_name,
                deviceModel: body.device_model,
                osVersion: body.os_version,
                appVersion: body.app_version
            });
            return {
                status: 200,
                body: { 
                    status: 'registered',
                    message: `Device registered successfully. Total devices: ${apns.getDeviceCount()}`
                }
            };

        case 'unregister':
            const removed = apns.unregisterDevice(body.device_token);
            return {
                status: 200,
                body: { 
                    status: removed ? 'unregistered' : 'not_found',
                    message: removed 
                        ? `Device unregistered. Total devices: ${apns.getDeviceCount()}`
                        : 'Device was not registered'
                }
            };

        default:
            return {
                status: 400,
                body: { status: 'error', error: `Unknown action: ${body.action}` }
            };
    }
}

/**
 * Handle iOS notification sending
 */
export async function handleIOSNotify(
    apns: APNsNotifier,
    body: NotifyRequest,
    authToken?: string
): Promise<{ status: number; body: HookResponse }> {
    
    const messageBody = body.body || body.message;
    
    if (!messageBody) {
        return {
            status: 400,
            body: { status: 'error', error: 'body or message is required' }
        };
    }

    const payload: NotificationPayload = {
        title: body.title || 'OpenClaw',
        body: messageBody,
        subtitle: body.subtitle,
        category: body.category || 'OPENCLAW_MESSAGE',
        badge: body.badge,
        data: body.data || { type: 'start_conversation' }
    };

    // Send to specific device(s) or all
    if (body.device_token) {
        // Single device
        const result = await apns.send(body.device_token, payload);
        return {
            status: result.success ? 200 : 500,
            body: {
                status: result.success ? 'sent' : 'failed',
                devices_notified: result.success ? 1 : 0,
                error: result.error
            }
        };
    } else if (body.device_tokens && body.device_tokens.length > 0) {
        // Multiple specific devices
        const results = await Promise.all(
            body.device_tokens.map(token => apns.send(token, payload))
        );
        const successful = results.filter(r => r.success).length;
        return {
            status: 200,
            body: {
                status: 'sent',
                devices_notified: successful,
                results: results
            }
        };
    } else {
        // All devices
        const result = await apns.sendToAll(payload);
        return {
            status: 200,
            body: {
                status: 'sent',
                devices_notified: result.successful,
                message: `Sent to ${result.successful}/${result.total} devices`
            }
        };
    }
}

/**
 * Get registered devices info
 */
export function handleIOSDeviceList(
    apns: APNsNotifier,
    authToken?: string
): { status: number; body: any } {
    const devices = apns.getDevices().map(d => ({
        token: d.token.substring(0, 8) + '...' + d.token.substring(d.token.length - 8),
        deviceName: d.deviceName,
        deviceModel: d.deviceModel,
        osVersion: d.osVersion,
        appVersion: d.appVersion,
        registeredAt: d.registeredAt,
        lastSeenAt: d.lastSeenAt
    }));

    return {
        status: 200,
        body: {
            count: devices.length,
            devices
        }
    };
}

// ============================================================================
// Express Router Factory
// ============================================================================

/**
 * Create Express router for iOS hooks
 * 
 * Usage:
 *   import express from 'express';
 *   import { createIOSHooksRouter } from './ios-hooks';
 *   import { createAPNsNotifier } from './apns-notifier';
 *   
 *   const app = express();
 *   const apns = createAPNsNotifier();
 *   app.use('/hooks', createIOSHooksRouter(apns));
 */
export function createIOSHooksRouter(apns: APNsNotifier) {
    // This is a generic implementation - adapt to your framework
    return {
        // POST /ios-device
        async postDevice(req: any, res: any) {
            const authToken = req.headers.authorization?.replace('Bearer ', '');
            const result = await handleIOSDevice(apns, req.body, authToken);
            res.status(result.status).json(result.body);
        },
        
        // POST /ios-notify
        async postNotify(req: any, res: any) {
            const authToken = req.headers.authorization?.replace('Bearer ', '');
            const result = await handleIOSNotify(apns, req.body, authToken);
            res.status(result.status).json(result.body);
        },
        
        // GET /ios-devices
        getDevices(req: any, res: any) {
            const authToken = req.headers.authorization?.replace('Bearer ', '');
            const result = handleIOSDeviceList(apns, authToken);
            res.status(result.status).json(result.body);
        }
    };
}

// ============================================================================
// Integration with OpenClaw system.notify Tool
// ============================================================================

/**
 * Extended system.notify function that supports iOS
 * 
 * This should be integrated into the Gateway's tool handler
 * 
 * Usage in agent tools:
 *   system.notify({ title: "Hello", message: "World", platform: "ios" })
 */
export async function systemNotifyWithIOS(
    apns: APNsNotifier | null,
    params: {
        title: string;
        message: string;
        platform?: 'macos' | 'ios' | 'all';
    },
    macosNotifyFn?: (title: string, message: string) => Promise<void>
): Promise<{ sent_to: string[] }> {
    const platform = params.platform || 'all';
    const sentTo: string[] = [];

    // macOS notification (existing functionality)
    if ((platform === 'macos' || platform === 'all') && macosNotifyFn) {
        await macosNotifyFn(params.title, params.message);
        sentTo.push('macos');
    }

    // iOS notification (new functionality)
    if ((platform === 'ios' || platform === 'all') && apns) {
        const deviceCount = apns.getDeviceCount();
        if (deviceCount > 0) {
            await apns.sendMessageNotification(params.title, params.message);
            sentTo.push(`ios (${deviceCount} devices)`);
        }
    }

    return { sent_to: sentTo };
}
