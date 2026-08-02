// ═══════════════════════════════════════════════════════════════════════════
//  Supabase Edge Function: notify
//  ترسل إشعار Firebase Cloud Messaging (FCM HTTP v1) إلى أجهزة مستخدمين محدّدين.
//  المدخل: { user_ids: uuid[], title, message, data? }
//  تجلب رموز الأجهزة من جدول device_tokens ثم ترسل عبر FCM.
//
//  الأسرار المطلوبة (supabase secrets set ...):
//    FIREBASE_SERVICE_ACCOUNT = محتوى ملف حساب الخدمة (JSON) كسلسلة واحدة
//    NOTIFY_SECRET            = سرّ مشترك للتحقّق من أن الطلب من قاعدة بياناتنا
//  (SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY متوفّران تلقائياً)
// ═══════════════════════════════════════════════════════════════════════════
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

const NOTIFY_SECRET = Deno.env.get("NOTIFY_SECRET") ?? "";
const SA_RAW = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function b64url(bytes: Uint8Array): string {
  let s = btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function strToB64url(str: string): string {
  return b64url(new TextEncoder().encode(str));
}

// استيراد المفتاح الخاص (PKCS8 PEM) وتوقيع RS256
async function importKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

// الحصول على access token من حساب الخدمة عبر JWT
async function getAccessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = strToB64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = strToB64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await importKey(sa.private_key);
  const sig = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );
  const jwt = `${unsigned}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await res.json();
  if (!json.access_token) throw new Error("token error: " + JSON.stringify(json));
  return json.access_token;
}

// جلب رموز الأجهزة للمستخدمين
async function tokensFor(userIds: string[]): Promise<string[]> {
  const inList = userIds.map((u) => `"${u}"`).join(",");
  const url = `${SUPABASE_URL}/rest/v1/device_tokens?user_id=in.(${inList})&select=token`;
  const res = await fetch(url, {
    headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}` },
  });
  const rows = await res.json();
  return Array.isArray(rows) ? rows.map((r: any) => r.token).filter(Boolean) : [];
}

serve(async (req) => {
  try {
    if (NOTIFY_SECRET && req.headers.get("x-notify-secret") !== NOTIFY_SECRET) {
      return new Response("forbidden", { status: 403 });
    }
    const { user_ids, title, message, data } = await req.json();
    if (!Array.isArray(user_ids) || user_ids.length === 0) {
      return new Response(JSON.stringify({ skipped: "no recipients" }), { status: 200 });
    }

    const tokens = await tokensFor(user_ids);
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ skipped: "no tokens" }), { status: 200 });
    }

    const sa = JSON.parse(SA_RAW);
    const accessToken = await getAccessToken(sa);
    const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let sent = 0;
    for (const token of tokens) {
      const body: Record<string, unknown> = {
        message: {
          token,
          notification: { title, body: message },
          android: { priority: "high", notification: { sound: "default" } },
          data: data ? Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)]),
          ) : undefined,
        },
      };
      const r = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
        body: JSON.stringify(body),
      });
      if (r.ok) sent++;
    }
    return new Response(JSON.stringify({ sent, total: tokens.length }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
