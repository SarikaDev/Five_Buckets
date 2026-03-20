CREATE TABLE
    bucket_configs (
        bucket_id SERIAL PRIMARY KEY,
        bucket_name VARCHAR(20),
        display_type VARCHAR(20),
        display_order int,
        is_active boolean,
        notes VARCHAR(150)
    )
    -- Add-On's
    --  ALTER TABLE bucket_configs 
    --     ADD CONSTRAINT fk_bucket_configs_bucket_display_type
    --     FOREIGN KEY (display_type)
    --     REFERENCES bucket_types (type_name) 
    --     ON DELETE RESTRICT -- Prevents deleting bucket_types if referenced in bucket_configs
    --     ON UPDATE CASCADE;-- Updates display_type in bucket_configs if type_name changes in bucket_types