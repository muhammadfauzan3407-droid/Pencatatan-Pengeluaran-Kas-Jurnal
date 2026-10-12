# UTS Pemrograman / Coding Akuntansi: Modul General Ledger, Persediaan Perpetual, dan Voucher Kas Keluar

| | |
|---|---|
| Nama | Zan |
| NIM | 12030124130082 |
| Program Studi | S1 Akuntansi, Fakultas Ekonomika dan Bisnis, Universitas Diponegoro |
| Mata Kuliah | Pemrograman / Coding |
| Dosen Pengampu | Totok Dewayanto |
| Ujian | Latihan Tengah Semester Gasal TA 2026/2027, Senin 19 Oktober 2026 (120 menit) |
| Sifat | Open Book / Open AI / Open Code Sandbox |

Repositori ini berisi seluruh artefak jawaban: skema dan skrip SQL (PostgreSQL), purwarupa web voucher kas keluar, log penggunaan AI, dan bukti hasil pengujian. Jawaban tertulis ada di berkas PDF lembar jawaban.

## Isi repositori

| Lokasi | Isi |
|---|---|
| `soal-1/erd.png` | ERD modul General Ledger |
| `soal-1/01_soal1_general_ledger.sql` | DDL 3 tabel, constraint, trigger Debit = Kredit, 8 akun contoh |
| `soal-1/uji_soal1.sql` | Skrip uji Soal 1 |
| `soal-2/02_soal2_inventory.sql` | Tabel persediaan, trigger stok dan jurnal otomatis, 1 barang contoh |
| `soal-2/uji_soal2.sql` | Skrip uji Soal 2 |
| `soal-3/03_soal3_audit_immutability.sql` | Audit log, penguncian jurnal POSTED, hash chain, RPC voucher dan storno |
| `soal-3/uji_soal3.sql` | Skrip uji Soal 3.2 |
| `soal-3/voucher.html` | Purwarupa formulir voucher kas keluar |
| `ai-log/` | Log prompt Gemini Canvas dan NotebookLM |
| `bukti-screenshot/` | Screenshot hasil pengujian |
| `00_reset_opsional.sql` | Menghapus objek latihan agar bisa diulang dari awal |

## Teknologi

PostgreSQL 18 (pgAdmin 4) untuk pengujian skrip, Supabase (PostgreSQL + RPC) untuk purwarupa web, HTML + JavaScript untuk antarmuka, Gemini Canvas dan NotebookLM untuk orkestrasi AI.

## Cara menjalankan

1. Buat database kosong (pgAdmin, Supabase SQL Editor, atau sandbox PostgreSQL).
2. Jalankan **seluruh isi** file berikut **secara berurutan**, masing-masing harus selesai tanpa error:
   `soal-1/01_soal1_general_ledger.sql` → `soal-2/02_soal2_inventory.sql` → `soal-3/03_soal3_audit_immutability.sql`
3. Setelah ketiganya selesai, jalankan `uji_soal1.sql`, `uji_soal2.sql`, dan `uji_soal3.sql`. Blok **satu pernyataan** lalu Run (di pgAdmin: blok teks, tekan F5). Pernyataan yang diberi tanda "harus ERROR" memang harus gagal; itu bukti kontrolnya bekerja.
4. Untuk mengulang dari awal, jalankan `00_reset_opsional.sql`, lalu ulangi langkah 2.
5. Untuk web: buka `soal-3/voucher.html` di browser (butuh internet). Agar tombol Submit mengirim data, isi `YOUR-PROJECT` dan `YOUR-ANON-KEY` di kode dengan URL dan publishable (anon) key project Supabase milik sendiri, dan jalankan `GRANT EXECUTE ON FUNCTION post_cash_out_voucher(DATE, VARCHAR, TEXT, JSONB) TO anon;` di SQL Editor (khusus purwarupa, lihat Keterbatasan).

## Ringkasan solusi

