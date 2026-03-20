CREATE TABLE
    vault_withdrawals (
        id SERIAL PRIMARY KEY,
        month_id INTEGER NOT NULL,
        bucket_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        item_name VARCHAR(50),
        total_amount DECIMAL(10, 2) NOT NULL,
        pull_type VARCHAR(20) NOT NULL,
        withdrawal_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        reason VARCHAR(100),
        -- CHECK constraint to limit values
        CONSTRAINT check_pull_type CHECK (pull_type IN ('OVERSPEND_COVER')),
        -- Ensure total_amount are non-negative
        CONSTRAINT check_total_amount_positive CHECK (total_amount >= 0),
        -- Foreign keys
        CONSTRAINT fk_vault_withdrawals_tag FOREIGN KEY (tag_id) REFERENCES withdrawal_tags (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        CONSTRAINT fk_vault_withdrawals_bucket FOREIGN KEY (bucket_id) REFERENCES bucket_configs (bucket_id) ON DELETE RESTRICT ON UPDATE CASCADE,
        CONSTRAINT fk_vault_withdrawals_month FOREIGN KEY (month_id) REFERENCES paychecks (month_id) ON DELETE RESTRICT ON UPDATE CASCADE
    )
ALTER TABLE vault_withdrawals
ALTER COLUMN pull_type
SET DEFAULT 'OVERSPEND_COVER';

ALTER TABLE vault_withdrawals
ADD COLUMN target_bucket_id INTEGER REFERENCES bucket_configs (bucket_id);