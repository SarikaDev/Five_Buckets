SELECT
    *
FROM
    bucket_types
SELECT
    *
FROM
    bucket_configs
SELECT
    *
FROM
    vault_withdrawals
SELECT
    *
FROM
    vault_withdrawal_sources
SELECT
    *
FROM
    vault_entries
WHERE
    bucket_id = 6
SELECT
    *
FROM
    monthly_entries
SELECT
    *
FROM
    ledger_entries
SELECT
    *
FROM
    vault_status
SELECT
    *
FROM
    paychecks
    -- VAULT_CREDIT
INSERT INTO
    bucket_configs (
        bucket_id,
        bucket_name,
        display_type,
        display_order,
        is_active,
        notes
    )
VALUES
    (
        7,
        'Emergency Funds',
        'ORANGE',
        6,
        true,
        'monthly emergency Suprises'
    );

INSERT INTO
    paychecks (month_id, month_label, salary, notes)
VALUES
    (2, 'Jan 2026', 100000, 'feb salary');

INSERT INTO
    monthly_entries (month_id, bucket_id, allocated)
VALUES
    (1, 7, 0);

SELECT
    COALESCE(SUM(le.amount), 0)
FROM
    ledger_entries le
WHERE
    le.monthly_entry_id = 1
    AND le.bucket_id = 6
SELECT
    *
FROM
    vault_status;

SELECT
    *
FROM
    vault_withdrawals;

SELECT
    *
FROM
    vault_withdrawal_sources;

INSERT INTO
    vault_withdrawals (
        month_id,
        bucket_id,
        tag_id,
        target_bucket_id,
        total_amount,
        pull_type
    )
VALUES
    (1, 6, 1, 7, 5000, 'OVERSPEND_COVER');

INSERT INTO
    vault_entries (month_id, bucket_id, total_drip)
VALUES
    (1, 6, 499);

-- Block
INSERT INTO
    ledger_entries (
        monthly_entry_id,
        bucket_id,
        description,
        amount,
        txn_type
    )
VALUES
    (1, 6, 'January Drip', 499, 'VAULT_CREDIT');

-- feb Block
INSERT INTO
    ledger_entries (
        monthly_entry_id,
        bucket_id,
        description,
        amount,
        txn_type
    )
VALUES
    (2, 6, 'Feb Drip', 4500, 'CONTRIBUTION');

INSERT INTO
    ledger_entries (
        monthly_entry_id,
        bucket_id,
        description,
        amount,
        txn_type
    )
VALUES
    (1, 6, 'JAN Movie', 500, 'SPEND');

INSERT INTO
    ledger_entries (
        monthly_entry_id,
        bucket_id,
        description,
        amount,
        txn_type
    )
VALUES
    (1, 6, 'January Function', 300, 'CONTRIBUTION');

DELETE FROM vault_entries
WHERE
    vault_wd_id IN (16);

SELECT
    set_config ('app.vault_operation_active', 'true', false)
DELETE FROM ledger_entries
WHERE
    bucket_id = 4
DELETE FROM vault_withdrawals
WHERE
    bucket_id IN (6, 7);

DELETE FROM vault_withdrawal_sources
WHERE
    id = 8;

INSERT INTO
    vault_withdrawals (
        month_id,
        bucket_id,
        tag_id,
        item_name,
        total_amount,
        reason
    )
VALUES
    (1, 6, 1, 'Test Item', 50.00, 'Test withdrawal');