### Soal 1: Arsitektur data, normalisasi, dan asas berpasangan
- Tiga tabel: `chart_of_accounts`, `journal_headers`, `journal_lines`. Header dan baris dipisah agar memenuhi 3NF dan jejak audit konsisten (satu status posting per transaksi).
- Foreign key memakai `ON DELETE RESTRICT`. CHECK constraint: debit dan kredit tidak negatif, tidak boleh keduanya nol, dan hanya satu sisi yang terisi per baris.
- Asas berpasangan ditegakkan **di database**, bukan di frontend: *constraint trigger* yang ditunda sampai commit (`DEFERRABLE INITIALLY DEFERRED`) menolak jurnal POSTED dengan total debit tidak sama dengan total kredit atau kurang dari 2 baris.

### Soal 2: Persediaan perpetual
- `trg_update_stock_and_journal()` berjalan setelah `INSERT` pada `inventory_transactions`: memperbarui `stock_qty`, menolak penjualan yang membuat stok negatif (`RAISE EXCEPTION`), dan membuat jurnal otomatis (pembelian: Dr Persediaan / Cr Utang Usaha; penjualan: Dr HPP / Cr Persediaan; penyesuaian: Persediaan terhadap Selisih Persediaan).
- Concurrency: baris barang dikunci dengan `SELECT ... FOR UPDATE` di dalam trigger. Alternatif yang dibahas: atomic conditional `UPDATE`, isolasi `SERIALIZABLE` dengan retry error 40001, dan `CHECK (stock_qty >= 0)` sebagai pengaman terakhir.

### Soal 3: Purwarupa web dan jejak audit
- `voucher.html`: formulir jurnal dinamis dengan indikator Debit, Kredit, dan Selisih secara langsung (hijau jika seimbang, merah jika tidak). Tombol Submit aktif hanya jika Debit = Kredit > 0, minimal 2 baris, tiap baris punya akun dan satu sisi, serta akun kas/bank dikredit dan tidak didebit. Perhitungan dalam sen (integer).
- `post_cash_out_voucher(...)` (Supabase RPC): memvalidasi ulang aturan kas di server lalu memposting jurnal.
- Immutability: jurnal berstatus `POSTED` tidak bisa di-`UPDATE` maupun `DELETE` (trigger `BEFORE`). Koreksi hanya lewat `reverse_journal(...)` yang membuat jurnal pembalik (storno) merujuk jurnal asal.
- Audit trail: `created_by` (dari klaim JWT di sisi server, tidak dikirim klien), `created_at` (`TIMESTAMPTZ`, jam server), tabel `audit_log` untuk setiap INSERT/UPDATE/DELETE, dan `hash_checksum` SHA-256 berantai (`prev_hash`) yang dihitung saat POSTED. Integritas diverifikasi dengan `fn_verify_ledger_integrity()`.

## Bukti pengujian

Seluruh skrip dijalankan berurutan pada database kosong. Screenshot ada di `bukti-screenshot/`.

**Soal 1**

| Uji | Hasil yang diharapkan | Bukti |
|---|---|---|
| A: jurnal seimbang | Berhasil, debit = kredit = 500.000 | [1a3_hasil_seimbang.png](bukti-screenshot/1a3_hasil_seimbang.png) |
| B: jurnal tidak seimbang | Ditolak: "tidak seimbang" | [1b2_error_tidak_seimbang.png](bukti-screenshot/1b2_error_tidak_seimbang.png) |
| C: baris debit = kredit = 0 | Ditolak: `ck_line_not_both_zero` | [1c_error_nol.png](bukti-screenshot/1c_error_nol.png) |
| D: nominal negatif | Ditolak: `ck_line_non_negative` | [1d_error_negatif.png](bukti-screenshot/1d_error_negatif.png) |

**Soal 2**

| Uji | Hasil yang diharapkan | Bukti |
|---|---|---|
| Beli 10, jual 3 | Stok akhir 7 | [2_stok_akhir.png](bukti-screenshot/2_stok_akhir.png) |
| Jual 20 (stok 7) | Ditolak: stok tidak cukup | [2_uji3_error_stok_kurang.png](bukti-screenshot/2_uji3_error_stok_kurang.png) |
| Jurnal otomatis | INV-1 500.000 = 500.000; INV-2 150.000 = 150.000 | [2_jurnal_otomatis.png](bukti-screenshot/2_jurnal_otomatis.png) |
| Detail akun | Dr/Cr sesuai jenis transaksi | [2_detail_akun.png](bukti-screenshot/2_detail_akun.png) |

