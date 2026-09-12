// Server-only auth helpers for the admin panel (never import from client
// components). Single shared password via the ADMIN_PASSWORD env var;
// sessions are stateless HMAC tokens in an httpOnly cookie.
import { createHash, createHmac, timingSafeEqual } from "node:crypto";

export const ADMIN_COOKIE = "lineoa_admin_session";
export const SESSION_TTL_SECONDS = 12 * 3600;

function secret(): string {
  return process.env.ADMIN_PASSWORD ?? "";
}

export function isAuthConfigured(): boolean {
  return secret().length > 0;
}

function sha256(value: string): Buffer {
  return createHash("sha256").update(value, "utf8").digest();
}

function safeEqual(a: Buffer, b: Buffer): boolean {
  return a.length === b.length && timingSafeEqual(a, b);
}

// Timing-safe password check (hash both sides so lengths always match).
export function verifyPassword(input: string): boolean {
  const s = secret();
  if (!s || !input) return false;
  return safeEqual(sha256(input), sha256(s));
}

export function createSessionValue(): string {
  return createHmac("sha256", secret()).update("lineoa-admin-session:v1").digest("hex");
}

export function isValidSession(value: string | undefined): boolean {
  if (!isAuthConfigured() || !value) return false;
  return safeEqual(Buffer.from(value, "utf8"), Buffer.from(createSessionValue(), "utf8"));
}
