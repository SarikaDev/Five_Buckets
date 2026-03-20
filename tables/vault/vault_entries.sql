CREATE TABLE vault_entries (
	   id SERIAL PRIMARY KEY,|
	     month_id INTEGER NOT NULL,
		        bucket_id INTEGER NOT NULL,
total_drip DECIMAL(10, 2),
drip_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,


        CONSTRAINT check_total_drip_positive CHECK (total_drip >= 0),

	-- Fk constraints
	 CONSTRAINT fk_monthly_id FOREIGN KEY (month_id) REFERENCES paychecks (month_id) ON DELETE RESTRICT ON UPDATE CASCADE,
        CONSTRAINT fk_bucket_id FOREIGN KEY (bucket_id) REFERENCES bucket_configs (bucket_id) ON DELETE RESTRICT ON UPDATE CASCADE
)


-- Trigger Fn to takecare of only Yellow bucket DRIP_IN
CREATE OR REPLACE FUNCTION check_vault_bucket_type()
RETURNS TRIGGER AS $$
DECLARE
    v_bucket_type VARCHAR(20);
    v_vault_role VARCHAR(50);
    v_bucket_name VARCHAR(20);
BEGIN
    -- Get full bucket details
    SELECT 
        bt.type_name, 
        bt.vault_role,
        bc.bucket_name
    INTO v_bucket_type, v_vault_role, v_bucket_name
    FROM bucket_configs bc
    JOIN bucket_types bt ON bc.display_type = bt.type_name
    WHERE bc.bucket_id = NEW.bucket_id;
    
    -- Validate
    IF v_bucket_type IS NULL THEN
        RAISE EXCEPTION 'Bucket ID % does not exist', NEW.bucket_id;
    END IF;
    
    IF v_bucket_type != 'YELLOW' THEN
        RAISE EXCEPTION 'Invalid bucket type for vault_entries. Bucket "%" (ID: %) is % type. Only YELLOW buckets allowed.',
            v_bucket_name, NEW.bucket_id, v_bucket_type;
    END IF;
    
    IF v_vault_role != 'DRIP_IN' THEN
        RAISE EXCEPTION 'Invalid vault role for bucket "%" (ID: %). Expected DRIP_IN, got %',
            v_bucket_name, NEW.bucket_id, v_vault_role;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_check_vault_bucket_type
    BEFORE INSERT OR UPDATE OF bucket_id ON vault_entries
    FOR EACH ROW
    EXECUTE FUNCTION check_vault_bucket_type();

-- Also keep your existing foreign key for referential integrity
-- (it will work alongside the trigger)
--------------------------------------------------------------
--- total_drip Rule

CREATE OR REPLACE FUNCTION validate_vault_remaining_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_remaining_bal DECIMAL(10, 2);
    v_bucket_name VARCHAR(20);
BEGIN
    -- Get bucket name for error message
    SELECT bucket_name INTO v_bucket_name
    FROM bucket_configs 
    WHERE bucket_id = NEW.bucket_id;
    
    -- Calculate remaining balance
    SELECT (allocated - spent) INTO v_remaining_bal
    FROM monthly_entries
    WHERE month_id = NEW.month_id 
    AND bucket_id = NEW.bucket_id;
    
    IF v_remaining_bal IS NULL THEN
        RAISE EXCEPTION 'No monthly entry found for month_id % and bucket_id %', 
            NEW.month_id, NEW.bucket_id;
    END IF;
    
    IF NEW.total_drip > v_remaining_bal THEN
        RAISE EXCEPTION 'Insufficient balance for bucket "%". Available: %, Requested: %',
            v_bucket_name, v_remaining_bal, NEW.total_drip;
    END IF;
    
   
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER trigger_validate_vault_remaining_balance
    BEFORE INSERT OR UPDATE OF total_drip, month_id, bucket_id ON vault_entries
    FOR EACH ROW
    EXECUTE FUNCTION validate_vault_remaining_balance();

