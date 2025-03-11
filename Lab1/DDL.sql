-- 1. Создание таблицы users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    age INT CHECK (age >= 18),
    registration_date TIMESTAMP DEFAULT NOW()
);

-- 2. Создание таблицы orders
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    total_price DECIMAL(10,2) CHECK (total_price >= 0),
    status VARCHAR(20) CHECK (status IN ('pending', 'completed', 'canceled')),
    order_date TIMESTAMP DEFAULT NOW()
);

-- 3. Создание таблицы products
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) CHECK (price >= 0),
    category VARCHAR(50) NOT NULL,
    stock_quantity INT CHECK (stock_quantity >= 0)
);

-- Вставка данных в таблицу users
INSERT INTO users (name, email, age, registration_date) VALUES
('Алексей Иванов', 'alexey@example.com', 25, '2024-01-10'),
('Мария Смирнова', 'maria@example.com', 30, '2023-12-05'),
('Иван Петров', 'ivan@example.com', 40, '2022-06-20'),
('Ольга Сидорова', 'olga@example.com', 35, '2023-08-15'),
('Дмитрий Кузнецов', 'dmitry@example.com', 28, '2023-09-12'),
('Анна Васильева', 'anna@example.com', 27, '2024-02-18'),
('Павел Морозов', 'pavel@example.com', 45, '2022-03-30'),
('Екатерина Орлова', 'ekaterina@example.com', 33, '2023-07-25'),
('Сергей Федоров', 'sergey@example.com', 38, '2021-11-10'),
('Наталья Белова', 'natalya@example.com', 29, '2024-01-22'),
('Виктор Николаев', 'victor@example.com', 31, '2023-06-11'),
('Елена Павлова', 'elena@example.com', 26, '2024-01-30'),
('Артур Волков', 'artur@example.com', 42, '2022-04-15'),
('Татьяна Киселева', 'tatyana@example.com', 36, '2023-05-05'),
('Игорь Жуков', 'igor@example.com', 39, '2021-09-07'),
('София Михайлова', 'sofia@example.com', 22, '2024-02-01'),
('Максим Захаров', 'maxim@example.com', 44, '2020-12-20'),
('Юлия Тихонова', 'yulia@example.com', 37, '2023-03-14'),
('Артем Егоров', 'artem@example.com', 34, '2023-09-08'),
('Людмила Королева', 'lyudmila@example.com', 41, '2021-07-27');

-- Вставка данных в таблицу orders
INSERT INTO orders (user_id, total_price, status, order_date) VALUES
(1, 1500.50, 'completed', '2024-02-01'),
(2, 2500.00, 'pending', '2024-02-02'),
(3, 700.75, 'canceled', '2024-02-03'),
(4, 3200.90, 'completed', '2024-02-04'),
(5, 1800.30, 'pending', '2024-02-05'),
(6, 4500.00, 'completed', '2024-02-06'),
(7, 2999.99, 'completed', '2024-02-07'),
(8, 500.20, 'pending', '2024-02-08'),
(9, 1200.60, 'canceled', '2024-02-09'),
(10, 3300.15, 'completed', '2024-02-10'),
(11, 4000.00, 'completed', '2024-02-11'),
(12, 2900.75, 'pending', '2024-02-12'),
(13, 750.50, 'canceled', '2024-02-13'),
(14, 5100.45, 'completed', '2024-02-14'),
(15, 1800.99, 'pending', '2024-02-15'),
(16, 2300.40, 'completed', '2024-02-16'),
(17, 3100.80, 'completed', '2024-02-17'),
(18, 900.60, 'canceled', '2024-02-18'),
(19, 2750.30, 'completed', '2024-02-19'),
(20, 2600.50, 'pending', '2024-02-20');

-- Вставка данных в таблицу products
INSERT INTO products (name, price, category, stock_quantity) VALUES
('Ноутбук HP', 55000.00, 'Электроника', 10),
('Смартфон Samsung', 32000.00, 'Электроника', 15),
('Телевизор LG', 45000.00, 'Бытовая техника', 7),
('Кофеварка Bosch', 12000.00, 'Кухонная техника', 20),
('Холодильник Samsung', 80000.00, 'Бытовая техника', 5),
('Микроволновка Panasonic', 9000.00, 'Кухонная техника', 12),
('Чайник Tefal', 3500.00, 'Кухонная техника', 25),
('Пылесос Dyson', 42000.00, 'Бытовая техника', 8),
('Монитор ASUS', 27000.00, 'Компьютеры', 10),
('Клавиатура Logitech', 4500.00, 'Компьютеры', 30),
('Мышь Razer', 6000.00, 'Компьютеры', 22),
('Флешка Kingston 64GB', 1500.00, 'Аксессуары', 40),
('Наушники Sony', 7500.00, 'Аудио', 18),
('Гарнитура HyperX', 8500.00, 'Аудио', 14),
('Фитнес-браслет Xiaomi', 3000.00, 'Гаджеты', 25),
('Видеокарта NVIDIA RTX 3060', 65000.00, 'Компьютеры', 6),
('Процессор Intel i7', 38000.00, 'Компьютеры', 5),
('ОЗУ Kingston 16GB', 12000.00, 'Компьютеры', 12),
('SSD Samsung 1TB', 14000.00, 'Компьютеры', 10),
('МФУ Canon', 18000.00, 'Офисная техника', 7);
