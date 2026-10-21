/*
# Audit keamanan tahap 1: Database dan Storage

## Ringkasan
Audit dan perbaikan keamanan untuk schema public dan storage.
Tidak ada fitur, tampilan, atau data yang diubah. Semua perbaikan melalui migrasi SQL baru.

## Temuan yang diperbaiki
1. REVOKE seluruh DML grants dari role anon pada profiles dan surat_masuk (defense-in-depth; RLS sudah memblokir tapi grants tidak perlu ada).
2. REVOKE INSERT, UPDATE, DELETE dari authenticated pada profiles — hanya SELECT yang dipertahankan. Semua perubahan profil dilakukan via RPC update_profile_saya (SECURITY DEFINER).
3. REVOKE DELETE dari authenticated pada surat_masuk — tidak ada operasi delete langsung di aplikasi; pembatalan via RPC batalkan_surat.
4. Ketatkan USING policy surat_update_aktif: tambah created_by = auth.uid() agar hanya pemilik dapat memilih baris untuk update.
5. Perbaiki validasi email di handle_new_user: domain harus SAMA PERSIS bankbsi.co.id (bukan subdomain), tanpa spasi, tepat satu karakter @.
6. Tambah CHECK constraint: panjang maksimum jenis_surat/penerima/diterima_oleh 200, keterangan 1000, full_name 100, tanggal tidak di masa depan, lampiran_path tidak boleh memuat segmen '..'.
7. Perbarui guard_surat_audit: lindungi juga kolom id dan no saat UPDATE (defense-in-depth; column grant sudah mencegah, tapi trigger juga harus menjaga).
8. Tambah proteksi super_admin aktif terakhir di set_status_akun: tolak nonaktifkan/ditolak jika target adalah super_admin aktif terakhir.

## Yang TIDAK diubah (aman tapi disengaja)
- is_aktif() dan is_super_admin() tetap punya GRANT EXECUTE ke authenticated karena dipanggil dalam policy RLS.
- RPC klien (set_status_akun, ajukan_ulang, batalkan_surat, set_approval_surat, ukuran_lampiran_total, update_profile_saya) tetap GRANT EXECUTE ke authenticated dengan cek otorisasi internal.
- Trigger functions (handle_new_user, guard_surat_audit, sync_profile_email) tetap REVOKE dari semua role klien.
- Bucket avatars dan policy-nya tidak diubah (hanya bucket lampiran yang diaudit).
- Storage.objects tidak diberi policy untuk anon (sudah benar — semua policy existing hanya TO authenticated).
*/

-- ============================================================
-- 1. REVOKE DML grants dari role anon pada tabel aplikasi
-- ============================================================
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.profiles FROM anon;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.surat_masuk FROM anon;

-- ============================================================
-- 2. REVOKE INSERT, UPDATE, DELETE dari authenticated pada profiles
--    Hanya SELECT yang dipertahankan (untuk policy RLS).
--    Semua perubahan profil via RPC update_profile_saya.
-- ============================================================
REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM authenticated;

-- ============================================================
-- 3. REVOKE DELETE dari authenticated pada surat_masuk
--    Tidak ada operasi delete langsung di aplikasi.
-- ============================================================
REVOKE DELETE ON public.surat_masuk FROM authenticated;

-- ============================================================
-- 4. Ketatkan policy surat_update_aktif
--    USING sebelumnya: is_aktif() — semua user aktif bisa memilih baris lain.
--    USING diperketat: is_aktif() AND created_by = auth.uid() — hanya pemilik.
--    WITH CHECK tidak berubah.
-- ============================================================
DROP POLICY IF EXISTS "surat_update_aktif" ON public.surat_masuk;
CREATE POLICY "surat_update_aktif" ON public.surat_masuk FOR UPDATE
  TO authenticated
  USING (public.is_aktif() AND created_by = auth.uid())
  WITH CHECK (public.is_aktif() AND created_by = auth.uid());

