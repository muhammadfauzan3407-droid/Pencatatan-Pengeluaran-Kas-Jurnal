-- UJI SOAL 1  (jalankan SETELAH file 01, 02, 03 selesai tanpa error)
-- Cara: blok SATU pernyataan (dari komentar sampai titik koma), klik Run, screenshot hasilnya.
-- Uji B, C, D MEMANG harus error -- itu buktinya.

-- ===== UJI A: jurnal seimbang (Dr Beban Listrik 500.000 / Cr Kas 500.000)  -> BERHASIL =====
-- A1. buat header + 2 baris (masih DRAFT)
WITH h AS (
  INSERT INTO journal_headers (trx_date, reference_no, description)
  VALUES (CURRENT_DATE, 'UJI-A', 'Bayar listrik') RETURNING header_id)
INSERT INTO journal_lines (header_id, account_id, debit, credit)
SELECT h.header_id, (SELECT account_id FROM chart_of_accounts WHERE account_code='5-2100'), 500000, 0 FROM h
UNION ALL
SELECT h.header_id, (SELECT account_id FROM chart_of_accounts WHERE account_code='1-1100'), 0, 500000 FROM h;

-- A2. posting
UPDATE journal_headers SET posting_status = 'POSTED' WHERE reference_no = 'UJI-A';

-- A3. lihat hasil (debit = kredit)
SELECT h.reference_no, h.posting_status, SUM(l.debit) AS total_debit, SUM(l.credit) AS total_kredit
FROM journal_headers h JOIN journal_lines l USING (header_id)
WHERE h.reference_no = 'UJI-A' GROUP BY 1, 2;

-- ===== UJI B: jurnal TIDAK seimbang (500.000 vs 400.000) -> harus ERROR "tidak seimbang" =====
-- B1. buat draft (berhasil, karena masih DRAFT)
WITH h AS (
  INSERT INTO journal_headers (trx_date, reference_no, description)
  VALUES (CURRENT_DATE, 'UJI-B', 'Jurnal tidak seimbang') RETURNING header_id)
INSERT INTO journal_lines (header_id, account_id, debit, credit)
SELECT h.header_id, (SELECT account_id FROM chart_of_accounts WHERE account_code='5-2100'), 500000, 0 FROM h
UNION ALL
SELECT h.header_id, (SELECT account_id FROM chart_of_accounts WHERE account_code='1-1100'), 0, 400000 FROM h;

-- B2. coba posting -> DITOLAK
UPDATE journal_headers SET posting_status = 'POSTED' WHERE reference_no = 'UJI-B';

-- ===== UJI C: baris dengan debit = 0 DAN kredit = 0 -> harus ERROR ck_line_not_both_zero =====
INSERT INTO journal_lines (header_id, account_id, debit, credit)
SELECT header_id, (SELECT account_id FROM chart_of_accounts WHERE account_code='1-1100'), 0, 0
FROM journal_headers WHERE reference_no = 'UJI-B';

-- ===== UJI D: nominal negatif -> harus ERROR ck_line_non_negative =====
INSERT INTO journal_lines (header_id, account_id, debit, credit)
SELECT header_id, (SELECT account_id FROM chart_of_accounts WHERE account_code='1-1100'), -100, 0
FROM journal_headers WHERE reference_no = 'UJI-B';
