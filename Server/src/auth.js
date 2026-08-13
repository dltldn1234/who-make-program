import { timingSafeEqual } from "node:crypto";

export function isAuthorized(presentedToken, expectedToken) {
  if (typeof presentedToken !== "string" || typeof expectedToken !== "string") return false;
  const presented = Buffer.from(presentedToken, "utf8");
  const expected = Buffer.from(expectedToken, "utf8");
  if (presented.length !== expected.length) return false;
  return timingSafeEqual(presented, expected);
}
