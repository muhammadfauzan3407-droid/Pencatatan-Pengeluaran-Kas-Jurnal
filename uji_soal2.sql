-- UJI SOAL 2  (jalankan SETELAH file 01, 02, 03). Satu pernyataan per Run, screenshot tiap hasil.

-- ===== UJI 1: pembelian 10 unit -> stok jadi 10, jurnal Dr Persediaan / Cr Utang Usaha Rp500.000 =====
INSERT INTO inventory_transactions (item_id, trx_type, qty) VALUES ('BRG-001', 'PURCHASE', 10);

-- ===== UJI 2: penjualan 3 unit -> stok jadi 7, jurnal Dr HPP / Cr Persediaan Rp150.000 =====
INSERT INTO inventory_transactions (item_id, trx_type, qty) VALUES ('BRG-001', 'SALE', 3);

-- ===== UJI 3: penjualan 20 unit (stok hanya 7) -> harus ERROR "Stok item BRG-001 tidak cukup" =====
INSERT INTO inventory_transactions (item_id, trx_type, qty) VALUES ('BRG-001', 'SALE', 20);

-- ===== HASIL: stok akhir harus 7 =====
SELECT item_id, item_name, stock_qty, unit_cost FROM inventory_items;

-- ===== HASIL: jurnal otomatis (setiap jurnal Debit = Kredit) =====
SELECT h.reference_no, h.description, h.posting_status, SUM(l.debit) AS total_debit, SUM(l.credit) AS total_kredit
FROM journal_headers h JOIN journal_lines l USING (header_id)
WHERE h.reference_no LIKE 'INV-%' GROUP BY 1, 2, 3 ORDER BY 1;

-- (Opsional) detail akun yang didebit/dikredit
SELECT h.reference_no, c.account_code, c.account_name, l.debit, l.credit
FROM journal_headers h JOIN journal_lines l USING (header_id) JOIN chart_of_accounts c USING (account_id)
WHERE h.reference_no LIKE 'INV-%' ORDER BY h.header_id, l.line_id;
