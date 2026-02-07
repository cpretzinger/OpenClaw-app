/**
 * APNs Notifier - HTTP/2 implementation for Apple Push Notification service
 * 
 * Uses HTTP/2 as required by APNs (HTTP/1.1 is not supported)
 */

import * as fs from "fs";
import * as crypto from "crypto";
import * as http2 from "http2";

export interface ApnsConfig {
  keyPath: string;
  keyId: string;
  teamId: string;
  bundleId: string;
  sandbox?: boolean;
}

export interface NotificationPayload {
  title: string;
  body: string;
  badge?: number;
  sound?: string;
  data?: Record<string, unknown>;
}

export class ApnsNotifier {
  private keyPath: string;
  private keyId: string;
  private teamId: string;
  private bundleId: string;
  private sandbox: boolean;
  private cachedToken: string | null = null;
  private tokenExpiry: number = 0;

  constructor(config: ApnsConfig) {
    this.keyPath = config.keyPath;
    this.keyId = config.keyId;
    this.teamId = config.teamId;
    this.bundleId = config.bundleId;
    this.sandbox = config.sandbox ?? true;
    console.log("[ApnsNotifier] Initialized with bundleId:", this.bundleId, "sandbox:", this.sandbox);
  }

  private getAuthToken(): string {
    const now = Math.floor(Date.now() / 1000);
    
    if (this.cachedToken && now < this.tokenExpiry - 600) {
      return this.cachedToken;
    }

    const privateKey = fs.readFileSync(this.keyPath, "utf8");
    const header = { alg: "ES256", kid: this.keyId };
    const payload = { iss: this.teamId, iat: now };

    const encodedHeader = Buffer.from(JSON.stringify(header)).toString("base64url");
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString("base64url");

    const signatureInput = `${encodedHeader}.${encodedPayload}`;
    const sign = crypto.createSign("SHA256");
    sign.update(signatureInput);
    const signature = sign.sign(privateKey);
    
    const rawSignature = this.derToRaw(signature);
    const encodedSignature = rawSignature.toString("base64url");

    this.cachedToken = `${signatureInput}.${encodedSignature}`;
    this.tokenExpiry = now + 3600;

    return this.cachedToken;
  }

  private derToRaw(derSignature: Buffer): Buffer {
    let offset = 2;
    if (derSignature[1] & 0x80) {
      offset += derSignature[1] & 0x7f;
    }
    
    const rLength = derSignature[offset + 1];
    const rStart = offset + 2;
    let r = derSignature.subarray(rStart, rStart + rLength);
    
    const sOffset = rStart + rLength;
    const sLength = derSignature[sOffset + 1];
    const sStart = sOffset + 2;
    let s = derSignature.subarray(sStart, sStart + sLength);
    
    if (r.length > 32) r = r.subarray(r.length - 32);
    if (s.length > 32) s = s.subarray(s.length - 32);
    
    const rawSignature = Buffer.alloc(64);
    r.copy(rawSignature, 32 - r.length);
    s.copy(rawSignature, 64 - s.length);
    
    return rawSignature;
  }

  async send(deviceToken: string, payload: NotificationPayload): Promise<void> {
    console.log("[ApnsNotifier] send() called for token:", deviceToken.substring(0, 8) + "...");
    
    const host = this.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
    
    const apnsPayload = {
      aps: {
        alert: { title: payload.title, body: payload.body },
        badge: payload.badge,
        sound: payload.sound ?? "default",
      },
      ...payload.data,
    };

    const body = JSON.stringify(apnsPayload);
    const token = this.getAuthToken();

    return new Promise((resolve, reject) => {
      const client = http2.connect(`https://${host}`);
      
      client.on("error", (err: Error) => {
        console.error("[ApnsNotifier] HTTP/2 connection error:", err.message);
        reject(new Error(`HTTP/2 connection error: ${err.message}`));
      });

      const req = client.request({
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        "authorization": `bearer ${token}`,
        "apns-topic": this.bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
        "content-length": Buffer.byteLength(body).toString(),
      });

      let responseData = "";
      let statusCode: number | undefined;

      req.on("response", (headers: http2.IncomingHttpHeaders) => {
        statusCode = headers[":status"] as number;
        console.log("[ApnsNotifier] Response status:", statusCode);
      });

      req.on("data", (chunk: Buffer) => {
        responseData += chunk.toString();
      });

      req.on("end", () => {
        client.close();
        if (statusCode === 200) {
          console.log("[ApnsNotifier] Notification sent successfully!");
          resolve();
        } else {
          console.error("[ApnsNotifier] APNs error:", statusCode, responseData);
          reject(new Error(`APNs error ${statusCode}: ${responseData}`));
        }
      });

      req.on("error", (err: Error) => {
        client.close();
        reject(new Error(`Request error: ${err.message}`));
      });

      req.write(body);
      req.end();
    });
  }
}
