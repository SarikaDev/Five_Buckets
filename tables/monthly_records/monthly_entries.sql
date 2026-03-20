CREATE TABLE
    monthly_entries (
        id SERIAL PRIMARY KEY,
        month_id INTEGER NOT NULL,
        bucket_id INTEGER NOT NULL,
        allocated DECIMAL(10, 2),
        spent DECIMAL(10, 2),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        -- Ensure allocated and spent are non-negative
        CONSTRAINT check_allocated_positive CHECK (allocated >= 0),
        CONSTRAINT check_spent_positive CHECK (spent >= 0),
        -- Ensure spent doesn't exceed allocated (optional business rule)
        CONSTRAINT check_spent_not_exceed_allocated CHECK (spent <= allocated),
        CONSTRAINT fk_monthly_id FOREIGN KEY (month_id) REFERENCES paychecks (month_id) ON DELETE RESTRICT ON UPDATE CASCADE,
        CONSTRAINT fk_bucket_id FOREIGN KEY (bucket_id) REFERENCES bucket_configs (bucket_id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

ALTER TABLE monthly_entries ADD CONSTRAINT fk_bucket_configs_bucket_id FOREIGN KEY (bucket_id) REFERENCES bucket_configs (bucket_id) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE monthly_entries
ALTER COLUMN spent
SET DEFAULT 0,
ALTER COLUMN spent
SET
    NOT NULL;

-- Patch any existing NULLs
UPDATE monthly_entries
SET
    spent = 0
WHERE
    spent IS NULL;