-- ============================================================
-- Sales & Inventory Management Database (MySQL 8.0+)
-- ============================================================
DROP DATABASE IF EXISTS sales_inventory;
CREATE DATABASE sales_inventory CHARACTER SET utf8mb4;
USE sales_inventory;

-- ------------------------------------------------------------
-- 1. SCHEMA
-- ------------------------------------------------------------
CREATE TABLE categories (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE suppliers (
    supplier_id   INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    phone         VARCHAR(20),
    city          VARCHAR(50)
);

CREATE TABLE products (
    product_id    INT AUTO_INCREMENT PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    category_id   INT NOT NULL,
    supplier_id   INT NOT NULL,
    unit_cost     DECIMAL(10,2) NOT NULL CHECK (unit_cost >= 0),
    unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE inventory (
    product_id     INT PRIMARY KEY,
    quantity       INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    reorder_level  INT NOT NULL DEFAULT 10,
    last_updated   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(100) UNIQUE,
    city        VARCHAR(50)
);

CREATE TABLE sales (
    sale_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    sale_date   DATE NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE sale_items (
    sale_id    INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,   -- price at time of sale
    PRIMARY KEY (sale_id, product_id),
    FOREIGN KEY (sale_id)    REFERENCES sales(sale_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_products_category ON products(category_id);

-- ------------------------------------------------------------
-- 2. SAMPLE DATA
-- ------------------------------------------------------------
INSERT INTO categories (category_name) VALUES
 ('Electronics'), ('Office Supplies'), ('Furniture'), ('Accessories');

INSERT INTO suppliers (supplier_name, phone, city) VALUES
 ('TechSource Ltd', '0100000001', 'Cairo'),
 ('OfficePro',      '0100000002', 'Alexandria'),
 ('HomeWorks',      '0100000003', 'Giza');

INSERT INTO products (product_name, category_id, supplier_id, unit_cost, unit_price) VALUES
 ('Laptop 15"',        1, 1, 600.00, 850.00),
 ('Wireless Mouse',    4, 1,   8.00,  18.00),
 ('Mechanical Keyboard',4,1,  35.00,  70.00),
 ('A4 Paper Ream',     2, 2,   3.00,   5.50),
 ('Ballpoint Pens (50)',2, 2,   4.00,   9.00),
 ('Office Chair',      3, 3,  70.00, 140.00),
 ('Standing Desk',     3, 3, 180.00, 320.00),
 ('USB-C Hub',         4, 1,  12.00,  29.00);

INSERT INTO inventory (product_id, quantity, reorder_level) VALUES
 (1, 15, 5), (2, 120, 30), (3, 8, 10), (4, 400, 100),
 (5, 60, 50), (6, 4, 6),  (7, 10, 3), (8, 25, 20);

INSERT INTO customers (full_name, email, city) VALUES
 ('Ahmed Hassan', 'ahmed@example.com', 'Cairo'),
 ('Sara Ali',     'sara@example.com',  'Giza'),
 ('Omar Khaled',  'omar@example.com',  'Alexandria'),
 ('Mona Samir',   'mona@example.com',  'Cairo');

INSERT INTO sales (customer_id, sale_date) VALUES
 (1, '2026-09-05'), (2, '2026-09-18'), (3, '2026-10-02'),
 (1, '2026-10-15'), (4, '2026-10-28'), (2, '2026-11-03');

INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES
 (1, 1, 1, 850.00), (1, 2, 2, 18.00),
 (2, 6, 2, 140.00), (2, 4, 10, 5.50),
 (3, 7, 1, 320.00), (3, 8, 3, 29.00),
 (4, 3, 2, 70.00),  (4, 2, 1, 18.00),
 (5, 1, 2, 850.00), (5, 5, 5, 9.00),
 (6, 6, 1, 140.00), (6, 8, 2, 29.00);

-- ------------------------------------------------------------
-- 3. BUSINESS-INSIGHT QUERIES
-- ------------------------------------------------------------

-- Q1. JOIN: full sales detail (line-level)
SELECT s.sale_id, s.sale_date, c.full_name, p.product_name,
       si.quantity, si.unit_price, si.quantity * si.unit_price AS line_total
FROM sales s
JOIN customers  c  ON c.customer_id = s.customer_id
JOIN sale_items si ON si.sale_id    = s.sale_id
JOIN products   p  ON p.product_id  = si.product_id
ORDER BY s.sale_date, s.sale_id;

-- Q2. Aggregation: monthly revenue, orders and average order value
SELECT DATE_FORMAT(s.sale_date, '%Y-%m') AS month,
       COUNT(DISTINCT s.sale_id)          AS orders,
       SUM(si.quantity * si.unit_price)   AS revenue,
       ROUND(SUM(si.quantity * si.unit_price) / COUNT(DISTINCT s.sale_id), 2) AS avg_order_value
FROM sales s
JOIN sale_items si ON si.sale_id = s.sale_id
GROUP BY month
ORDER BY month;

-- Q3. Top 5 products by revenue and profit
SELECT p.product_name,
       SUM(si.quantity)                                   AS units_sold,
       SUM(si.quantity * si.unit_price)                   AS revenue,
       SUM(si.quantity * (si.unit_price - p.unit_cost))   AS profit
FROM sale_items si
JOIN products p ON p.product_id = si.product_id
GROUP BY p.product_id, p.product_name
ORDER BY revenue DESC
LIMIT 5;

-- Q4. Revenue and profit margin by category
SELECT cat.category_name,
       SUM(si.quantity * si.unit_price) AS revenue,
       ROUND(100 * SUM(si.quantity * (si.unit_price - p.unit_cost))
                 / SUM(si.quantity * si.unit_price), 1) AS margin_pct
FROM sale_items si
JOIN products   p   ON p.product_id   = si.product_id
JOIN categories cat ON cat.category_id = p.category_id
GROUP BY cat.category_id, cat.category_name
ORDER BY revenue DESC;

-- Q5. Filtering + HAVING: customers who spent more than 500
SELECT c.full_name, c.city, SUM(si.quantity * si.unit_price) AS total_spent
FROM customers c
JOIN sales s       ON s.customer_id = c.customer_id
JOIN sale_items si ON si.sale_id    = s.sale_id
GROUP BY c.customer_id, c.full_name, c.city
HAVING total_spent > 500
ORDER BY total_spent DESC;

-- Q6. Low-stock alert: products at or below reorder level, with supplier
SELECT p.product_name, i.quantity, i.reorder_level, sup.supplier_name, sup.phone
FROM inventory i
JOIN products  p   ON p.product_id   = i.product_id
JOIN suppliers sup ON sup.supplier_id = p.supplier_id
WHERE i.quantity <= i.reorder_level
ORDER BY i.quantity - i.reorder_level;

-- Q7. LEFT JOIN: products that never sold
SELECT p.product_id, p.product_name
FROM products p
LEFT JOIN sale_items si ON si.product_id = p.product_id
WHERE si.product_id IS NULL;

-- Q8. Subquery: products priced above the average price
SELECT product_name, unit_price
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products)
ORDER BY unit_price DESC;

-- Q9. Window function: running revenue total by date
SELECT sale_date, daily_revenue,
       SUM(daily_revenue) OVER (ORDER BY sale_date) AS running_total
FROM (
    SELECT s.sale_date, SUM(si.quantity * si.unit_price) AS daily_revenue
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.sale_id
    GROUP BY s.sale_date
) d;

-- Q10. Window function: rank products within each category by units sold
SELECT category_name, product_name, units_sold,
       RANK() OVER (PARTITION BY category_name ORDER BY units_sold DESC) AS rank_in_category
FROM (
    SELECT cat.category_name, p.product_name, COALESCE(SUM(si.quantity), 0) AS units_sold
    FROM products p
    JOIN categories cat ON cat.category_id = p.category_id
    LEFT JOIN sale_items si ON si.product_id = p.product_id
    GROUP BY cat.category_name, p.product_id, p.product_name
) t;

-- ------------------------------------------------------------
-- 4. DATA MANIPULATION: keep inventory in sync with sales
-- ------------------------------------------------------------
DELIMITER //
CREATE TRIGGER trg_reduce_stock
AFTER INSERT ON sale_items
FOR EACH ROW
BEGIN
    UPDATE inventory
    SET quantity = quantity - NEW.quantity
    WHERE product_id = NEW.product_id;
END//
DELIMITER ;

-- Restock procedure
DELIMITER //
CREATE PROCEDURE restock_product(IN p_id INT, IN qty INT)
BEGIN
    UPDATE inventory SET quantity = quantity + qty WHERE product_id = p_id;
END//
DELIMITER ;

-- Example usage:
-- INSERT INTO sales (customer_id, sale_date) VALUES (3, CURDATE());
-- INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES (LAST_INSERT_ID(), 2, 5, 18.00);
-- CALL restock_product(6, 20);
-- UPDATE products SET unit_price = unit_price * 1.05 WHERE category_id = 4;   -- 5% price rise
-- DELETE FROM inventory WHERE quantity = 0 AND product_id NOT IN (SELECT product_id FROM sale_items);

-- Reporting view
CREATE VIEW v_product_performance AS
SELECT p.product_id, p.product_name,
       COALESCE(SUM(si.quantity), 0) AS units_sold,
       COALESCE(SUM(si.quantity * si.unit_price), 0) AS revenue,
       i.quantity AS in_stock
FROM products p
LEFT JOIN sale_items si ON si.product_id = p.product_id
JOIN inventory i ON i.product_id = p.product_id
GROUP BY p.product_id, p.product_name, i.quantity;
