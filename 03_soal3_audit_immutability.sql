-- =====================================================================
-- SOAL 3.2 - Audit trail, immutability, hash chain, RPC voucher & storno
-- Nama: Zan | NIM: 12030124130082 | UTS Pemrograman/Coding Akuntansi
-- PostgreSQL 16 / Supabase. Jalankan SELURUH file ini (Select All -> Run).
-- WAJIB dijalankan SETELAH file 01 dan 02.
-- =====================================================================

-- Khusus PostgreSQL biasa (pgAdmin / sandbox kelas): buat role bawaan Supabase
-- agar perintah REVOKE/GRANT di bawah tidak error. Di Supabase blok ini tidak berpengaruh.
DO $$ BEGIN CREATE ROLE anon NOLOGIN;          EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticated NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Jawaban 3.2 (sama dengan lembar jawaban Word)
-- Kolom jejak audit
CREATE OR REPLACE FUNCTION fn_actor() RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT COALESCE((NULLIF(current_setting('request.jwt.claims', true), '')::json ->> 'sub'), current_user)
$$;

ALTER TABLE chart_of_accounts ADD COLUMN is_cash_account BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE journal_headers ALTER COLUMN created_by SET DEFAULT fn_actor();
ALTER TABLE journal_headers
    ADD COLUMN chain_no      BIGINT UNIQUE,
    ADD COLUMN posted_by     VARCHAR(100),
    ADD COLUMN posted_at     TIMESTAMPTZ,
    ADD COLUMN prev_hash     CHAR(64),
    ADD COLUMN hash_checksum CHAR(64),
    ADD COLUMN reversal_of   BIGINT REFERENCES journal_headers (header_id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX ux_one_reversal ON journal_headers (reversal_of) WHERE reversal_of IS NOT NULL;

CREATE TABLE audit_log (
    audit_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name TEXT NOT NULL, record_id BIGINT, action TEXT NOT NULL,
    old_data   JSONB, new_data JSONB,
    actor      TEXT NOT NULL, acted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION fn_audit_log() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, actor)
    VALUES (TG_TABLE_NAME,
            (COALESCE(to_jsonb(NEW), to_jsonb(OLD)) ->>
                CASE TG_TABLE_NAME WHEN 'journal_lines' THEN 'line_id' ELSE 'header_id' END)::BIGINT,
            TG_OP,
            CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END,
            fn_actor());
    RETURN NULL;
END; $$;

CREATE TRIGGER trg_hdr_audit  AFTER INSERT OR UPDATE OR DELETE ON journal_headers
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();
CREATE TRIGGER trg_line_audit AFTER INSERT OR UPDATE OR DELETE ON journal_lines
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Penguncian jurnal POSTED: UPDATE / DELETE ditolak
CREATE OR REPLACE FUNCTION fn_block_posted_mutation() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE v_hid BIGINT; v_status VARCHAR(10);
BEGIN
    IF TG_TABLE_NAME = 'journal_headers' THEN
        v_hid := OLD.header_id;  v_status := OLD.posting_status;
    ELSE
        v_hid := CASE WHEN TG_OP = 'INSERT' THEN NEW.header_id ELSE OLD.header_id END;
        SELECT posting_status INTO v_status FROM journal_headers WHERE header_id = v_hid;
    END IF;
    IF v_status = 'POSTED' THEN
        RAISE EXCEPTION 'Jurnal % berstatus POSTED dan immutable (% ditolak). Gunakan jurnal pembalik (storno).',
            v_hid, TG_OP USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END; $$;

CREATE TRIGGER trg_hdr_immutable  BEFORE UPDATE OR DELETE ON journal_headers
    FOR EACH ROW EXECUTE FUNCTION fn_block_posted_mutation();
CREATE TRIGGER trg_line_immutable BEFORE INSERT OR UPDATE OR DELETE ON journal_lines
    FOR EACH ROW EXECUTE FUNCTION fn_block_posted_mutation();

-- Hash checksum berantai (disegel saat POSTED)
CREATE OR REPLACE FUNCTION fn_compute_hash(h journal_headers, p_prev TEXT) RETURNS CHAR(64)
LANGUAGE sql STABLE AS $$
    SELECT encode(sha256(convert_to(concat_ws('|',
        h.chain_no, h.header_id, h.trx_date, h.reference_no, h.description,
        h.created_by, h.reversal_of,
        (SELECT string_agg(account_id || ':' || debit || ':' || credit, ';' ORDER BY line_id)
           FROM journal_lines WHERE header_id = h.header_id),
        p_prev), 'UTF8')), 'hex')
$$;

CREATE OR REPLACE FUNCTION fn_seal_journal() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_prev TEXT;
BEGIN
    IF OLD.posting_status = 'DRAFT' AND NEW.posting_status = 'POSTED' THEN
        PERFORM pg_advisory_xact_lock(hashtext('journal_hash_chain'));
        SELECT COALESCE(MAX(chain_no), 0) + 1 INTO NEW.chain_no FROM journal_headers;
        SELECT hash_checksum INTO v_prev FROM journal_headers WHERE chain_no = NEW.chain_no - 1;
        v_prev := COALESCE(v_prev, repeat('0', 64));
        NEW.posted_by     := fn_actor();
        NEW.posted_at     := clock_timestamp();
        NEW.prev_hash     := v_prev;
        NEW.hash_checksum := fn_compute_hash(NEW, v_prev);
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_hdr_seal BEFORE UPDATE ON journal_headers
    FOR EACH ROW EXECUTE FUNCTION fn_seal_journal();

CREATE OR REPLACE FUNCTION fn_verify_ledger_integrity()
RETURNS TABLE (chain_no BIGINT, header_id BIGINT, reference_no VARCHAR, hash_ok BOOLEAN, chain_ok BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT h.chain_no, h.header_id, h.reference_no,
           h.hash_checksum = fn_compute_hash(h, h.prev_hash),
           h.prev_hash = COALESCE(p.hash_checksum, repeat('0', 64))
    FROM journal_headers h
    LEFT JOIN journal_headers p ON p.chain_no = h.chain_no - 1
    WHERE h.posting_status = 'POSTED'
    ORDER BY h.chain_no
$$;
-- RPC posting voucher kas keluar
CREATE OR REPLACE FUNCTION post_cash_out_voucher(
    p_trx_date DATE, p_reference_no VARCHAR, p_description TEXT, p_lines JSONB)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_header BIGINT;
BEGIN
    IF jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) < 2 THEN
        RAISE EXCEPTION 'Voucher minimal memiliki 2 baris';
    END IF;

    INSERT INTO journal_headers (trx_date, reference_no, description)
    VALUES (p_trx_date, p_reference_no, p_description)
    RETURNING header_id INTO v_header;

    INSERT INTO journal_lines (header_id, account_id, debit, credit)
    SELECT v_header, l.account_id, l.debit, l.credit
    FROM jsonb_to_recordset(p_lines) AS l(account_id BIGINT, debit NUMERIC, credit NUMERIC);

    IF NOT EXISTS (SELECT 1 FROM journal_lines jl JOIN chart_of_accounts c USING (account_id)
                   WHERE jl.header_id = v_header AND c.is_cash_account AND jl.credit > 0)
       OR EXISTS  (SELECT 1 FROM journal_lines jl JOIN chart_of_accounts c USING (account_id)
                   WHERE jl.header_id = v_header AND c.is_cash_account AND jl.debit > 0) THEN
        RAISE EXCEPTION 'Voucher kas keluar harus mengkredit akun kas/bank dan tidak boleh mendebitnya';
    END IF;

    SET CONSTRAINTS ctrg_lines_balanced, ctrg_header_balanced IMMEDIATE;
    UPDATE journal_headers SET posting_status = 'POSTED' WHERE header_id = v_header;
    RETURN v_header;
END; $$;

-- RPC jurnal pembalik (storno)
CREATE OR REPLACE FUNCTION reverse_journal(p_header_id BIGINT, p_reason TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_old journal_headers; v_new BIGINT;
BEGIN
    SELECT * INTO v_old FROM journal_headers WHERE header_id = p_header_id FOR UPDATE;
    IF NOT FOUND OR v_old.posting_status <> 'POSTED' THEN
        RAISE EXCEPTION 'Hanya jurnal POSTED yang dapat dibalik';
    END IF;
    IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
        RAISE EXCEPTION 'Alasan storno wajib diisi';
    END IF;

    INSERT INTO journal_headers (trx_date, reference_no, description, reversal_of)
    VALUES (CURRENT_DATE, 'REV-' || v_old.reference_no,
            'Storno ' || v_old.reference_no || ': ' || p_reason, v_old.header_id)
    RETURNING header_id INTO v_new;

    INSERT INTO journal_lines (header_id, account_id, debit, credit)
    SELECT v_new, account_id, credit, debit FROM journal_lines WHERE header_id = v_old.header_id;

    SET CONSTRAINTS ctrg_lines_balanced, ctrg_header_balanced IMMEDIATE;
    UPDATE journal_headers SET posting_status = 'POSTED' WHERE header_id = v_new;
    RETURN v_new;
END; $$;

-- Hak akses: aplikasi hanya melalui RPC
REVOKE ALL ON journal_headers, journal_lines, audit_log FROM anon, authenticated;
GRANT  SELECT ON journal_headers, journal_lines, chart_of_accounts TO authenticated;
REVOKE EXECUTE ON FUNCTION post_cash_out_voucher(DATE, VARCHAR, TEXT, JSONB),
                           reverse_journal(BIGINT, TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION post_cash_out_voucher(DATE, VARCHAR, TEXT, JSONB),
                           reverse_journal(BIGINT, TEXT) TO authenticated;





-- ---------------------------------------------------------------------
-- DATA AWAL: tandai akun Kas & Bank sebagai akun kas (dipakai RPC voucher kas keluar)
-- ---------------------------------------------------------------------
UPDATE chart_of_accounts SET is_cash_account = TRUE WHERE account_code IN ('1-1100','1-1200');
