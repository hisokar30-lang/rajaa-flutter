// supabase/functions/location-ping/index.ts
// Thin wrapper: client calls this; it forwards to zone-agent and returns matches.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const body = await req.json();
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!);
    const authHeader = (req.headers.get('authorization') || '').replace('Bearer ', '');
    const { data: user } = await sb.auth.getUser(body.token ?? authHeader);
    const uid = user?.user?.id ?? (body.user_id || authHeader.split('.')[0]);
    const svc = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const zoneUrl = Deno.env.get('SUPABASE_URL')! + '/functions/v1/zone-agent';
    const r = await fetch(zoneUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + svc },
      body: JSON.stringify({ lat: body.lat, lng: body.lng, user_id: uid }),
    });
    const data = await r.json();
    return new Response(JSON.stringify(data), { status: r.status, headers: cors });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: cors });
  }
});
