# UTS Pemrograman / Coding Akuntansi — FEB Undip (TA 2026/2027)
Nama: Zan | NIM: 12030124130082 | Dosen: Totok Dewayanto | Tanggal: 19 Oktober 2026

## Isi repositori
| Folder | Isi |
|---|---|
| `soal-1/` | `erd.png`, `01_soal1_general_ledger.sql` (DDL, constraint, trigger Debit=Kredit, 8 akun contoh), `uji_soal1.sql` |
| `soal-2/` | `02_soal2_inventory.sql` (tabel soal, trigger stok + jurnal otomatis, 1 barang contoh), `uji_soal2.sql` |
| `soal-3/` | `03_soal3_audit_immutability.sql` (audit log, immutability, hash chain, RPC voucher & storno), `uji_soal3.sql`, `voucher.html` |
| `ai-log/` | Log prompt Gemini Canvas dan NotebookLM |
| `bukti-screenshot/` | Screenshot hasil uji |
| `00_reset_opsional.sql` | Menghapus objek latihan agar bisa mengulang dari awal |

## Cara menjalankan (PostgreSQL 16 / Supabase SQL Editor / pgAdmin)
1. Buat database kosong.
2. Jalankan **satu per satu, berurutan, seluruh isi file**: `01` -> `02` -> `03`. Ketiganya harus selesai tanpa error.
3. Setelah itu baru jalankan file `uji_soal*.sql`. Blok SATU pernyataan, klik Run (di pgAdmin: blok teks lalu F5; di Supabase: blok teks lalu Run selected), screenshot hasilnya.
   Pernyataan yang diberi tanda "harus ERROR" memang harus gagal; itu bukti kontrolnya bekerja.
4. Buka `soal-3/voucher.html` di browser (butuh internet untuk Tailwind dan supabase-js).
