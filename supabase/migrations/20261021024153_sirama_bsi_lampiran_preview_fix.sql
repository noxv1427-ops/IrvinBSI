/*
# Perbaikan: preview lampiran untuk semua admin aktif

## Masalah
Policy `lampiran_select_aktif` membatasi baca objek hanya ke folder milik pengguna
sendiri (`(storage.foldername(name))[1] = auth.uid()::text`). Akibatnya, admin biasa
tidak dapat melihat preview lampiran surat yang dibuat oleh pengguna lain, meskipun
merelu berhak melihat surat tersebut (policy surat_select_aktif mengizinkan semua
pengguna aktif membaca seluruh surat masuk).

## Perbaikan
Hapus batasan folder pemilik pada policy SELECT lampiran. Semua pengguna aktif
dapat membaca objek di bucket lampiran. Tulis dan hapus tetap dibatasi:
- INSERT: hanya pengguna aktif, folder sendiri.
- DELETE: hanya super admin.

## Keamanan
- Tidak ada tabel, kolom, atau data yang diubah.
- Policy INSERT dan DELETE tidak diubah.
- Bucket tetap privat (public = false) — akses hanya via signed URL dari klien yang
  sudah terautentikasi dan berstatus aktif.
*/

DROP POLICY IF EXISTS "lampiran_select_aktif" ON storage.objects;
CREATE POLICY "lampiran_select_aktif" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'lampiran' AND public.is_aktif());
