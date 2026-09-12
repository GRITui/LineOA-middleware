import { NextResponse } from "next/server";
import {
  ADMIN_COOKIE,
  SESSION_TTL_SECONDS,
  createSessionValue,
  isAuthConfigured,
  verifyPassword,
} from "@/lib/auth";

export async function POST(req: Request) {
  if (!isAuthConfigured()) {
    return NextResponse.json(
      { error: "Admin auth is not configured (set ADMIN_PASSWORD)" },
      { status: 503 }
    );
  }

  let password: unknown;
  try {
    password = (await req.json()).password;
  } catch {
    password = undefined;
  }

  if (typeof password !== "string" || !verifyPassword(password)) {
    return NextResponse.json({ error: "Invalid password" }, { status: 401 });
  }

  const res = NextResponse.json({ ok: true });
  res.cookies.set(ADMIN_COOKIE, createSessionValue(), {
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_TTL_SECONDS,
    ...(process.env.NODE_ENV === "production" ? { secure: true } : {}),
  });
  return res;
}
