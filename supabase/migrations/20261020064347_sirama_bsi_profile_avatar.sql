/*
# Profil pengguna: foto profil dan edit mandiri

1. Kolom baru
- `profiles.avatar_url`: path foto profil pada bucket `avatars`.

2. RPC baru
- `update_profile_saya(p_full_name, p_avatar_url)`: pengguna memperbarui nama dan foto profil sendiri.

3. Sinkronisasi email
- Trigger `sync_profile_email` memperbarui `profiles.email` saat `auth.users.email` berubah.

4. Storage
- Bucket publik `avatars` untuk foto profil (jpg, png, webp; maks 5 MB).
- Kebijakan: baca publik, tulis/hapus hanya pemilik.

5. Keamanan
- RPC dan trigger bersifat SECURITY DEFINER dengan search_path tetap.
- EXECUTE hanya untuk authenticated.
*/

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;

CREATE OR REPLACE FUNCTION public.update_profile_saya(p_full_name text, p_avatar_url text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Tidak berwenang'; END IF;
  UPDATE public.profiles
  SET full_name = nullif(trim(p_full_name), ''),
      avatar_url = nullif(trim(p_avatar_url), '')
  WHERE id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Profil tidak ditemukan'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_profile_saya(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_profile_saya(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.sync_profile_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    UPDATE public.profiles SET email = lower(NEW.email) WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_email ON auth.users;
CREATE TRIGGER sync_profile_email AFTER UPDATE OF email ON auth.users
  FOR EACH ROW WHEN (NEW.email IS DISTINCT FROM OLD.email)
  EXECUTE FUNCTION public.sync_profile_email();

REVOKE ALL ON FUNCTION public.sync_profile_email() FROM PUBLIC, anon;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 5242880, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "avatars_select_public" ON storage.objects;
CREATE POLICY "avatars_select_public" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
