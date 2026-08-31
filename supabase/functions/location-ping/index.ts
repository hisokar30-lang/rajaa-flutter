// supabase/functions/location-ping/index.ts
// Thin wrapper: client calls this; it forwards to zone-agent and returns matches.
// Keeping it separate lets the client use one stable endpoint name (kLocationPingFunction).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const body = await req.json();
  const userId = (req.headers.get('authorization') || '').replace('Bearer ', '').split('.')[0] || body.user_id;
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!);
  // verify the JWT to get the real user id
  const { data: user } = await sb.auth.getUser(body.token ?? (req.headers.get('authorization') || '').replace('Bearer ', ''));
  const uid = user?.user?.id ?? userId;
  const r = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/zone-agent`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!}` },
    body: JSON.stringify({ lat: body.lat, lng: body.lng, user_id: uid }),
  });
  const data = await r.json();
  return new Response(JSON.stringify(data), { status: r.status, headers: cors });
});
