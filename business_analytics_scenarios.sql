-- SQL Portfolio: Business Analytics Scenarios
-- Data: Brazilian E-Commerce Public Dataset by Olist
----------------------------------------------------------
-- Scenario 1:  Who are our fastest sellers in the last 3 months?
SELECT 
    s.seller_id,  s.seller_city, s.seller_state,
    COUNT(DISTINCT oi.order_id) AS orders_fulfilled,  -- how many orders each seller fulfilled
    ROUND(AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp)), 1) AS avg_delivery_days   -- average days from purchase to delivery
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  -- Only look at the most recent 3 months (from latest order date)
  AND o.order_purchase_timestamp >= DATE((SELECT MAX(order_purchase_timestamp) FROM orders), '-90 days')
GROUP BY s.seller_id, s.seller_city, s.seller_state
HAVING orders_fulfilled >= 20  -- make sure each seller has enough orders for it to be fair
ORDER BY avg_delivery_days ASC
LIMIT 20;
----------------------------------------------------------
-- Scenario 2: Are late deliveries in São Paulo a real problem?
SELECT 
    c.customer_city,
    COUNT(DISTINCT o.order_id) as total_orders,     -- total delivered orders in each city
    SUM(CASE WHEN JULIANDAY(o.order_delivered_customer_date) > JULIANDAY(o.order_estimated_delivery_date) THEN 1 ELSE 0 END) as late_orders,   -- count only if delivered late
	-- what percent are late
    ROUND(SUM(CASE WHEN JULIANDAY(o.order_delivered_customer_date) > JULIANDAY(o.order_estimated_delivery_date) THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as late_pct, 
    ROUND(AVG(CASE WHEN JULIANDAY(o.order_delivered_customer_date) > JULIANDAY(o.order_estimated_delivery_date)
        THEN JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date)
        ELSE 0 END), 1) as avg_days_late_when_late     -- when it is late, how late is it on average
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  -- Only look at the most recent 30 days
  AND o.order_delivered_customer_date >= DATE('2018-08-01', '-30 days')
GROUP BY c.customer_city
HAVING total_orders>200      -- only include big cities for fair comparison
ORDER BY late_pct DESC;
----------------------------------------------------------
-- Scenario 3: Who spent the most in Q1 2018, and where are they from?
WITH q1_customer_spending AS (
    SELECT 
        c.customer_unique_id, c.customer_city, c.customer_state,
        COUNT(DISTINCT o.order_id) AS num_orders,
        SUM(p.payment_value) AS total_spend
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2018-01-01'
      AND o.order_purchase_timestamp < '2018-04-01'
    GROUP BY c.customer_unique_id, c.customer_city, c.customer_state
)
SELECT 
    customer_unique_id, customer_city, customer_state, num_orders,
    ROUND(total_spend, 2) AS total_spend,
    ROUND(total_spend/num_orders, 2) AS avg_order_value    -- will match total_spend if  just 1 order
FROM q1_customer_spending
ORDER BY total_spend DESC
LIMIT 10;
------------------------------------------------------------
-- Scenario 4: Which cities had the most sales in 2017?
SELECT 
    c.customer_city, c.customer_state,
    ROUND(SUM(p.payment_value), 2) AS total_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
  AND strftime('%Y', o.order_purchase_timestamp) = '2017'
GROUP BY c.customer_city, c.customer_state
ORDER BY total_revenue DESC
LIMIT 5;
------------------------------------------------------------
-- Scenario 5: Did our electronics discount campaign work?
WITH campaign_data AS (
    SELECT 
        o.order_id, o.order_purchase_timestamp, oi.order_item_id, oi.price, p.product_category_name,
        CASE 
            WHEN DATE(o.order_purchase_timestamp) 
                BETWEEN '2018-07-08' AND '2018-07-14' THEN 'Pre-campaign'
            WHEN DATE(o.order_purchase_timestamp) 
                BETWEEN '2018-07-15' AND '2018-07-21' THEN 'Campaign week'
            WHEN DATE(o.order_purchase_timestamp) 
                BETWEEN '2018-07-22' AND '2018-07-28' THEN 'Post-campaign'
        END as period
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name 
          IN ('eletronicos', 'informatica_acessorios', 'pcs', 'tablets_impressao_imagem')
      AND DATE(o.order_purchase_timestamp) BETWEEN '2018-07-08' AND '2018-07-28'
)
SELECT 
    period,
    COUNT(DISTINCT order_id) as num_orders,         -- how many unique orders each week
    COUNT(order_item_id) as items_sold,             -- total items sold each week
    ROUND(SUM(price), 2) as gross_revenue,          -- total sales revenue
    ROUND(AVG(price), 2) as avg_item_price,         -- average price per individual item
    ROUND(SUM(price) / COUNT(DISTINCT order_id), 2) as avg_order_value    -- typical order size
FROM campaign_data
WHERE period IS NOT NULL
GROUP BY period
ORDER BY 
    CASE period
        WHEN 'Pre-campaign' THEN 1
        WHEN 'Campaign week' THEN 2
        WHEN 'Post-campaign' THEN 3
    END;
