import { useEffect, useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import { Camera, Loader2, Mail, Save, User } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { Badge, Button, Card, Input } from '@/components/ui';

function avatarPublicUrl(path: string | null) { return path ? supabase.storage.from('avatars').getPublicUrl(path).data.publicUrl : null; }

export function ProfilePage() {
  const { profile, refreshProfile } = useAuth();
  const [fullName, setFullName] = useState(profile?.full_name ?? '');
  const [email, setEmail] = useState(profile?.email ?? '');
  const [avatarPath, setAvatarPath] = useState(profile?.avatar_url ?? null);
  const [avatarUrl, setAvatarUrl] = useState(avatarPublicUrl(profile?.avatar_url ?? null));
  const [uploading, setUploading] = useState(false);
  const [savingInfo, setSavingInfo] = useState(false);
  const [savingEmail, setSavingEmail] = useState(false);
  const [infoMessage, setInfoMessage] = useState('');
  const [infoError, setInfoError] = useState('');
  const [emailMessage, setEmailMessage] = useState('');
  const [emailError, setEmailError] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [passwordMessage, setPasswordMessage] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [savingPassword, setSavingPassword] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setFullName(profile?.full_name ?? '');
    setEmail(profile?.email ?? '');
    setAvatarPath(profile?.avatar_url ?? null);
    setAvatarUrl(avatarPublicUrl(profile?.avatar_url ?? null));
  }, [profile]);

  const initial = profile?.full_name?.slice(0, 1).toUpperCase() || 'A';

  async function handleAvatarChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file || !profile) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setInfoError('Hanya JPG, PNG, atau WEBP.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      setInfoError('Ukuran foto maksimal 5 MB.');
      return;
    }
    setUploading(true);
    setInfoError('');
    const ext = file.name.split('.').pop()?.toLowerCase() ?? 'jpg';
    const newPath = `${profile.id}/avatar-${Date.now()}.${ext}`;
    const upload = await supabase.storage.from('avatars').upload(newPath, file, { contentType: file.type, upsert: false });
    if (upload.error) {
      setUploading(false);
      setInfoError('Foto belum dapat diunggah.');
      return;
    }
    if (avatarPath && avatarPath !== newPath) {
      await supabase.storage.from('avatars').remove([avatarPath]);
    }
    const { error: rpcError } = await supabase.rpc('update_profile_saya', { p_full_name: fullName, p_avatar_url: newPath });
    setUploading(false);
    if (rpcError) {
      setInfoError('Foto belum dapat disimpan.');
      return;
    }
    setAvatarPath(newPath);
    setAvatarUrl(avatarPublicUrl(newPath));
    setInfoMessage('Foto profil berhasil diperbarui.');
    await refreshProfile();
    window.setTimeout(() => setInfoMessage(''), 4000);
  }

  async function removeAvatar() {
    if (!avatarPath || !profile) return;
    setUploading(true);
    await supabase.storage.from('avatars').remove([avatarPath]);
    const { error } = await supabase.rpc('update_profile_saya', { p_full_name: fullName, p_avatar_url: '' });
    setUploading(false);
    if (error) {
      setInfoError('Foto belum dapat dihapus.');
      return;
    }
    setAvatarPath(null);
    setAvatarUrl(null);
    setInfoMessage('Foto profil dihapus.');
    await refreshProfile();
    window.setTimeout(() => setInfoMessage(''), 4000);
  }

  async function saveInfo(event: FormEvent) {
    event.preventDefault();
    setInfoError('');
    setInfoMessage('');
    if (!fullName.trim()) {
      setInfoError('Nama tidak boleh kosong.');
      return;
    }
    setSavingInfo(true);
    const { error } = await supabase.rpc('update_profile_saya', { p_full_name: fullName.trim(), p_avatar_url: avatarPath });
    setSavingInfo(false);
    if (error) setInfoError('Nama belum dapat disimpan.');
    else {
      setInfoMessage('Nama berhasil disimpan.');
      await refreshProfile();
      window.setTimeout(() => setInfoMessage(''), 4000);
    }
  }

  async function saveEmail(event: FormEvent) {
    event.preventDefault();
    setEmailError('');
    setEmailMessage('');
    if (!email.trim() || !email.includes('@')) {
      setEmailError('Email tidak valid.');
      return;
    }
    setSavingEmail(true);
    const { error } = await supabase.auth.updateUser({ email: email.trim() });
    setSavingEmail(false);
    if (error) setEmailError('Email belum dapat diubah. ' + error.message);
    else {
      setEmailMessage('Email diperbarui. Jika konfirmasi email aktif, cek email baru untuk verifikasi.');
      await refreshProfile();
      window.setTimeout(() => setEmailMessage(''), 6000);
    }
  }

  async function savePassword(event: FormEvent) {
    event.preventDefault();
    setPasswordError('');
    setPasswordMessage('');
    if (password.length < 8) {
      setPasswordError('Kata sandi minimal 8 karakter.');
      return;
    }
    if (password !== confirmation) {
      setPasswordError('Konfirmasi kata sandi belum sama.');
      return;
    }
    setSavingPassword(true);
    const { error } = await supabase.auth.updateUser({ password });
    setSavingPassword(false);
    if (error) setPasswordError('Kata sandi belum dapat diubah.');
    else {
      setPassword('');
      setConfirmation('');
      setPasswordMessage('Kata sandi berhasil diubah.');
      window.setTimeout(() => setPasswordMessage(''), 4000);
    }
  }

  return (
    <section className="max-w-3xl">
      <div className="mb-7">
        <p className="text-sm font-bold uppercase tracking-[0.16em] text-teal-600">Pengaturan akun</p>
        <h1 className="mt-2 text-3xl font-bold text-ink">Profil</h1>
        <p className="mt-2 text-muted">Kelola informasi akun, foto profil, dan kata sandi Anda.</p>
      </div>

      <Card className="mb-5 p-6">
        <h2 className="text-lg font-bold text-ink">Foto profil</h2>
        <div className="mt-5 flex flex-col items-center gap-5 sm:flex-row sm:items-center">
          <div className="relative">
            {avatarUrl ? (
              <img src={avatarUrl} alt="Foto profil" className="h-24 w-24 rounded-full object-cover ring-4 ring-teal-600/10" />
            ) : (
              <span className="flex h-24 w-24 items-center justify-center rounded-full bg-teal-600 text-2xl font-bold text-white">{initial}</span>
            )}
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              disabled={uploading}
              className="absolute bottom-0 right-0 flex h-8 w-8 items-center justify-center rounded-full bg-white text-teal-600 shadow-soft ring-2 ring-teal-600/10 transition hover:bg-canvas disabled:opacity-50"
              aria-label="Ubah foto"
            >
              {uploading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Camera className="h-4 w-4" />}
            </button>
            <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" onChange={handleAvatarChange} className="sr-only" />
          </div>
          <div className="text-center sm:text-left">
            <p className="text-sm text-muted">Klik ikon kamera untuk mengunggah foto. Format JPG, PNG, atau WEBP. Maksimal 5 MB.</p>
            {avatarPath && (
              <button type="button" onClick={removeAvatar} disabled={uploading} className="mt-2 text-sm font-bold text-danger hover:underline disabled:opacity-50">
                Hapus foto
              </button>
            )}
          </div>
        </div>
        {infoError && <p className="mt-4 rounded-input bg-danger/10 px-3 py-2 text-sm text-danger">{infoError}</p>}
        {infoMessage && <p className="mt-4 rounded-input bg-success/10 px-3 py-2 text-sm text-success">{infoMessage}</p>}
      </Card>

      <div className="grid gap-5 lg:grid-cols-2">
        <Card className="p-6">
          <h2 className="flex items-center gap-2 text-lg font-bold text-ink"><User className="h-5 w-5 text-teal-600" />Edit nama</h2>
          <form onSubmit={saveInfo} className="mt-5 space-y-4">
            <Input label="Nama lengkap" value={fullName} onChange={(e) => setFullName(e.target.value)} required />
            <Button type="submit" loading={savingInfo} className="w-full"><Save className="h-4 w-4" />Simpan nama</Button>
          </form>
        </Card>

        <Card className="p-6">
          <h2 className="flex items-center gap-2 text-lg font-bold text-ink"><Mail className="h-5 w-5 text-teal-600" />Edit email</h2>
          <p className="mt-2 text-sm leading-relaxed text-muted">Mengubah email akan memperbarui email login akun Anda.</p>
          <form onSubmit={saveEmail} className="mt-5 space-y-4">
            {emailError && <p className="rounded-input bg-danger/10 px-3 py-2 text-sm text-danger">{emailError}</p>}
            {emailMessage && <p className="rounded-input bg-success/10 px-3 py-2 text-sm text-success">{emailMessage}</p>}
            <Input label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
            <Button type="submit" loading={savingEmail} className="w-full"><Save className="h-4 w-4" />Simpan email</Button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <h2 className="text-lg font-bold text-ink">Ganti kata sandi</h2>
          <p className="mt-2 text-sm leading-relaxed text-muted">Kata sandi lama tidak diperlukan. Gunakan minimal 8 karakter.</p>
          <form onSubmit={savePassword} className="mt-5 space-y-4">
            {passwordError && <p className="rounded-input bg-danger/10 px-3 py-2 text-sm text-danger">{passwordError}</p>}
            {passwordMessage && <p className="rounded-input bg-success/10 px-3 py-2 text-sm text-success">{passwordMessage}</p>}
            <div className="grid gap-4 sm:grid-cols-2">
              <Input label="Kata sandi baru" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="new-password" />
              <Input label="Konfirmasi kata sandi" type="password" value={confirmation} onChange={(e) => setConfirmation(e.target.value)} required autoComplete="new-password" />
            </div>
            <Button type="submit" loading={savingPassword} className="w-full sm:w-auto">Simpan kata sandi</Button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <h2 className="text-lg font-bold text-ink">Informasi akun</h2>
          <dl className="mt-5 grid gap-4 sm:grid-cols-3">
            <div>
              <dt className="text-xs font-bold uppercase tracking-wide text-muted">Nama</dt>
              <dd className="mt-1 font-semibold text-ink">{profile?.full_name || '—'}</dd>
            </div>
            <div>
              <dt className="text-xs font-bold uppercase tracking-wide text-muted">Email</dt>
              <dd className="mt-1 break-words font-semibold text-ink">{profile?.email || '—'}</dd>
            </div>
            <div>
              <dt className="text-xs font-bold uppercase tracking-wide text-muted">Peran</dt>
              <dd className="mt-2"><Badge tone={profile?.role === 'super_admin' ? 'success' : 'neutral'}>{profile?.role === 'super_admin' ? 'Super Admin' : 'Admin'}</Badge></dd>
            </div>
          </dl>
        </Card>
      </div>
    </section>
  );
}
