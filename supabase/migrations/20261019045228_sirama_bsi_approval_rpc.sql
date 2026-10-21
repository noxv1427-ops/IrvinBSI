/*
# Izinkan RPC approval melewati penjaga audit

1. Perubahan fungsi
- `guard_surat_audit` tidak lagi menganggap `approval`, `approved_by`, dan `approved_at` sebagai kolom pembatalan.
- Keputusan approval tetap hanya dapat ditulis melalui `set_approval_surat`, karena hak UPDATE kolom tersebut tidak diberikan kepada klien.

2. Keamanan
- Kolom `dibatalkan`, `dibatalkan_oleh`, `dibatalkan_at`, `created_by`, dan `created_at` tetap dilindungi dari perubahan langsung.
- Tidak ada tabel, kolom, atau kebijakan RLS yang diubah.
*/

CREATE OR REPLACE FUNCTION public.guard_surat_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    IF NEW.dibatalkan IS DISTINCT FROM OLD.dibatalkan
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