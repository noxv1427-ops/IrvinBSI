/*
# Meter penyimpanan lampiran

1. Fungsi baru
- `ukuran_lampiran_total()`: menjumlahkan ukuran objek pada bucket privat `lampiran` dalam byte.

2. Keamanan
- Fungsi SECURITY DEFINER memeriksa `is_super_admin()` sebelum mengembalikan ukuran.
- EXECUTE dicabut dari publik dan anon, lalu hanya diberikan kepada authenticated.
- Tidak ada tabel atau kolom yang diubah.
*/

CREATE OR REPLACE FUNCTION public.ukuran_lampiran_total()
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  total_bytes bigint;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Tidak berwenang';
  END IF;

  SELECT COALESCE(SUM((metadata ->> 'size')::bigint), 0)
  INTO total_bytes
  FROM storage.objects
  WHERE bucket_id = 'lampiran';

  RETURN total_bytes;
END;
$$;

REVOKE ALL ON FUNCTION public.ukuran_lampiran_total() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ukuran_lampiran_total() TO authenticated;