-- ============================================================
-- 5. Perbaiki validasi email di handle_new_user
--    Sebelumnya: lower(email) NOT LIKE '%@bankbsi.co.id' — mengizinkan subdomain.
--    Sekarang: regex ketat — lokal tanpa @/spasi, domain persis bankbsi.co.id.
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.email IS NULL OR lower(trim(NEW.email)) !~ '^[^@[:space:]]+@bankbsi[.]co[.]id$' THEN
    RAISE EXCEPTION 'Pendaftaran hanya untuk email Bank Syariah Indonesia';
  END IF;
  INSERT INTO public.profiles (id, email, full_name, role, status)
  VALUES (NEW.id, lower(trim(NEW.email)), COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''), 'admin', 'menunggu');
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 6. Tambah CHECK constraint pada surat_masuk dan profiles
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE con.conname = 'surat_jenis_surat_max' AND n.nspname = 'public' AND c.relname = 'surat_masuk') THEN
    ALTER TABLE public.surat_masuk ADD CONSTRAINT surat_jenis_surat_max CHECK (length(jenis_surat) <= 200);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE con.conname = 'surat_penerima_max' AND n.nspname = 'public' AND c.relname = 'surat_masuk') THEN
    ALTER TABLE public.surat_masuk ADD CONSTRAINT surat_penerima_max CHECK (length(penerima) <= 200);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE con.conname = 'surat_diterima_oleh_max' AND n.nspname = 'public' AND c.relname = 'surat_masuk') THEN
    ALTER TABLE public.surat_masuk ADD CONSTRAINT surat_diterima_oleh_max CHECK (length(diterima_oleh) <= 200);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE con.conname = 'surat_keterangan_max' AND n.nspname = 'public' AND c.relname = 'surat_masuk') THEN
    ALTER TABLE public.surat_masuk ADD CONSTRAINT surat_keterangan_max CHECK (keterangan IS NULL OR length(keterangan) <= 1000);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE con.conname = 'surat_tanggal_max' AND n.nspname = 'public' AND c.relname = 'surat_masuk') THEN
    ALTER TABLE public.surat_masuk ADD CONSTRAINT surat_tanggal_max CHECK (tanggal <= current_date);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE con.conname = 'surat_lampiran_path_safe' AND n.nspname = 'public' AND c.relname = 'surat_masuk') THEN
    ALTER TABLE public.surat_masuk ADD CONSTRAINT surat_lampiran_path_safe
      CHECK (lampiran_path IS NULL OR NOT ('..' = ANY(string_to_array(lampiran_path, '/'))));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE con.conname = 'profiles_full_name_max' AND n.nspname = 'public' AND c.relname = 'profiles') THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_full_name_max CHECK (length(full_name) <= 100);
  END IF;
END $$;

-- ============================================================
-- 7. Perbarui guard_surat_audit: lindungi juga id dan no
-- ============================================================
CREATE OR REPLACE FUNCTION public.guard_surat_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    IF NEW.id IS DISTINCT FROM OLD.id
      OR NEW.no IS DISTINCT FROM OLD.no
      OR NEW.dibatalkan IS DISTINCT FROM OLD.dibatalkan
      OR NEW.dibatalkan_oleh IS DISTINCT FROM OLD.dibatalkan_oleh
      OR NEW.dibatalkan_at IS DISTINCT FROM OLD.dibatalkan_at
      OR NEW.created_by IS DISTINCT FROM OLD.created_by
      OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Kolom audit hanya dapat diubah melalui alur resmi';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_surat_audit() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 8. Tambah proteksi super_admin aktif terakhir di set_status_akun
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_status_akun(p_user_id uuid, p_status_baru text, p_alasan text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN RAISE EXCEPTION 'Tidak berwenang'; END IF;
  IF p_user_id = auth.uid() THEN RAISE EXCEPTION 'Tidak dapat mengubah status sendiri'; END IF;
  IF p_status_baru NOT IN ('aktif', 'ditolak', 'nonaktif') THEN RAISE EXCEPTION 'Status tidak valid'; END IF;
  IF p_status_baru = 'ditolak' AND nullif(trim(p_alasan), '') IS NULL THEN RAISE EXCEPTION 'Alasan penolakan wajib diisi'; END IF;

  IF p_status_baru IN ('ditolak', 'nonaktif') THEN
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id AND role = 'super_admin' AND status = 'aktif')
       AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE role = 'super_admin' AND status = 'aktif' AND id <> p_user_id) THEN
      RAISE EXCEPTION 'Tidak dapat menonaktifkan super_admin aktif terakhir';
    END IF;
  END IF;

  UPDATE public.profiles
  SET status = p_status_baru,
      reject_reason = CASE WHEN p_status_baru = 'ditolak' THEN trim(p_alasan) ELSE NULL END,
      reviewed_by = auth.uid(),
      reviewed_at = now()
  WHERE id = p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Akun tidak ditemukan'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.set_status_akun(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_status_akun(uuid, text, text) TO authenticated;
