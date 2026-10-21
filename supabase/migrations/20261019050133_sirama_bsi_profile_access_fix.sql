/*
# Perbaikan akses pembacaan profil

1. Perubahan keamanan
- Mempertahankan policy `profiles_select_own_or_super` untuk membaca profil sendiri atau seluruh profil oleh Super Admin.
- Memberikan hak EXECUTE `is_aktif()` dan `is_super_admin()` kepada role authenticated karena keduanya dipanggil oleh policy RLS.
- Fungsi tetap SECURITY DEFINER dengan search_path tetap; keduanya hanya mengembalikan boolean untuk evaluasi policy.

2. Catatan penting
- Tidak ada tabel, kolom, autentikasi, atau data pengguna yang diubah.
- Tanpa hak EXECUTE ini, PostgreSQL menolak query profil dengan error permission denied sebelum policy dapat mengevaluasi akses.
*/

GRANT EXECUTE ON FUNCTION public.is_aktif() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;

DROP POLICY IF EXISTS "profiles_select_own_or_super" ON public.profiles;
CREATE POLICY "profiles_select_own_or_super"
ON public.profiles FOR SELECT
TO authenticated
USING (id = auth.uid() OR public.is_super_admin());