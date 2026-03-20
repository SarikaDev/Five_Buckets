SELECT * FROM bucket_types;
SELECT * FROM bucket_configs;
SELECT * FROM vault_withdrawals;
SELECT * FROM vault_withdrawal_sources;
SELECT * FROM vault_entries WHERE bucket_id = 6;
SELECT * FROM monthly_entries  WHERE bucket_id = 3;
SELECT * FROM ledger_entries  WHERE bucket_id = 3;
SELECT * FROM vault_status;
SELECT * FROM blue_box_state
SELECT * FROM box_events
SELECT * FROM blue_box_withdrawals 
SELECT * FROM blue_box_withdrawal_sources 
INSERT INTO box_events (bucket_id, month_id, box_type, amount)
VALUES (3, 1, 'SEALED', NULL);

INSERT INTO ledger_entries (monthly_entry_id, bucket_id, amount, txn_type)
VALUES (1, 3, 100.00, 'CONTRIBUTION');


DELETE FROM ledger_entries
WHERE id IN (14,24,28,29)

DELETE FROM box_events
WHERE id IN (8,12,16,17)

-- Should be BLOCKED
INSERT INTO box_events (bucket_id, month_id, box_type, amount)
VALUES (3, 1, 'WITHDRAW', 1200.00);

SELECT * FROM ledger_entries 
WHERE bucket_id = 3
ORDER BY id DESC LIMIT 3;

SELECT * FROM monthly_entries WHERE bucket_id = 3; 
SELECT * FROM bucket_configs WHERE bucket_id = 3;

INSERT INTO monthly_entries (month_id, bucket_id, allocated, spent)
VALUES (1, 3, 1000.00, 0)

CREATE TRIGGER trg_box_events_after_insert
AFTER INSERT ON box_events
FOR EACH ROW EXECUTE FUNCTION trg_box_events_after_insert();
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid = 'box_events'::regclass;



INSERT INTO box_events (bucket_id, month_id, box_type, amount, description)
VALUES (3, 1, 'DEPOSIT', 500.00, 'January Tax 2 savings');



INSERT INTO blue_box_withdrawals (bucket_id, month_id, total_amount, description)
VALUES (3, 1, 1200.00, 'Should Fail');


INSERT INTO blue_box_withdrawals (bucket_id, month_id, total_amount, description)
VALUES (3, 1, 300.00, 'Should fail');


SELECT 
    SUM(me.allocated) - COALESCE(SUM(bbws.amount_taken), 0) AS remaining
FROM monthly_entries me
LEFT JOIN blue_box_withdrawal_sources bbws ON me.id = bbws.source_entry_id
WHERE me.bucket_id = 3;
ALTER TABLE monthly_entries 
DROP CONSTRAINT check_spent_not_exceed_allocated;


delete connections: (blue_box_withdrawals)

blue_box_withdrawal_sources will delete automatically
box_events with WITHDRAW will be delete automatically
ledger_entries with SPEND will be delete automatically
monthly_entries of that particular Spend amt will be deducted from spent column

insert connections: (box_events)
Direct ledger inserts not allowed for blue box bucket, use box_events

We must insert records via box_events table only
corresponding record will be inserted into ledger_entries as CONTRIBUTION


WIP

we can't directly blue record from  box_events, 1st ledger_entries then only should delete box_events