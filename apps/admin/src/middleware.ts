import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const ADMIN_ONLY_PREFIXES = ["/users", "/locations", "/amenities"];

function isAdminOnly(pathname: string) {
  return ADMIN_ONLY_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get("vibes_admin_token")?.value;
  const role = request.cookies.get("vibes_admin_role")?.value;

  // NextURL.clone() keeps the basePath — redirects land on /admin/... not /
  if (pathname.startsWith("/login")) {
    if (token) {
      const url = request.nextUrl.clone();
      url.pathname = "/";
      return NextResponse.redirect(url);
    }
    return NextResponse.next();
  }

  if (!token) {
    const login = request.nextUrl.clone();
    login.pathname = "/login";
    login.searchParams.set("next", pathname);
    return NextResponse.redirect(login);
  }

  if (isAdminOnly(pathname) && role !== "ADMIN") {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|vibes-logo.png|.*\\.png$|.*\\.jpg$).*)"],
};
