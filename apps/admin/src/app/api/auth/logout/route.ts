import { NextResponse } from "next/server";
import { ADMIN_COOKIE } from "@/lib/auth";

function clearAndRedirect(req: Request) {
  const res = NextResponse.redirect(new URL("/login", req.url));
  res.cookies.set(ADMIN_COOKIE, "", { httpOnly: true, path: "/", maxAge: 0 });
  return res;
}

export async function POST(req: Request) {
  return clearAndRedirect(req);
}

export async function GET(req: Request) {
  return clearAndRedirect(req);
}
