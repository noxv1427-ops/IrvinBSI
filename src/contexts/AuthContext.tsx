import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';

export type Profile = { id: string; email: string; full_name: string; role: 'admin' | 'super_admin'; status: 'menunggu' | 'aktif' | 'ditolak' | 'nonaktif'; reject_reason: string | null; avatar_url: string | null };
type AuthValue = { session: Session | null; profile: Profile | null; profileError: string | null; loading: boolean; pendingCount: number; signOut: () => Promise<void>; refreshProfile: () => Promise<void>; refreshPendingCount: () => Promise<void> };
const AuthContext = createContext<AuthValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [pendingCount, setPendingCount] = useState(0);

  const loadProfile = useCallback(async (userId: string | null) => {
    setProfileError(null);
    if (!userId) {
      setProfile(null);
      return;
    }
    const { data, error } = await supabase.from('profiles').select('id,email,full_name,role,status,reject_reason,avatar_url').eq('id', userId).maybeSingle();
    if (error) {
      console.error('Profil tidak dapat dimuat:', error);
      setProfile(null);
      setProfileError(error.message);
      return;
    }
    if (!data) {
      const missingMessage = `Profil tidak ditemukan untuk pengguna ${userId}.`;
      console.error('Profil tidak dapat dimuat:', missingMessage);
      setProfile(null);
      setProfileError(missingMessage);
      return;
    }
    setProfile(data as Profile);
  }, []);

  const refreshProfile = useCallback(async () => {
    await loadProfile(session?.user.id ?? null);
  }, [loadProfile, session]);

  const refreshPendingCount = useCallback(async () => {
    if (profile?.role !== 'super_admin' || profile.status !== 'aktif') {
      setPendingCount(0);
      return;
    }
    const { count } = await supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('status', 'menunggu');
    setPendingCount(count ?? 0);
  }, [profile]);

  useEffect(() => {
    let mounted = true;
    supabase.auth.getSession().then(async ({ data }) => {
      if (!mounted) return;
      setSession(data.session);
      await loadProfile(data.session?.user.id ?? null);
      if (mounted) setLoading(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setLoading(Boolean(nextSession));
      void (async () => {
        await loadProfile(nextSession?.user.id ?? null);
        if (mounted) setLoading(false);
      })();
    });
    return () => {
      mounted = false;
      listener.subscription.unsubscribe();
    };
  }, [loadProfile]);

  useEffect(() => {
    void refreshPendingCount();
    if (profile?.role === 'super_admin') {
      const timer = window.setInterval(() => void refreshPendingCount(), 60000);
      return () => window.clearInterval(timer);
    }
  }, [profile, refreshPendingCount]);

  const value = useMemo(() => ({ session, profile, profileError, loading, pendingCount, signOut: () => supabase.auth.signOut().then(() => undefined), refreshProfile, refreshPendingCount }), [session, profile, profileError, loading, pendingCount, refreshProfile, refreshPendingCount]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() { const value = useContext(AuthContext); if (!value) throw new Error('AuthProvider diperlukan'); return value; }
