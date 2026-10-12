-- UJI SOAL 3.2  (jalankan SETELAH file 01, 02, 03). Satu pernyataan per Run, screenshot tiap hasil.
-- Uji 2, 3a, 3b memang harus ERROR.

-- ===== UJI 1: voucher kas keluar valid (Dr Beban Gaji 2.000.000 / Cr Bank 2.000.000) -> BERHASIL, mengembalikan ID =====
SELECT post_cash_out_voucher(
  CURRENT_DATE, 'KK-UJI-1', 'Bayar gaji karyawan',
  jsonb_build_array(
    jsonb_build_object('account_id', (SELECT account_id FROM chart_of_accounts WHERE account_code='5-2200'), 'debit', 2000000, 'credit', 0),
    jsonb_build_object('account_id', (SELECT account_id FROM chart_of_accounts WHERE account_code='1-1200'), 'debit', 0, 'credit', 2000000)));

-- ===== UJI 2: voucher TIDAK seimbang -> harus ERROR "tidak seimbang" =====
SELECT post_cash_out_voucher(
  CURRENT_DATE, 'KK-UJI-2', 'Voucher tidak seimbang',
  jsonb_build_array(
    jsonb_build_object('account_id', (SELECT account_id FROM chart_of_accounts WHERE account_code='5-2200'), 'debit', 2000000, 'credit', 0),
    jsonb_build_object('account_id', (SELECT account_id FROM chart_of_accounts WHERE account_code='1-1200'), 'debit', 0, 'credit', 1500000)));

-- ===== UJI 3a: ubah jurnal POSTED -> harus ERROR "immutable (UPDATE ditolak)" =====
UPDATE journal_headers SET description = 'diubah diam-diam' WHERE reference_no = 'KK-UJI-1';

-- ===== UJI 3b: hapus jurnal POSTED -> harus ERROR "immutable (DELETE ditolak)" =====
DELETE FROM journal_lines WHERE header_id = (SELECT header_id FROM journal_headers WHERE reference_no = 'KK-UJI-1');

-- ===== UJI 4: koreksi lewat jurnal pembalik (storno) -> BERHASIL =====
SELECT reverse_journal((SELECT header_id FROM journal_headers WHERE reference_no = 'KK-UJI-1'), 'Salah input akun gaji');

-- (lihat jurnal asal & pembaliknya: debit/kredit tertukar)
SELECT h.reference_no, h.reversal_of, c.account_name, l.debit, l.credit
FROM journal_headers h JOIN journal_lines l USING (header_id) JOIN chart_of_accounts c USING (account_id)
WHERE h.reference_no IN ('KK-UJI-1', 'REV-KK-UJI-1') ORDER BY h.header_id, l.line_id;

-- ===== UJI 5: verifikasi integritas hash chain -> semua hash_ok dan chain_ok = t =====
SELECT * FROM fn_verify_ledger_integrity();

-- ===== UJI 6: riwayat audit_log =====
SELECT audit_id, table_name, record_id, action, actor, acted_at FROM audit_log ORDER BY audit_id DESC LIMIT 20;
