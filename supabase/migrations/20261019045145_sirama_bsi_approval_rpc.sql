/*
# RPC approval surat masuk

1. Perubahan fungsi
- Menambahkan `set_approval_surat(p_id, p_approval)` untuk memperbarui status persetujuan surat.
- Nilai `approved_by` selalu berasal dari pengguna yang sedang login.
- Nilai `approved_at` selalu diisi oleh database saat keputusan dibuat.

2. Keamanan
- Hanya pengguna aktif yang dapat memanggil fungsi.
- Surat yang sudah dibatalkan tidak dapat diproses.
- Hak EXECUTE dicabut dari publik dan anon, lalu diberikan hanya kepada authenticated.
- Tidak ada tabel, kolom, atau kebijakan RLS yang diubah.
*/

CREATE OR REPLACE FUNCTION public.set_approval_surat(p_id uuid, p_approval text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_aktif() THEN
    RAISE EXCEPTION 'Tidak berwenang';
  END IF;
  IF p_approval NOT IN ('menunggu', 'disetujui', 'ditolak') THEN
    RAISE EXCEPTION 'Status persetujuan tidak valid';
  END IF;

  UPDATE public.surat_masuk
  SET approval = p_approval,
      approved_by = CASE WHEN p_approval = 'menunggu' THEN NULL ELSE auth.uid() END,
      approved_at = CASE WHEN p_approval = 'menunggu' THEN NULL ELSE now() END
  WHERE id = p_id AND dibatalkan = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Surat tidak ditemukan atau sudah dibatalkan';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.set_approval_surat(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_approval_surat(uuid, text) TO authenticated;