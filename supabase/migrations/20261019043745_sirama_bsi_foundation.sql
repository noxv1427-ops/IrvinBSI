/*
# Fondasi SIRAMA BSI

1. Tabel baru
- `profiles`: identitas pengguna, peran, status persetujuan, dan jejak peninjauan.
- `surat_masuk`: metadata surat masuk, persetujuan, lampiran, pembatalan, dan pembuat.
- Bucket privat `lampiran` pada Storage untuk berkas surat.

2. Keamanan
- RLS aktif pada seluruh tabel aplikasi.
- Profil hanya dapat dibaca oleh pemiliknya atau Super Admin; perubahan status hanya melalui RPC berizin.
- Surat hanya dapat diakses pengguna aktif; kolom audit dan pembatalan dilindungi.
- Bucket privat membatasi ukuran dan tipe berkas, serta akses berdasarkan pengguna aktif.
- Semua fungsi memiliki search_path tetap dan hak EXECUTE paling minimal.

3. Alur akun
- Pendaftaran dibatasi ke email `@bankbsi.co.id`.
- Profil dibuat otomatis sebagai `admin` dan `menunggu`, tanpa mempercayai metadata peran dari klien.
- Super Admin dapat menyetujui, menolak, atau menonaktifkan akun melalui `set_status_akun`.
- Pengguna yang ditolak dapat mengajukan ulang melalui `ajukan_ulang`.
*/

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin')),
  status text NOT NULL DEFAULT 'menunggu' CHECK (status IN ('menunggu', 'aktif', 'ditolak', 'nonaktif')),
  reviewed_by uuid REFERENCES public.profiles(id),
  reviewed_at timestamptz,
  reject_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.surat_masuk (
  no integer GENERATED ALWAYS AS IDENTITY (START WITH 1) UNIQUE NOT NULL,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tanggal date NOT NULL,
  jenis_surat text NOT NULL,
  penerima text NOT NULL,
  diterima_oleh text NOT NULL,
  approval text NOT NULL DEFAULT 'menunggu' CHECK (approval IN ('menunggu', 'disetujui', 'ditolak')),
  approved_by uuid REFERENCES public.profiles(id),
  approved_at timestamptz,
  keterangan text,
  lampiran_path text,
  lampiran_nama text,
  dibatalkan boolean NOT NULL DEFAULT false,
  dibatalkan_oleh uuid REFERENCES public.profiles(id),
  dibatalkan_at timestamptz,
  created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.surat_masuk ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_aktif()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND status = 'aktif');
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin' AND status = 'aktif');
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.email IS NULL OR lower(NEW.email) NOT LIKE '%@bankbsi.co.id' THEN
    RAISE EXCEPTION 'Pendaftaran hanya untuk email Bank Syariah Indonesia';
  END IF;
  INSERT INTO public.profiles (id, email, full_name, role, status)
  VALUES (NEW.id, lower(NEW.email), COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''), 'admin', 'menunggu');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.set_status_akun(p_user_id uuid, p_status_baru text, p_alasan text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_super_admin() THEN RAISE EXCEPTION 'Tidak berwenang'; END IF;
  IF p_user_id = auth.uid() THEN RAISE EXCEPTION 'Tidak dapat mengubah status sendiri'; END IF;
  IF p_status_baru NOT IN ('aktif', 'ditolak', 'nonaktif') THEN RAISE EXCEPTION 'Status tidak valid'; END IF;
  IF p_status_baru = 'ditolak' AND nullif(trim(p_alasan), '') IS NULL THEN RAISE EXCEPTION 'Alasan penolakan wajib diisi'; END IF;
  UPDATE public.profiles SET status = p_status_baru, reject_reason = CASE WHEN p_status_baru = 'ditolak' THEN trim(p_alasan) ELSE NULL END, reviewed_by = auth.uid(), reviewed_at = now() WHERE id = p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Akun tidak ditemukan'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.ajukan_ulang()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE public.profiles SET status = 'menunggu', reject_reason = NULL, reviewed_by = NULL, reviewed_at = NULL WHERE id = auth.uid() AND status = 'ditolak';
  IF NOT FOUND THEN RAISE EXCEPTION 'Akun tidak dapat diajukan ulang'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_surat_audit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    IF NEW.dibatalkan IS DISTINCT FROM OLD.dibatalkan OR NEW.dibatalkan_oleh IS DISTINCT FROM OLD.dibatalkan_oleh OR NEW.dibatalkan_at IS DISTINCT FROM OLD.dibatalkan_at OR NEW.approval IS DISTINCT FROM OLD.approval OR NEW.approved_by IS DISTINCT FROM OLD.approved_by OR NEW.approved_at IS DISTINCT FROM OLD.approved_at OR NEW.created_by IS DISTINCT FROM OLD.created_by OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Kolom audit hanya dapat diubah melalui alur resmi';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_surat_audit_before_update ON public.surat_masuk;
CREATE TRIGGER guard_surat_audit_before_update BEFORE UPDATE ON public.surat_masuk FOR EACH ROW EXECUTE FUNCTION public.guard_surat_audit();

CREATE OR REPLACE FUNCTION public.batalkan_surat(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_super_admin() THEN RAISE EXCEPTION 'Tidak berwenang'; END IF;
  UPDATE public.surat_masuk SET dibatalkan = true, dibatalkan_oleh = auth.uid(), dibatalkan_at = now() WHERE id = p_id AND dibatalkan = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Surat tidak ditemukan atau sudah dibatalkan'; END IF;
END;
$$;

DROP POLICY IF EXISTS "profiles_select_own_or_super" ON public.profiles;
CREATE POLICY "profiles_select_own_or_super" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid() OR public.is_super_admin());
DROP POLICY IF EXISTS "surat_select_aktif" ON public.surat_masuk;
CREATE POLICY "surat_select_aktif" ON public.surat_masuk FOR SELECT TO authenticated USING (public.is_aktif());
DROP POLICY IF EXISTS "surat_insert_aktif" ON public.surat_masuk;
CREATE POLICY "surat_insert_aktif" ON public.surat_masuk FOR INSERT TO authenticated WITH CHECK (public.is_aktif() AND created_by = auth.uid());
DROP POLICY IF EXISTS "surat_update_aktif" ON public.surat_masuk;
CREATE POLICY "surat_update_aktif" ON public.surat_masuk FOR UPDATE TO authenticated USING (public.is_aktif()) WITH CHECK (public.is_aktif() AND created_by = auth.uid());

REVOKE ALL ON FUNCTION public.is_aktif() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_super_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_surat_audit() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_status_akun(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ajukan_ulang() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.batalkan_surat(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_status_akun(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ajukan_ulang() TO authenticated;
GRANT EXECUTE ON FUNCTION public.batalkan_surat(uuid) TO authenticated;

REVOKE INSERT, UPDATE ON public.surat_masuk FROM authenticated;
GRANT INSERT (tanggal, jenis_surat, penerima, diterima_oleh, keterangan, lampiran_path, lampiran_nama) ON public.surat_masuk TO authenticated;
GRANT UPDATE (tanggal, jenis_surat, penerima, diterima_oleh, keterangan, lampiran_path, lampiran_nama) ON public.surat_masuk TO authenticated;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('lampiran', 'lampiran', false, 10485760, ARRAY['application/pdf', 'image/jpeg', 'image/png', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 10485760, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "lampiran_select_aktif" ON storage.objects;
CREATE POLICY "lampiran_select_aktif" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'lampiran' AND public.is_aktif() AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "lampiran_insert_aktif" ON storage.objects;
CREATE POLICY "lampiran_insert_aktif" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'lampiran' AND public.is_aktif() AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "lampiran_delete_super" ON storage.objects;
CREATE POLICY "lampiran_delete_super" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'lampiran' AND public.is_super_admin());

CREATE INDEX IF NOT EXISTS profiles_status_idx ON public.profiles(status);
CREATE INDEX IF NOT EXISTS surat_masuk_tanggal_idx ON public.surat_masuk(tanggal DESC);