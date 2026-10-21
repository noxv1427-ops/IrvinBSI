import { useState } from 'react';
import { Inbox } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import type { Letter } from '@/pages/AppPages';
import { Card } from '@/components/ui';

type Approval = Letter['approval'];
type BoardProps = {
  letters: Letter[];
  onApprovalChange: (id: string, approval: Approval, previous: Approval) => void;
  onCardClick: (letter: Letter) => void;
};

const columns: { key: Approval; label: string; accent: string; bar: string; glow: string }[] = [
  { key: 'menunggu', label: 'Menunggu', accent: 'text-warning', bar: 'bg-warning', glow: 'ring-warning/40' },
  { key: 'disetujui', label: 'Disetujui', accent: 'text-success', bar: 'bg-success', glow: 'ring-success/40' },
  { key: 'ditolak', label: 'Ditolak', accent: 'text-danger', bar: 'bg-danger', glow: 'ring-danger/40' },
];

export default function BoardView({ letters, onApprovalChange, onCardClick }: BoardProps) {
  const [dragId, setDragId] = useState<string | null>(null);
  const [overCol, setOverCol] = useState<Approval | null>(null);

  const active = letters.filter((l) => !l.dibatalkan);
  const grouped: Record<Approval, Letter[]> = { menunggu: [], disetujui: [], ditolak: [] };
  for (const l of active) grouped[l.approval].push(l);

  async function drop(target: Approval) {
    if (!dragId) return;
    const letter = active.find((l) => l.id === dragId);
    setDragId(null);
    setOverCol(null);
    if (!letter || letter.approval === target) return;
    await onApprovalChange(letter.id, target, letter.approval);
  }

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      {columns.map((col) => (
        <div
          key={col.key}
          onDragOver={(e) => { e.preventDefault(); setOverCol(col.key); }}
          onDragLeave={() => setOverCol((c) => (c === col.key ? null : c))}
          onDrop={() => void drop(col.key)}
          className={`rounded-card border border-line bg-canvas p-4 transition-all duration-200 ${overCol === col.key ? `ring-2 ${col.glow} bg-white` : ''}`}
        >
          <div className="mb-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className={`h-2.5 w-2.5 rounded-full ${col.bar}`} />
              <h3 className={`text-sm font-bold ${col.accent}`}>{col.label}</h3>
            </div>
            <span className="rounded-full bg-white px-2 py-0.5 text-xs font-bold text-muted">{grouped[col.key].length}</span>
          </div>
          <div className="space-y-3">
            {grouped[col.key].length === 0 ? (
              <div className="flex flex-col items-center gap-2 py-10 text-center">
                <Inbox className="h-7 w-7 text-muted/40" />
                <p className="text-xs text-muted">Tidak ada surat</p>
              </div>
            ) : (
              grouped[col.key].map((letter) => (
                <div
                  key={letter.id}
                  draggable
                  onDragStart={() => setDragId(letter.id)}
                  onDragEnd={() => { setDragId(null); setOverCol(null); }}
                  onClick={() => onCardClick(letter)}
                  className={`cursor-grab rounded-input border border-line bg-white p-4 shadow-soft transition-all active:cursor-grabbing hover:border-teal-600/30 hover:shadow-deep ${dragId === letter.id ? 'opacity-40 ring-2 ring-teal-600/30 -rotate-2 scale-[0.98]' : ''}`}
                >
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-teal-600">#{letter.no}</span>
                    {letter.lampiran_path && <span className="text-[10px] text-muted">Lampiran</span>}
                  </div>
                  <p className="mt-2 text-sm font-bold text-ink">{letter.jenis_surat}</p>
                  <p className="mt-1 truncate text-xs text-muted">{letter.penerima}</p>
                  <p className="mt-2 text-[10px] text-muted">{letter.tanggal}</p>
                </div>
              ))
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
