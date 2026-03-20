CREATE TABLE
    paychecks (
        month_id SERIAL PRIMARY KEY,
        month_label VARCHAR(20),
        salary DECIMAL(10, 2),
        notes VARCHAR(150)
    )