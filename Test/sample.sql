SELECT * FROM monthly_entries
SELECT * FROM ledger_entries

DROP FROM ledger_entries WHERE monthly_entry_id = 1 AND bucket_id = 3 ;
TRUNCATE TABLE ledger_entries


INSERT INTO ledger_entries(monthly_entry_id,bucket_id,description,amount,txn_type) 
 VALUES (1,5,'bucke05',2000,'CONTRIBUTION'),
(1, 3, 'Test 2', 2500, 'CONTRIBUTION');

INSERT INTO ledger_entries(monthly_entry_id, bucket_id, description, amount, txn_type)
VALUES (1, 5, 'Test 5', 2500, 'CONTRIBUTION');


INSERT INTO ledger_entries(monthly_entry_id, bucket_id, description, amount, txn_type)
VALUES (1, 3, 'Test 3', 20000, 'CONTRIBUTION');

UPDATE monthly_entries
SET spent = 0
WHERE id = 3;

SELECT COUNT(*) FROM ledger_entries;

SELECT * FROM pg_trigger WHERE tgname = 'trg_ledger_truncate_sync';

SELECT current_setting('app.ledger_recalc_active', true) = 'true'

DELETE FROM ledger_entries
WHERE id IN (106,107,108)

  SELECT tgname, tgrelid::regclass, tgenabled 
FROM   pg_trigger 
WHERE  tgname IN (
    'trg_ledger_sync',
    'trg_ledger_truncate_sync', 
    'trg_protect_spent' --- 0 means enables 
);


-- ______________________

WITH bucket_wise_spent_amount AS
(
SELECT
    le.bucket_id,
    SUM(le.amount) AS spent_amount
FROM ledger_entries le
GROUP BY le.bucket_id
)
SELECT
COALESCE(me.allocated,0) AS allocated_amount,
bwsa.spent_amount AS actual_spent_amount,
COALESCE(me.allocated,0) - bwsa.spent_amount AS remaining_amount
FROM monthly_entries me
RIGHT JOIN bucket_wise_spent_amount bwsa
ON me.bucket_id = bwsa.bucket_id;


```sql

BEGIN
    INSERT INTO ledger_entries (
        monthly_entry_id,
        bucket_id,
        vault_wd_id,
        description,
        amount,
        txn_date,
        txn_type
    ) VALUES (
        NEW.month_id,
        NEW.bucket_id,
        NEW.id,
        format('Vault withdrawal'),
        NEW.total_drip,
        NEW.drip_date,
        'SPEND'
    );

    RETURN NEW;
END;

```

CREATE OR REPLACE FUNCTION trg_vault_withdrawal_manage()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_remaining NUMERIC;
    r           RECORD;
    v_available NUMERIC;
BEGIN
    -- ===========================================================
    -- DELETE - restore amounts by removing sources
    -- ===========================================================
    IF TG_OP = 'DELETE' THEN
        DELETE FROM vault_withdrawal_sources
        WHERE withdrawal_id = OLD.id;
        RETURN OLD;
    END IF;

    -- ===========================================================
    -- UPDATE - rebuild allocation from scratch
    -- ===========================================================
    IF TG_OP = 'UPDATE' THEN
        DELETE FROM vault_withdrawal_sources
        WHERE withdrawal_id = NEW.id;
    END IF;

    -- ===========================================================
    -- INSERT or UPDATE - allocate from vault_entries oldest month first
    -- ===========================================================
    v_remaining := NEW.total_amount;

    FOR r IN
        SELECT
            ve.id                                                    AS vault_entry_id,
            ve.total_drip - COALESCE(SUM(vws.amount_taken), 0)      AS remaining
        FROM vault_entries ve
        LEFT JOIN vault_withdrawal_sources vws
            ON ve.id = vws.source_month_id
        WHERE ve.bucket_id = NEW.bucket_id
        GROUP BY ve.id, ve.total_drip, ve.month_id, ve.drip_date
        HAVING (ve.total_drip - COALESCE(SUM(vws.amount_taken), 0)) > 0
        ORDER BY ve.month_id ASC, ve.drip_date ASC  -- oldest month first, then oldest drip
    LOOP
        EXIT WHEN v_remaining <= 0;

        v_available := r.remaining;

        INSERT INTO vault_withdrawal_sources (
            withdrawal_id,
            source_month_id,   -- stores vault_entries.id
            amount_taken
        ) VALUES (
            NEW.id,
            r.vault_entry_id,
            LEAST(v_remaining, v_available)
        );

        v_remaining := v_remaining - LEAST(v_remaining, v_available);
    END LOOP;

    -- Safety: reject if vault balance insufficient
    IF v_remaining > 0 THEN
        RAISE EXCEPTION 
            'Vault does not have enough balance. Shortfall: %', v_remaining;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vault_withdrawal_manage
AFTER INSERT OR UPDATE OR DELETE ON vault_withdrawals
FOR EACH ROW EXECUTE FUNCTION trg_vault_withdrawal_manage();

View:

CREATE OR REPLACE VIEW vault_status AS
SELECT
    ve.id                                                   AS vault_entry_id,
    ve.month_id,
    ve.bucket_id,
    ve.drip_date,
    ve.total_drip,
    COALESCE(SUM(vws.amount_taken), 0)                      AS used,
    ve.total_drip - COALESCE(SUM(vws.amount_taken), 0)      AS remaining,
    (ve.total_drip - COALESCE(SUM(vws.amount_taken), 0) <= 0) AS is_drained
FROM vault_entries ve
LEFT JOIN vault_withdrawal_sources vws
    ON ve.id = vws.source_month_id       -- ✅ vault_entries.id
GROUP BY ve.id, ve.month_id, ve.bucket_id, ve.drip_date, ve.total_drip;