**Soal 3**

| Uji | Hasil yang diharapkan | Bukti |
|---|---|---|
| Voucher valid | Berhasil, mengembalikan ID jurnal | [3_uji1_voucher_berhasil.png](bukti-screenshot/3_uji1_voucher_berhasil.png) |
| Voucher tidak seimbang | Ditolak | [3_uji2_error_tidak_seimbang.png](bukti-screenshot/3_uji2_error_tidak_seimbang.png) |
| UPDATE jurnal POSTED | Ditolak (immutable) | [3_uji3a_error_update_ditolak.png](bukti-screenshot/3_uji3a_error_update_ditolak.png) |
| DELETE jurnal POSTED | Ditolak (immutable) | [3_uji3b_error_delete_ditolak.png](bukti-screenshot/3_uji3b_error_delete_ditolak.png) |
| Storno | Berhasil, debit dan kredit tertukar | [3_uji4_storno_berhasil.png](bukti-screenshot/3_uji4_storno_berhasil.png), [3_uji4_storno_pembanding.png](bukti-screenshot/3_uji4_storno_pembanding.png) |
| Verifikasi hash chain | Semua `hash_ok` dan `chain_ok` = true | [3_uji5_verifikasi_hash.png](bukti-screenshot/3_uji5_verifikasi_hash.png) |
| Riwayat audit | Setiap perubahan tercatat | [3_uji6_audit_log.png](bukti-screenshot/3_uji6_audit_log.png) |

**Purwarupa web**

| Kondisi | Bukti |
|---|---|
| Tidak seimbang (merah, tombol mati) | [3_voucher_merah.png](bukti-screenshot/3_voucher_merah.png) |
| Seimbang (hijau, tombol aktif) | [3_voucher_hijau.png](bukti-screenshot/3_voucher_hijau.png) |
| Submit berhasil | [3_voucher_submit_berhasil.png](bukti-screenshot/3_voucher_submit_berhasil.png) |
| Data masuk di Supabase | [3_supabase_data_masuk.png](bukti-screenshot/3_supabase_data_masuk.png) |

## Penggunaan alat AI

Latihan ini bersifat *Open AI*. Alat yang dipakai:
- **Gemini Canvas**: menyusun formulir voucher dinamis. Prompt dan hasil ada di [`ai-log/prompt_gemini_canvas.md`](ai-log/prompt_gemini_canvas.md), screenshot di `bukti-screenshot/ai_gemini_*.png`.
- **NotebookLM**: menguji kesesuaian aturan bisnis dengan PSAK 2 dan PSAK 1. Screenshot di `bukti-screenshot/ai_notebooklm_*.png`.
- **Claude (asisten AI)**: membantu menyusun dan menguji skrip SQL serta menyusun panduan pengerjaan. Seluruh skrip dijalankan dan diuji sendiri pada PostgreSQL.

## Keterbatasan purwarupa

- **Hak akses RPC untuk demo.** Fungsi `post_cash_out_voucher` pada skrip 03 hanya diberi hak untuk pengguna `authenticated`. Karena purwarupa web belum memiliki login, untuk demo fungsi diberi hak `anon` (`GRANT EXECUTE ... TO anon`). Pada sistem sungguhan, pengiriman harus lewat autentikasi Supabase Auth.
- **Kunci API tidak disertakan.** `voucher.html` di repositori ini memakai placeholder `YOUR-PROJECT` dan `YOUR-ANON-KEY`. Kunci asli hanya dipakai di salinan lokal. Kunci `secret`/`service_role` tidak pernah dipakai di sisi klien.
- **Daftar akun di `voucher.html` bersifat tetap** (ID 1 sampai 4) dan harus sama dengan data awal `chart_of_accounts` pada file 01.
- Hash chain menjamin **deteksi** perubahan data, bukan mencegah pengguna dengan hak superuser mengubah data di level database.
