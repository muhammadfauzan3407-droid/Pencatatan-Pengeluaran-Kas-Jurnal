-- =====================================================================
-- SOAL 1 - General Ledger: tabel, constraint, trigger Debit=Kredit
-- Nama: Zan | NIM: 12030124130082 | UTS Pemrograman/Coding Akuntansi
-- PostgreSQL 16 / Supabase. Jalankan SELURUH file ini (Select All -> Run).
-- =====================================================================

CREATE TABLE chart_of_accounts (
    account_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_code    VARCHAR(20)  NOT NULL UNIQUE,
    account_name    VARCHAR(150) NOT NULL,
    normal_balance  VARCHAR(6)   NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    report_class    VARCHAR(12)  NOT NULL CHECK (report_class IN
                        ('ASET', 'LIABILITAS', 'EKUITAS', 'PENDAPATAN', 'BEBAN')),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE journal_headers (
    header_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trx_date        DATE         NOT NULL,
    reference_no    VARCHAR(50)  NOT NULL UNIQUE,
    description     TEXT         NOT NULL,
    posting_status  VARCHAR(10)  NOT NULL DEFAULT 'DRAFT'
                        CHECK (posting_status IN ('DRAFT', 'POSTED', 'VOID')),
    created_by      VARCHAR(100) NOT NULL DEFAULT current_user,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE journal_lines (
    line_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    header_id   BIGINT NOT NULL REFERENCES journal_headers (header_id)    ON DELETE RESTRICT,
    account_id  BIGINT NOT NULL REFERENCES chart_of_accounts (account_id) ON DELETE RESTRICT,
    debit       NUMERIC(18,2) NOT NULL DEFAULT 0,
    credit      NUMERIC(18,2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_line_non_negative  CHECK (debit >= 0 AND credit >= 0),
    CONSTRAINT ck_line_not_both_zero CHECK (NOT (debit = 0 AND credit = 0)),
    CONSTRAINT ck_line_single_side   CHECK (debit = 0 OR credit = 0)
);

CREATE INDEX ix_lines_header  ON journal_lines (header_id);
CREATE INDEX ix_lines_account ON journal_lines (account_id);


CREATE OR REPLACE FUNCTION fn_assert_journal_balanced()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_header_id BIGINT; v_status VARCHAR(10);
    v_debit NUMERIC(18,2); v_credit NUMERIC(18,2); v_lines INT;
BEGIN
    IF TG_TABLE_NAME = 'journal_headers' THEN v_header_id := NEW.header_id;
    ELSIF TG_OP = 'DELETE' THEN v_header_id := OLD.header_id;
    ELSE v_header_id := NEW.header_id;
    END IF;

    SELECT posting_status INTO v_status FROM journal_headers WHERE header_id = v_header_id;
    IF NOT FOUND OR v_status <> 'POSTED' THEN RETURN NULL; END IF;

    SELECT COALESCE(SUM(debit),0), COALESCE(SUM(credit),0), COUNT(*)
      INTO v_debit, v_credit, v_lines
    FROM journal_lines WHERE header_id = v_header_id;

    IF v_lines < 2 THEN
        RAISE EXCEPTION 'Jurnal % harus memiliki minimal 2 baris', v_header_id
            USING ERRCODE = 'check_violation';
    END IF;
    IF v_debit <> v_credit THEN
        RAISE EXCEPTION 'Jurnal % tidak seimbang: debit=% kredit=%', v_header_id, v_debit, v_credit
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NULL;
END; $$;

CREATE CONSTRAINT TRIGGER ctrg_lines_balanced
    AFTER INSERT OR UPDATE OR DELETE ON journal_lines
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_assert_journal_balanced();

CREATE CONSTRAINT TRIGGER ctrg_header_balanced
    AFTER INSERT OR UPDATE OF posting_status ON journal_headers
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_assert_journal_balanced();


-- ---------------------------------------------------------------------
-- DATA AWAL: 8 akun contoh (urutan ID penting: voucher.html memakai ID 1-4)
-- ---------------------------------------------------------------------
INSERT INTO chart_of_accounts (account_code, account_name, normal_balance, report_class) VALUES
 ('1-1100','Kas',                 'DEBIT',  'ASET'),        -- id 1
 ('1-1200','Bank',                'DEBIT',  'ASET'),        -- id 2
 ('5-2100','Beban Listrik',       'DEBIT',  'BEBAN'),       -- id 3
 ('5-2200','Beban Gaji',          'DEBIT',  'BEBAN'),       -- id 4
 ('1-1300','Persediaan',          'DEBIT',  'ASET'),        -- id 5
 ('2-1100','Utang Usaha',         'CREDIT', 'LIABILITAS'),  -- id 6
 ('5-1100','HPP',                 'DEBIT',  'BEBAN'),       -- id 7
 ('5-9100','Selisih Persediaan',  'DEBIT',  'BEBAN');       -- id 8
