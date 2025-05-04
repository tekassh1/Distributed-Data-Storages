DROP TABLE IF EXISTS table_one;
CREATE TABLE table_one (
    id SERIAL PRIMARY KEY,
    username TEXT,
    age INT,
    signup_date DATE,
    is_active BOOLEAN
);

INSERT INTO table_one (username, age, signup_date, is_active) VALUES
('alice', 25, CURRENT_DATE - INTERVAL '1 day', true),
('bob', 32, CURRENT_DATE - INTERVAL '5 days', false),
('carol', 29, CURRENT_DATE - INTERVAL '3 days', true),
('dave', 40, CURRENT_DATE - INTERVAL '10 days', true),
('eve', 22, CURRENT_DATE, false);


DROP TABLE IF EXISTS table_two;
CREATE TABLE table_two (
    product_id SERIAL PRIMARY KEY,
    product_name TEXT,
    price NUMERIC(10,2),
    in_stock BOOLEAN,
    added_on TIMESTAMP
);

INSERT INTO table_two (product_name, price, in_stock, added_on) VALUES
('Widget A', 19.99, true, NOW() - INTERVAL '1 hour'),
('Widget B', 29.99, false, NOW() - INTERVAL '3 days'),
('Gadget X', 14.50, true, NOW()),
('Gadget Y', 99.99, true, NOW() - INTERVAL '1 day'),
('Tool Z', 5.00, false, NOW() - INTERVAL '2 days');


DROP TABLE IF EXISTS table_three;
CREATE TABLE table_three (
    order_id SERIAL PRIMARY KEY,
    customer_name TEXT,
    total INT,
    status TEXT,
    created_at TIMESTAMP
);

INSERT INTO table_three (customer_name, total, status, created_at) VALUES
('John Doe', 100, 'pending', NOW()),
('Jane Smith', 200, 'shipped', NOW() - INTERVAL '1 day'),
('Mike Black', 150, 'processing', NOW() - INTERVAL '2 days'),
('Anna White', 250, 'cancelled', NOW() - INTERVAL '5 days'),
('Leo Green', 300, 'completed', NOW() - INTERVAL '3 days');


DROP TABLE IF EXISTS table_four;
CREATE TABLE table_four (
    emp_id SERIAL PRIMARY KEY,
    name TEXT,
    department TEXT,
    salary INT,
    hired_date DATE
);

INSERT INTO table_four (name, department, salary, hired_date) VALUES
('Ivan', 'IT', 1000, CURRENT_DATE - INTERVAL '100 days'),
('Oleg', 'HR', 950, CURRENT_DATE - INTERVAL '200 days'),
('Svetlana', 'Finance', 1200, CURRENT_DATE - INTERVAL '300 days'),
('Nina', 'Marketing', 1100, CURRENT_DATE - INTERVAL '150 days'),
('Pavel', 'Sales', 1050, CURRENT_DATE - INTERVAL '180 days');


DROP TABLE IF EXISTS table_five;
CREATE TABLE table_five (
    session_id SERIAL PRIMARY KEY,
    user_agent TEXT,
    ip_address INET,
    login_time TIMESTAMP,
    success BOOLEAN
);

INSERT INTO table_five (user_agent, ip_address, login_time, success) VALUES
('Mozilla/5.0', '192.168.0.1', NOW(), true),
('Chrome/90.0', '10.0.0.2', NOW() - INTERVAL '1 hour', false),
('Safari/604.1', '172.16.0.3', NOW() - INTERVAL '3 hours', true),
('Edge/91.0', '192.168.1.4', NOW() - INTERVAL '2 hours', false),
('Opera/80.0', '10.1.1.5', NOW() - INTERVAL '30 minutes', true);