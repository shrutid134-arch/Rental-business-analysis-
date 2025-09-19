-- ==============================================
-- 1. KPI DEVELOPMENT QUERIES
-- ==============================================

-- Total Revenue of business
-- Calculates overall revenue, total transactions, and average transaction value
DROP TABLE IF EXISTS kpi_total_revenue;
CREATE TABLE kpi_total_revenue AS
SELECT 
    'Total Revenue (All time)' AS metric, 
    SUM(amount) AS total_amount,
    COUNT(*) AS total_transactions,
    AVG(amount) AS avg_transaction_value
FROM payment;

-- Revenue by Store
-- Aggregates revenue, transactions, and average payment per store
DROP TABLE IF EXISTS kpi_revenue_by_store;
CREATE TABLE kpi_revenue_by_store AS
SELECT 
    s.store_id,
    SUM(p.amount) AS store_revenue,
    COUNT(p.payment_id) AS total_transactions,
    AVG(p.amount) AS avg_payment_per_store
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN store s ON i.store_id = s.store_id
GROUP BY s.store_id
ORDER BY store_revenue DESC;

-- Revenue by Film Category
-- Shows revenue per film category and its contribution to total revenue
DROP TABLE IF EXISTS kpi_revenue_by_category;
CREATE TABLE kpi_revenue_by_category AS
SELECT 
    c.name AS category,
    SUM(p.amount) AS category_revenue,
    COUNT(r.rental_id) AS total_rentals,
    AVG(p.amount) AS avg_payment_per_rental,
    ROUND((SUM(p.amount) * 100.0 / (SELECT SUM(amount) FROM payment)), 2) AS revenue_percentage
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
GROUP BY c.name
ORDER BY category_revenue DESC;

-- Average Rental Duration
-- Calculates average rental duration in hours and days, and average payment per rental
DROP TABLE IF EXISTS kpi_rental_stats;
CREATE TABLE kpi_rental_stats AS
SELECT 
    AVG(EXTRACT(EPOCH FROM (r.return_date - r.rental_date))/3600) AS avg_rental_hours,
    AVG(EXTRACT(EPOCH FROM (r.return_date - r.rental_date))/86400) AS avg_rental_days,
    AVG(p.amount) AS avg_payment_per_rental
FROM rental r
JOIN payment p ON r.rental_id = p.rental_id
WHERE r.return_date IS NOT NULL;

-- ==============================================
-- 2. ADVANCED SQL ANALYTICS
-- ==============================================

-- 1) Monthly Revenue with 2-Month Moving Average
-- Shows revenue trends and smoothing using a 2-month moving average
DROP TABLE IF EXISTS adv_monthly_revenue;
CREATE TABLE adv_monthly_revenue AS
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', payment_date) AS month,
        SUM(amount) AS monthly_total
    FROM payment
    GROUP BY DATE_TRUNC('month', payment_date)
    ORDER BY month
)
SELECT 
    TO_CHAR(month, 'YYYY-MM') AS month_name,
    monthly_total,
    ROUND(AVG(monthly_total) OVER (
        ORDER BY month 
        ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
    ),2) AS two_month_moving_avg
FROM monthly_revenue;

-- 2) Top 10 Customers by Spend
-- Identifies highest-spending customers with total rentals
DROP TABLE IF EXISTS adv_top_customers;
CREATE TABLE adv_top_customers AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    SUM(p.amount) AS total_spend,
    COUNT(r.rental_id) AS total_rentals,
    RANK() OVER (ORDER BY SUM(p.amount) DESC) AS spend_rank
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY c.customer_id, customer_name
ORDER BY total_spend DESC
LIMIT 10;

-- 3) Customer Segmentation (VIP / Regular / Low using NTILE)
-- Splits customers into 3 tiers based on total spend
DROP TABLE IF EXISTS adv_customer_segments;
CREATE TABLE adv_customer_segments AS
WITH customer_spending AS (
    SELECT 
        c.customer_id,
        SUM(p.amount) AS total_spent
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
)
SELECT 
    customer_id,
    total_spent,
    CASE 
        WHEN NTILE(3) OVER (ORDER BY total_spent DESC) = 1 THEN 'VIP'
        WHEN NTILE(3) OVER (ORDER BY total_spent DESC) = 2 THEN 'Regular'
        ELSE 'Low'
    END AS customer_tier
FROM customer_spending
ORDER BY total_spent DESC;

-- ==============================================
-- 3. SEGMENTATION & TARGETING
-- ==============================================

-- Film Segmentation based on Revenue and Popularity
-- Categorizes films into Blockbuster, Hit, and Regular based on revenue & rentals
DROP TABLE IF EXISTS film_segmentation;
CREATE TABLE film_segmentation AS
SELECT 
    f.film_id,
    f.title,
    COUNT(r.rental_id) AS total_rentals,
    SUM(p.amount) AS total_revenue,
    AVG(p.amount) AS avg_payment_per_rental,
    CASE 
        WHEN SUM(p.amount) > 5000 AND COUNT(r.rental_id) > 100 THEN 'Blockbuster'
        WHEN SUM(p.amount) > 3000 THEN 'Hit'
        ELSE 'Regular'
    END AS film_segment
FROM film f
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY f.film_id, f.title
ORDER BY total_revenue DESC;

-- Compare Store Performance
-- Summarizes store performance including revenue per customer and rentals per customer
DROP TABLE IF EXISTS store_performance;
CREATE TABLE store_performance AS
SELECT 
    s.store_id,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(r.rental_id) AS total_rentals,
    SUM(p.amount) AS total_revenue,
    AVG(p.amount) AS avg_payment,
    ROUND(SUM(p.amount)/COUNT(DISTINCT c.customer_id),2) AS revenue_per_customer,
    ROUND(COUNT(r.rental_id)/COUNT(DISTINCT c.customer_id),2) AS rentals_per_customer
FROM store s
JOIN inventory i ON s.store_id = i.store_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
JOIN customer c ON r.customer_id = c.customer_id
GROUP BY s.store_id
ORDER BY total_revenue DESC;

-- Customer Segmentation by Total Spend
-- Classifies customers as High, Medium, Low spend based on total amount spent
DROP TABLE IF EXISTS customer_segmentation;
CREATE TABLE customer_segmentation AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    SUM(p.amount) AS total_spend,
    COUNT(r.rental_id) AS rental_count,
    CASE
        WHEN SUM(p.amount) > 1000 THEN 'High'
        WHEN SUM(p.amount) > 500 THEN 'Medium'
        ELSE 'Low'
    END AS spend_segment
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spend DESC;

-- ==============================================
-- 4. PERFORMANCE ANALYSIS
-- ==============================================

-- Pareto Analysis: Top 20% Films Generating 80% Revenue
-- Identifies films contributing most revenue vs long tail
DROP TABLE IF EXISTS pareto_analysis;
CREATE TABLE pareto_analysis AS
SELECT 
    film_id,
    title,
    film_revenue,
    total_rentals,
    CASE 
        WHEN cumulative_revenue <= total_revenue*0.8 THEN 'Top 80% Revenue'
        ELSE 'Long Tail'
    END AS pareto_category
FROM (
    SELECT 
        f.film_id,
        f.title,
        SUM(p.amount) AS film_revenue,
        COUNT(r.rental_id) AS total_rentals,
        SUM(SUM(p.amount)) OVER (ORDER BY SUM(p.amount) DESC) AS cumulative_revenue,
        SUM(SUM(p.amount)) OVER () AS total_revenue
    FROM film f
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY f.film_id, f.title
) sub
ORDER BY film_revenue DESC;


