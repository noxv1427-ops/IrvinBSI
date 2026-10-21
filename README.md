# SIRAMA BSI - Sistem Informasi Registrasi Surat Masuk

SIRAMA BSI adalah aplikasi internal untuk registrasi surat masuk dan pengelolaan akses pengguna Bank Syariah Indonesia.

## Variabel lingkungan

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Kredensial Supabase dikelola oleh proyek dan tidak boleh ditulis ke kode sumber.

## Menyiapkan akun Super Admin pertama

1. Daftarkan akun menggunakan email `@bankbsi.co.id`.
2. Buka SQL Editor Supabase dan jalankan SQL berikut, ganti alamat emailnya:

```sql
UPDATE public.profiles
SET role = 'super_admin', status = 'aktif', reviewed_at = now()
WHERE email = 'nama@bankbsi.co.id';
```

3. Di Supabase, buka Authentication > Providers > Email lalu matikan **Confirm email** untuk lingkungan internal/testing.

## Menjalankan dan deploy

Aplikasi menggunakan Vite dan akan berjalan melalui lingkungan proyek.

Untuk deploy ke Vercel:

1. Import proyek ke Vercel.
2. Pilih framework preset **Vite**.
3. Pastikan variabel `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY` tersedia pada Environment Variables.
4. Gunakan perintah build `npm run build` dan direktori output `dist`.

Edge Function reset password menggunakan secret Supabase yang dikelola di sisi layanan dan tidak boleh dipindahkan ke browser.
