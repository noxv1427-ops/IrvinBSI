import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

function generateTemporaryPassword() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
  const values = crypto.getRandomValues(new Uint32Array(12));
  return Array.from(values, (value) => alphabet[value % alphabet.length]).join('');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !anonKey || !serviceRoleKey) return response({ error: 'Konfigurasi layanan tidak tersedia.' }, 500);

    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return response({ error: 'Tidak berwenang.' }, 401);
    const token = authorization.slice('Bearer '.length);
    const callerClient = createClient(supabaseUrl, anonKey);
    const { data: userData, error: userError } = await callerClient.auth.getUser(token);
    if (userError || !userData.user) return response({ error: 'Tidak berwenang.' }, 401);

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { data: callerProfile, error: profileError } = await adminClient.from('profiles').select('role,status').eq('id', userData.user.id).maybeSingle();
    if (profileError || callerProfile?.role !== 'super_admin' || callerProfile.status !== 'aktif') return response({ error: 'Tidak berwenang.' }, 403);

    const payload = await request.json() as { user_id?: string };
    if (!payload.user_id || payload.user_id === userData.user.id) return response({ error: 'Pengguna tidak valid.' }, 400);
    const password = generateTemporaryPassword();
    const { error: updateError } = await adminClient.auth.admin.updateUserById(payload.user_id, { password });
    if (updateError) return response({ error: 'Password belum dapat diatur ulang.' }, 500);
    return response({ temporary_password: password });
  } catch (error) {
    console.error('reset-password failed', error);
    return response({ error: 'Password belum dapat diatur ulang.' }, 500);
  }
});
