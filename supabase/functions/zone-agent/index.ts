// supabase/functions/zone-agent/index.ts
// Core Zone Alert Agent (FR-5.2). Receives a location ping, matches active open posts
// within their radius via PostGIS match_zones(), records a dedupe zone_event, and pushes FCM.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { initializeApp, cert } from 'https://esm.sh/firebase-admin@12';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const body = await req.json();
    const lat = Number(body.lat), lng = Number(body.lng);
    const userId = body.user_id ?? (req.headers.get('x-user-id') || '');
    if (!lat || !lng) return new Response(JSON.stringify({ error: 'lat/lng required' }), { status: 400, headers: cors });

    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    // 1) match zones (RLS bypass via service role; function enforces ownership + daily dedup)
    const { data: matches, error } = await sb.rpc('match_zones', { p_lat: lat, p_lng: lng, p_user: userId });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: cors });

    const out: any[] = [];
    for (const m of (matches ?? []) as any[]) {
      // 2) record dedupe zone_event
      await sb.from('zone_events').upsert({ user_id: userId, post_id: m.post_id }, onConflict: 'user_id,post_id').then(() => {});
      // 3) push FCM to the POST OWNER (not the pinging user) if they opted in
      const owner = await sb.from('users').select('settings_json').eq('id', m.user_id).maybeSingle();
      const fcm = (owner?.data?.settings_json as any)?.fcm_token as string | undefined;
      if (fcm) await pushFcm(fcm, m);
      out.push(m);
    }
    return new Response(JSON.stringify({ matches: out }), { status: 200, headers: cors });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: cors });
  }
});

async function pushFcm(token: string, post: any) {
  try {
    const serverKey = Deno.env.get('FCM_SERVER_KEY');
    if (!serverKey) return;
    await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `key=${serverKey}` },
      body: JSON.stringify({
        to: token,
        notification: { title: '👀 غرض مفقود قريب منك', body: `احتفظ بعينيك: ${post.title} — داخل منطقة البحث.` },
        data: { post_id: post.post_id, type: 'zone' },
      }),
    });
  } catch { /* best-effort */ }
}
