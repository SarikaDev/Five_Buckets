CREATE TABLE
    vault_withdrawal_sources (
        id SERIAL PRIMARY KEY,
        withdrawal_id INTEGER NOT NULL,
        source_month_id INTEGER NOT NULL,
        amount_taken DECIMAL(10, 2) NOT NULL,
        -- Ensure total_amount are non-negative
        CONSTRAINT check_amount_taken_positive CHECK (amount_taken >= 0),
        -- Foreign keys
        CONSTRAINT fk_vault_withdrawals_source_id FOREIGN KEY (withdrawal_id) REFERENCES vault_withdrawals (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        CONSTRAINT fk_vault_withdrawals_source_month FOREIGN KEY (source_month_id) REFERENCES paychecks (month_id) ON DELETE RESTRICT ON UPDATE CASCADE
    ) CREATE INDEX idx_vault_sources_month ON vault_withdrawal_sources (source_month_id);

ALTER TABLE vault_withdrawal_sources
DROP CONSTRAINT fk_vault_withdrawals_source_id;

ALTER TABLE vault_withdrawal_sources
DROP CONSTRAINT fk_vault_withdrawals_source_month;

-- Add correct FK pointing to vault_entries.id
ALTER TABLE vault_withdrawal_sources ADD CONSTRAINT fk_vws_vault_entry FOREIGN KEY (source_month_id) REFERENCES vault_entries (id) ON DELETE CASCADE ON UPDATE CASCADE;

-- remove is_fully_used falg
CREATE VIEW
    vault_status AS
SELECT
    ve.month_id,
    ve.total_drip,
    COALESCE(SUM(vws.amount_taken), 0) AS used,
    ve.total_drip - COALESCE(SUM(vws.amount_taken), 0) AS remaining,
    (
        ve.total_drip - COALESCE(SUM(vws.amount_taken), 0) <= 0
    ) AS is_drained
FROM
    vault_entries ve
    LEFT JOIN vault_withdrawal_sources vws ON ve.month_id = vws.source_month_id
GROUP BY
    ve.month_id,
    ve.total_drip;