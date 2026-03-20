Triggers basically a snaps that handle CRUD operations as DataBase Level

Chapter One:

Table (monthly_entries aka me, leadger_entries aka le)

Rule:
No manual update will done for column (spent) on me,
Because (me) table was connected to (le), which means spent column must derive from (le)

```sql
WITH bucket_wise_spent_amount AS
(
SELECT
	le. monthly_entry_id,
    le.bucket_id,
    SUM(le.amount) AS spent_amount
FROM ledger_entries le
GROUP BY le.bucket_id,le. monthly_entry_id
)
SELECT
me.month_id,
COALESCE(me.allocated,0) AS allocated_amount,
bwsa.spent_amount AS actual_spent_amount,
COALESCE(me.allocated,0) - bwsa.spent_amount AS remaining_amount
FROM monthly_entries me
RIGHT JOIN bucket_wise_spent_amount bwsa
ON me.bucket_id = bwsa.bucket_id
AND me.month_id = bwsa.monthly_entry_id;
```

"spent column is system controlled and cannot be manually updated"

Trigger Fn's:

    trigger_name: trg_protect_from_manual_update_on_spent()
    trigger_function:

---

Trigger Details:

Trigger 01:

1. we can't update spent colum manually, because it's connected to ledger_entries table of it respective bucket_id and month_id.
2. spent amt cannot exceed allocated amt.
3. Once entry made in ledger_entries (INSERT) then we should change spent col (AUTO_UPDATE) in monthly_entries.

therefore,

leadger_entry_record is trigger_name and trigger_point was ledger_entries (INSERT,UPDATE,DELETE) where it internally focus on monthly_entries (AUTO_UPDATE).

INSERT/UPDATE:
then we shuould add entry amt into amount col which were detected from allocated and spent col will update from entry amt.

Note: If the entry amt was exceed than the remaining amt (we should calculate manually on-fly) then we should throw an exception with entry amt,allocated amt, spent amt, allowed to enter amt (remaining).

DELETE:
when some records of respective bucket_id with month_id combination then we should re-calculate the spent col in monthly_entries with previouse records sum of amount in spent column.

Trigger 02:
we should block user to manual update spent column in monthly_entries and if tried should throw an exception "spent column is system controlled and cannot be manually updated".

monthly_spent_blocker is trigger_name
monthly_entries (UPDATE) was trigger_point

NOTE: we should write a constraint that every Insert in monthly_entries on spent column was always 0 ( i mean if there are 0 records exists in ledger_entries then spent column was 0 only)

Trigger_03:
on TRUNCATE of ledger_entries we have to allow spent column in monthly_entries as 0.

trg_monthly_spent_reset is trigger_name
ledger_entries (TRUNCATE) was trigger_point.

---

at vault_entries table
we haev to check:

the bucket belongs to DRIP_IN (bucket_types.vault_role AND bucket_configs.display_type YELLOW) where we have bucket_id and display_type connections to vault_entries and bucket_types

we should only DRIP_IN when
WITH spent_summary AS
(
sum(le.amount) AS spent_amt
FROM leadger_entries AS le
JOIN monthly_entries AS me
ON le.monthly_entry_id = me.month_id
WHERE le.bucket_id = me.bucket_id
AND le.monthly_entry_id = me.month_id
)
SELECT
me.allocated - ss.spent_amt AS remaining_amt
FROM montly_entries AS me
JOIN spent_summary AS ss

here these remaining_amt (+ve) only have elgible to INSERT into vault_entries as total_drip.

where vault_entries table as columns
id,month_id,bucket_id,total_drip, drip_date

---

vault:
entry
withdraw
withdraw_source

monthly_entries
ledger_entries

NOTE: Operation start with monthly_entries table INSERTED data.

vault_entry scenario:
[monthly_entries]
cannot update spent col in monthly_entries.
can update allocated col in monthly_entries (only allocated > spent).

[ledger_entries]
cqn insert direct record in ledger, when we have vault_entry and vault_withdraw is null (Normal buckets)
cannot insert direct record in ledger, when we have special buckets attached to vault_entry or vault_withdraw.

we can directly update amount in ledger, when we have vault_entry and vault_withdraw is null (Normal buckets)
cannot directly update amount in ledger , when we have special buckets attached to vault_entry or vault_withdraw.

[ledger_entries] [special_bucket: YELLOW + DRIP_IN]

we can insert new record, where total_drip (specific bucket and specific month) was actually sum(ledger.amount) AS spent_amt (specific bucket and specific month)
this is the same value that we have in monthly_entries.spent

once recorded, then monthly_entries.spent will update and new record on ledger with vault_credit_id will be recorded.

[vault_entry]
we can only update total_drip col from vault_entries, which automatically allows to update all its corresponding records like
(ledger,monthly_entry).

vault_withdraw scenario:
there is no connection with monthly_entries table.

