import type { Letter } from '@/pages/AppPages';

const headers = ['No', 'Tanggal', 'Jenis Surat', 'Penerima', 'Diterima Oleh', 'Approval', 'Keterangan'] as const;
const approvalLabel = (value: Letter['approval']) => (value === 'disetujui' ? 'Disetujui' : value === 'ditolak' ? 'Ditolak' : 'Menunggu');

function sanitize(value: string) {
  return /^[=+\-@]/.test(value) ? `'${value}` : value;
}

export async function exportLettersToExcel(letters: Letter[], filters: { status: string; query: string; from: string; to: string }) {
  const ExcelJS = await import('exceljs');
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Surat Masuk');
  sheet.columns = headers.map((header) => ({ header, key: header, width: 22 }));
  for (const letter of letters) {
    sheet.addRow({
      No: letter.no,
      Tanggal: letter.tanggal,
      'Jenis Surat': sanitize(letter.jenis_surat),
      Penerima: sanitize(letter.penerima),
      'Diterima Oleh': sanitize(letter.diterima_oleh),
      Approval: approvalLabel(letter.approval),
      Keterangan: sanitize(letter.keterangan ?? ''),
    });
  }
  sheet.getRow(1).font = { bold: true };
  const stamp = new Date().toISOString().slice(0, 10);
  const suffix = [filters.status !== 'semua' ? filters.status : '', filters.query, filters.from, filters.to].filter(Boolean).join('_');
  const filename = `surat-masuk_${stamp}${suffix ? `_${suffix}` : ''}.xlsx`;
  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}
