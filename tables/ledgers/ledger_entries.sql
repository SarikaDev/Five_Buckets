CREATE TABLE
    ledger_entries (
        id SERIAL PRIMARY KEY,
        monthly_entry_id INTEGER NOT NULL,
        bucket_id INTEGER NOT NULL,
        vault_wd_id INTEGER DEFAULT NULL,
        description VARCHAR(150),
        amount DECIMAL(10, 2),
        txn_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        txn_type VARCHAR(20) NOT NULL,
        -- CHECK constraint to limit values
        CONSTRAINT check_txn_type CHECK (txn_type IN ('SPEND', 'CONTRIBUTION')),
        -- Ensure amount and spent are non-negative
        CONSTRAINT check_amount_positive CHECK (amount >= 0),
        -- Foreign keys
        CONSTRAINT fk_ledger_monthly_entry FOREIGN KEY (monthly_entry_id) REFERENCES monthly_entries (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        CONSTRAINT fk_bucket_id FOREIGN KEY (bucket_id) REFERENCES bucket_configs (bucket_id) ON DELETE RESTRICT ON UPDATE CASCADE
    )

ALTER TABLE ledger_entries
ADD COLUMN box_event_id INTEGER REFERENCES box_events(id);


    ALTER TABLE ledger_entries
ADD COLUMN vault_credit_id INTEGER;

ALTER TABLE ledger_entries
ADD CONSTRAINT fk_vault_credit
FOREIGN KEY (vault_credit_id)
REFERENCES vault_entries(id)
ON DELETE RESTRICT
ON UPDATE CASCADE;


ALTER TABLE ledger_entries
DROP CONSTRAINT IF EXISTS check_txn_type;

ALTER TABLE ledger_entries
ADD CONSTRAINT check_txn_type 
CHECK (txn_type IN ('CONTRIBUTION', 'VAULT_CREDIT', 'VAULT_WITHDRAWAL', 'SPEND'));


    -- Trigger to ensure monthly_entry_id and bucket_id are consistent

-- Function to ensure monthly_entry_id and bucket_id are consistent
CREATE OR REPLACE FUNCTION ensure_ledger_bucket_consistency()
RETURNS TRIGGER AS $$
DECLARE
    v_monthly_bucket_id INTEGER;
    v_monthly_allocated DECIMAL(10, 2);
    v_total_spent DECIMAL(10, 2);
    v_remaining DECIMAL(10, 2);

BEGIN
    -- Get the bucket_id and allocated from monthly_entries
    SELECT bucket_id, allocated INTO v_monthly_bucket_id, v_monthly_allocated
       WHERE month_id = NEW.monthly_entry_id  -- NEW.monthly_entry_id is actually month_id
    AND bucket_id = NEW.bucket_id;  -- Match the bucket too
    
    -- Check if such combination exists
    IF v_monthly_entry_id IS NULL THEN
        RAISE EXCEPTION 'No monthly entry found for month_id % and bucket_id %', 
            NEW.monthly_entry_id, NEW.bucket_id;
    END IF;
    
    
    -- Calculate total spent including this transaction
    SELECT COALESCE(SUM(amount), 0) INTO v_total_spent
    FROM ledger_entries
    WHERE monthly_entry_id = NEW.monthly_entry_id;
    
    -- For UPDATE, exclude the old amount
    IF TG_OP = 'UPDATE' THEN
        v_total_spent := v_total_spent - OLD.amount;
    END IF;
    
  	 v_remaining := v_monthly_allocated - v_total_spent;
    
     -- Check budget limit
    IF NEW.amount > v_remaining THEN
        RAISE EXCEPTION 'Budget exceeded for bucket ID %: Allocated: %, Already spent: %, Remaining: %, Attempted: % - You can only contribute up to %',
            NEW.bucket_id, 
            v_monthly_allocated, 
            v_total_spent, 
            v_remaining,
            NEW.amount,
            v_remaining;
    END IF;
    
    -- Update monthly_entries spent amount
    UPDATE monthly_entries 
    SET spent = v_total_spent + NEW.amount
    WHERE id = NEW.monthly_entry_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER trigger_ensure_ledger_consistency
    BEFORE INSERT OR UPDATE ON ledger_entries
    FOR EACH ROW
    EXECUTE FUNCTION ensure_ledger_bucket_consistency();

    ---OLD

       -- Trigger to ensure monthly_entry_id and bucket_id are consistent

-- Function to ensure monthly_entry_id and bucket_id are consistent
CREATE OR REPLACE FUNCTION ensure_ledger_bucket_consistency()
RETURNS TRIGGER AS $$
DECLARE
    v_monthly_allocated  DECIMAL(10, 2);
    v_current_spent      DECIMAL(10, 2);
    v_remaining          DECIMAL(10, 2);
    v_delta              DECIMAL(10, 2);
BEGIN
    -- Lock the monthly_entries row immediately to serialize concurrent writes.
    -- FOR UPDATE prevents race conditions under heavy concurrent inserts/updates.
    SELECT allocated, spent
    INTO   v_monthly_allocated, v_current_spent
    FROM   monthly_entries
    WHERE  month_id        = NEW.monthly_entry_id
      AND  bucket_id = NEW.bucket_id
    FOR UPDATE;

    -- Guard: row must exist
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Invalid monthly_entry_id=% / bucket_id=% combination',
            NEW.monthly_entry_id, NEW.bucket_id;
    END IF;

    -- Compute the net change this operation represents:
    --   INSERT  →  +NEW.amount
    --   UPDATE  →  NEW.amount - OLD.amount  (negative when reducing)
    --   DELETE  →  -OLD.amount
    v_delta := CASE TG_OP
                   WHEN 'INSERT' THEN  NEW.amount
                   WHEN 'UPDATE' THEN  NEW.amount - OLD.amount
                   WHEN 'DELETE' THEN -OLD.amount
               END;

    v_remaining := v_monthly_allocated - v_current_spent;

    -- Enforce budget only when the delta would increase spending
    IF v_delta > 0 AND v_delta > v_remaining THEN
        RAISE EXCEPTION
            'Budget exceeded — bucket_id: %, allocated: %, spent: %, remaining: %, attempted delta: % (max allowed: %)',
            NEW.bucket_id,
            v_monthly_allocated,
            v_current_spent,
            v_remaining,
            v_delta,
            v_remaining;
    END IF;

    -- Atomic increment: no re-aggregation, no extra seq-scan on ledger_entries
    UPDATE monthly_entries
    SET    spent = spent + v_delta
    WHERE  id    = NEW.monthly_entry_id;

    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER trigger_ensure_ledger_consistency
    BEFORE INSERT OR UPDATE OR DELETE ON ledger_entries
    FOR EACH ROW
    EXECUTE FUNCTION ensure_ledger_bucket_consistency();