when a record is recorded then [ledger_entries] with vault_wd_id will created where vault_credited_id is NULL will be automatic, Also
vault_withdrawal_source should also auto created.

we manually pick month_id (here in vault_entries table we have common bucket_id and common month_id based records the unique was vault_entries.id)
why common bucket_id and month_id because we can enter data in different drip_date so
when i pick month_id,tag_id,item_name,total_amount,reason
then i mean we are representing
The month_id in which the withdrawal happened, so i should have desire to pick on which months (vault_entries) should grab

imagine
in vault_entries
we have onn jan 5th (total_drip as 500), jan 16th (total_drip as 100)
and feb 4th (total_drip as 50) , feb 28th (total_drip as 50)

so now in vault_withdrawals when i enter month_id,tag_id,item_name,total_amount,reason then is should iterate from jan to feb AHH that's what we arewn doing i guess

at final pull_type (default value as OVERSPEND_COVER),bucket_id should grab from corresonding vault_entries

at last vault_withdrawal_sources with withdrawal_id ,source_month_id ,amount_taken should loged in vault_withdrawal_sources table
NOTE: INSERT/UPDATE/DELETE should handle
i mean if we delete vault_withdrawals then the amount should restore

---

SELECT _ FROM vault_entries WHERE bucket_id = 6
SELECT _ FROM monthly_entries WHERE bucket_id = 6
SELECT \* FROM ledger_entries WHERE bucket_id = 6

SELECT _ FROM vault_status;
SELECT _ FROM vault*withdrawals;
SELECT * FROM vault*withdrawal_sources;
SELECT * FROM withdrawal_tags;

DELETE FROM vault_withdrawals
WHERE id = 6 AND bucket_id = 6;

INSERT INTO vault_withdrawals (month_id, bucket_id, tag_id, item_name, total_amount, reason)
VALUES (1, 6, 1, 'Test Item', 4.00, 'Test withdrawal');

SELECT tgname, tgenabled, tgtype
FROM pg_trigger
WHERE tgname = 'trg_vault_withdrawal_manage';

---

okay yesturday we discussed about

vault_entries, vault_withdrawals, vault_withdrawsources,

ledger_enties,monthly_entries right

now today we discuss about

Blue Vault (main purpose was this is a bucket who's responsiblity was to save money in blue vault and if needed we can grab from it and either withdraw completely or partially )
every log was here will logged under box_events

so i have few questions like should we takecare in box-events or ledger_entries for transperancy

i will give the following details of blue Zone you analysis them and give me suggestions

box_events (talbe)
id,bucket_id,month_id,box_type(DEPOSIT,WITHDRAW,PARTIAL_WITHDRAW,FULL_WITHDRAW,MONTH_EXHAUSTED,SEALED),amount,description,event_date
NOTE: PARTIAL_WITHDRAW → month still has balance
FULL_WITHDRAW → that month's balance becomes 0

blue_box_withdrawals (similar to vault_withdrawals)
id,bucket_id,withdrawal_date,total_amount,description.

blue_box_withdrawal_sources (similar to vault_withdrawal_sources)
id,withdrawal_id,source_month_id(monthly_entries.month_id),source_entry_id(monthly_entries.id)

blue_box_state (table)

id,bucket_id,is_sealed,sealed_data,sealed_reason
is_sealed = FALSE → withdrawals allowed
is_sealed = TRUE → bucket permanently closed, withdraws will be closed too
Where the sealing decision comes from ?
blue_box_withdrawal_sources

Theory :

- blue bucket will create in monthly_entries.
- detailed transactions will be mentioned in ledger_entries.
- any withdraws from blue bucket will be logged in blue_box_withdrawals.
- More details about those above transactions will be in blue_box_withdrawal_sources.
- overall summary about complete blue money will be visible in box_events.
- Closure of specific blue bucket and seal it with balance 0 only.

---

1st we create a monthly_entries with blue_bucket under specific month_id (Jan-2026) with allocated (we will allocated when creation) and spent (initiallty it's 0)
2nd thought we have blue_box_events so we can't manually make a record entry in ledger_entries directly, so we have to make an entry 1st in box_events , so then depends on box_type
if DEPOSIT then the amount in box_event will make a legder_entries with tnx_type CONTRIBUTION
if WITHDRAW then here the record in making via blue_box_withdrawals table, which means we only have access to
make DEPOSIT directly into box_events only ,so the total_amount for blue_box_withdrawals will make record entry in
box_event with DEPOSIT as box_type AND also will make a record entry in ledger_entries with that exact amount with DEPOSIT from box_events so here in ledger_entries its tnx_type as SPEND so then monthly_entries consider calculation on SPEND only
so spend will be recalculated (this re-calcualtion is already handled don't worry)

same thing applies to
if SEALED where we follow in WITHDRAWAL here sealed was only upto box_event and blue_box_state (automatically),No ledger_entries needed to record

hope you understand
