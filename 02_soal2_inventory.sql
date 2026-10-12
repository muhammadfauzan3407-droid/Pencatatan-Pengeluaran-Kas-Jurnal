-- =====================================================================
-- SOAL 2 - Trigger persediaan perpetual
-- Nama: Zan | NIM: 12030124130082 | UTS Pemrograman/Coding Akuntansi
-- PostgreSQL 16 / Supabase. Jalankan SELURUH file ini (Select All -> Run).
-- WAJIB dijalankan SETELAH file 01.
-- =====================================================================

-- Tabel dari naskah soal (diberikan)
CREATE TABLE inventory_items (
    item_id   VARCHAR(10) PRIMARY KEY,
    item_name VARCHAR(100),
    stock_qty INT NOT NULL DEFAULT 0,
    unit_cost NUMERIC(15, 2) NOT NULL
);
CREATE TABLE inventory_transactions (
    trx_id   SERIAL PRIMARY KEY,
    item_id  VARCHAR(10) REFERENCES inventory_items(item_id),
    trx_type VARCHAR(10) CHECK (trx_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT')),
    qty      INT NOT NULL,
    trx_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Jawaban 2.1 (sama dengan lembar jawaban Word)
-- Fungsi pembantu: jurnal 2 baris (DRAFT -> baris -> POSTED)
CREATE OR REPLACE FUNCTION fn_post_two_line_journal(
    p_ref VARCHAR, p_desc TEXT, p_debit_code VARCHAR, p_credit_code VARCHAR, p_amount NUMERIC)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_header BIGINT;
BEGIN
    INSERT INTO journal_headers (trx_date, reference_no, description)
    VALUES (CURRENT_DATE, p_ref, p_desc) RETURNING header_id INTO v_header;

    INSERT INTO journal_lines (header_id, account_id, debit, credit)
    SELECT v_header, account_id, p_amount, 0 FROM chart_of_accounts WHERE account_code = p_debit_code;
    INSERT INTO journal_lines (header_id, account_id, debit, credit)
    SELECT v_header, account_id, 0, p_amount FROM chart_of_accounts WHERE account_code = p_credit_code;

    UPDATE journal_headers SET posting_status = 'POSTED' WHERE header_id = v_header;
    RETURN v_header;
END; $$;

-- Akun: 1-1300 Persediaan | 5-1100 HPP | 2-1100 Utang Usaha | 5-9100 Selisih Persediaan
CREATE OR REPLACE FUNCTION trg_update_stock_and_journal()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_current_qty INT;
    v_unit_cost   NUMERIC(15,2);
    v_delta       INT;
    v_new_qty     INT;
BEGIN
    IF NEW.trx_type IN ('PURCHASE', 'SALE') AND NEW.qty <= 0 THEN
        RAISE EXCEPTION 'Qty % tidak valid untuk %', NEW.qty, NEW.trx_type
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT stock_qty, unit_cost INTO v_current_qty, v_unit_cost
    FROM inventory_items WHERE item_id = NEW.item_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item % tidak ditemukan', NEW.item_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    v_delta   := CASE NEW.trx_type WHEN 'SALE' THEN -NEW.qty ELSE NEW.qty END;
    v_new_qty := v_current_qty + v_delta;

    -- (b) anti-negative inventory
    IF v_new_qty < 0 THEN
        RAISE EXCEPTION 'Stok item % tidak cukup: tersedia %, diminta %',
            NEW.item_id, v_current_qty, ABS(v_delta)
            USING ERRCODE = 'check_violation';
    END IF;

    -- (a) mutasi stok
    UPDATE inventory_items SET stock_qty = v_new_qty WHERE item_id = NEW.item_id;

    -- jurnal otomatis Persediaan / HPP
    IF NEW.trx_type = 'SALE' THEN
        PERFORM fn_post_two_line_journal('INV-' || NEW.trx_id, 'HPP ' || NEW.item_id,
                '5-1100', '1-1300', NEW.qty * v_unit_cost);
    ELSIF NEW.trx_type = 'PURCHASE' THEN
        PERFORM fn_post_two_line_journal('INV-' || NEW.trx_id, 'Pembelian ' || NEW.item_id,
                '1-1300', '2-1100', NEW.qty * v_unit_cost);
    ELSIF NEW.qty > 0 THEN
        PERFORM fn_post_two_line_journal('INV-' || NEW.trx_id, 'Penyesuaian + ' || NEW.item_id,
                '1-1300', '5-9100', NEW.qty * v_unit_cost);
    ELSIF NEW.qty < 0 THEN
        PERFORM fn_post_two_line_journal('INV-' || NEW.trx_id, 'Penyesuaian - ' || NEW.item_id,
                '5-9100', '1-1300', ABS(NEW.qty) * v_unit_cost);
    END IF;

    RETURN NEW;
END; $$;

CREATE TRIGGER trg_inventory_transactions_ai
    AFTER INSERT ON inventory_transactions
    FOR EACH ROW EXECUTE FUNCTION trg_update_stock_and_journal();


-- ---------------------------------------------------------------------
-- DATA AWAL: 1 barang contoh, stok 0, harga pokok Rp50.000
-- ---------------------------------------------------------------------
INSERT INTO inventory_items (item_id, item_name, stock_qty, unit_cost)
VALUES ('BRG-001', 'Kertas HVS A4 (rim)', 0, 50000);

-- ---------------------------------------------------------------------
-- 2.2 Concurrency (sama dengan lembar jawaban; contoh kode, tidak perlu dijalankan)
-- ---------------------------------------------------------------------
-- 1. Pessimistic locking
--   BEGIN;
--     SELECT stock_qty FROM inventory_items WHERE item_id = 'BRG-001' FOR UPDATE;
--     INSERT INTO inventory_transactions (item_id, trx_type, qty) VALUES ('BRG-001','SALE',1);
--   COMMIT;
-- 2. Atomic conditional update (0 baris dikembalikan = stok habis)
--   UPDATE inventory_items SET stock_qty = stock_qty - 1
--   WHERE item_id = 'BRG-001' AND stock_qty >= 1 RETURNING stock_qty;
-- 3. Isolasi Serializable (ulangi transaksi bila ERROR 40001)
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--     INSERT INTO inventory_transactions (item_id, trx_type, qty) VALUES ('BRG-001','SALE',1);
--   COMMIT;
-- 4. Pengaman terakhir
--   ALTER TABLE inventory_items ADD CONSTRAINT ck_stock_non_negative CHECK (stock_qty >= 0);
