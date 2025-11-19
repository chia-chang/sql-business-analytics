# SQL Portfolio: Business Analytics Scenarios

Data: [**Brazilian E-Commerce Public Dataset by Olist**](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce/data) 

## Introduction

This portfolio shows real ad hoc requests a data analyst might get, and answers each with SQL to support decision-making across marketing, operations, and customer service. The aim is to not just run queries, but to think about what the real business need is and deliver useful, actionable answers.

## Scenario 1: Seller Delivery Performance

### Request from Operations

Which sellers have the fastest average delivery time in the last 3 months?

### What do they want to know?

- Who are the fastest sellers?
- What is each seller's average delivery time?

```sql
SELECT 
    s.seller_id, s.seller_city,  s.seller_state,
    COUNT(DISTINCT oi.order_id) AS orders_fulfilled,
    -- Calculate average delivery time (purchase to delivery)
    ROUND(AVG(JULIANDAY(o.order_delivered_customer_date) - 
              JULIANDAY(o.order_purchase_timestamp)), 1) AS avg_delivery_days
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  -- Last 3 months from latest date in dataset
  AND o.order_purchase_timestamp >= DATE((SELECT MAX(order_purchase_timestamp) 
                                          FROM orders), '-90 days')
GROUP BY s.seller_id, s.seller_city, s.seller_state
HAVING orders_fulfilled >= 20 -- Minimum volume for statistical significance
ORDER BY avg_delivery_days ASC -- Fastest first
LIMIT 20;
```
<p align="center">
  <img src="https://github.com/chia-chang/sql-business-analytics/raw/main/outputs/1_Seller_Delivery_Performance.png" width="780"/>
</p>


### Key Findings

- The fastest sellers are consistently delivering in 5 to 6 days on average.
- Most top sellers by speed are in São Paulo (SP), especially São Paulo city.
- High volume doesn't slow everyone down (one seller fulfilled 104 orders at an average of 5.3 days).

### Recommendations

- Investigate what the top sellers do well (how do they handle shipping/logistics?) and share those practices.
- Offer support or coaching to sellers with delivery averages over 6 days.
- Test if new delivery partnerships or better options would help slow sellers outside big cities.

## Scenario 2: Late Delivery Analysis

### Request from Customer Service

We're getting complaints about late deliveries in São Paulo. Is it a real pattern or just a few people being loud?

### What do they want to know?

- Is São Paulo really worse than other places?
- How many customers affected?
- How late are the deliveries?

I've compared São Paulo against other big cities with over 200 orders (using only the last 30 days).

```sql
SELECT 
    c.customer_city,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(CASE 
        WHEN JULIANDAY(o.order_delivered_customer_date) > 
             JULIANDAY(o.order_estimated_delivery_date) 
        THEN 1 ELSE 0 END) as late_orders,
    ROUND(SUM(CASE 
        WHEN JULIANDAY(o.order_delivered_customer_date) > 
             JULIANDAY(o.order_estimated_delivery_date) 
        THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as late_pct,
    ROUND(AVG(CASE 
        WHEN JULIANDAY(o.order_delivered_customer_date) > 
             JULIANDAY(o.order_estimated_delivery_date)
        THEN JULIANDAY(o.order_delivered_customer_date) - 
             JULIANDAY(o.order_estimated_delivery_date)
        ELSE 0 END), 1) as avg_days_late_when_late
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  -- Last 30 days
  AND o.order_delivered_customer_date >= DATE('2018-08-01', '-30 days')
GROUP BY c.customer_city
-- Other major cities with total orders over 200
HAVING total_orders>200
ORDER BY late_pct DESC;
```
<p align="center">
  <img src="https://github.com/chia-chang/sql-business-analytics/raw/main/outputs/2_Late_Delivery_Analysis.png" width="715"/>
</p>

### Key Findings

- São Paulo had a late delivery rate of 12.2%, which is much higher than Rio de Janeiro (7.4%) and most other large cities (below 5%).
- Over 300 customers were impacted in the last month.
- The average delay was about half a day, but São Paulo saw late orders much more often.

### Recommendations

- Review operations in São Paulo to fix whatever is causing more frequent delays.
- Keep tracking late deliveries in all cities to spot new issues early.

## Scenario 3: Top High-Value Customers

### Request from Marketing

Who spent the most money in Q1 2018? What do these top customers have in common?

### What do they want to know?

- Who are the top 10 spenders?
- Where are they from?

```sql
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
    ROUND(total_spend/num_orders, 2) AS avg_order_value
FROM q1_customer_spending
ORDER BY total_spend DESC
LIMIT 10;
```
<p align="center">
  <img src="https://github.com/chia-chang/sql-business-analytics/raw/main/outputs/3_Top_High-Value_Customers.png" width="888"/>
</p>

### Key Findings

- All ten top spenders in Q1 2018 made just one purchase each, ranging from $2204 to $4175.
- These big spenders are spread out—no one city or region dominates.

### Recommendations

- Reach out to these high-spenders with tailored offers and ask for their feedback and try to turn them into repeat buyers.
- Understand what they bought to find bundles or products that attract high-value shoppers and use that for future promotions and campaigns.

## Scenario 4: City Sales Rankings

### Request from Regional Sales

Which cities brought in the most sales in 2017?

```sql
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
```
<p align="center">
  <img src="https://github.com/chia-chang/sql-business-analytics/raw/main/outputs/4_City_Sales_Rankings.png" width="395"/>
</p>

### Key Findings

- São Paulo (SP) is the top city by total revenue in 2017, with over $850K in sales, followed by Rio de Janeiro (RJ) at over $540K.
- The top five cities accounted for a big share of all sales, confirming that big urban areas lead in e-commerce.

### Recommendations

- Focus marketing on these top cities to make the most of where demand is already high.
- Study what's working in these places and try to apply those lessons in other growing cities.

## Scenario 5: Discount Campaign Impact

### Request from Marketing

We ran a discount campaign on electronics July 15-21. Did it work?

### What do they want to know?

- Did revenue and orders increase during the campaign?
- Did things slow down after?

### Breaking it down:

- Compared campaign week to the week before and after.
- Looked at those three periods for sales and pricing.

```sql
WITH campaign_data AS (
    SELECT 
        o.order_id, o.order_purchase_timestamp,
        oi.order_item_id, oi.price,
        p.product_category_name,
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
    COUNT(DISTINCT order_id) as num_orders,
    COUNT(order_item_id) as items_sold,
    ROUND(SUM(price), 2) as gross_revenue,
    ROUND(AVG(price), 2) as avg_item_price,
    ROUND(SUM(price) / COUNT(DISTINCT order_id), 2) as avg_order_value
FROM campaign_data
WHERE period IS NOT NULL
GROUP BY period
ORDER BY 
    CASE period
        WHEN 'Pre-campaign' THEN 1
        WHEN 'Campaign week' THEN 2
        WHEN 'Post-campaign' THEN 3
    END;
```


### Key Findings

- Orders jumped from 86 to 130 during the campaign, and even hit 144 after the campaign ended.
- Revenue more than doubled—going from $8.6K to $20.9K post-campaign.
- Discounts lowered the average item price, but revenue and order counts still went up.

### Recommendations

- Try similar short-term discount campaigns as they're effective for boosting both orders and revenue.
- Investigate why post-campaign revenue spiked—maybe the campaign built momentum?

## Summary

The scenarios demonstrate practical ways to turn data into value for different teams—whether identifying fast sellers, finding top customers, or measuring campaign impact.

When deciding how much data to pull or how detailed to make my analysis, I try to keep the big picture in mind, not just the specific question that's asked. In this project, I have given examples with some scenarios where I keep it simple, and some scenarios I expanded the question and gave more information.

### Here's how I decide what to give:

- **Deadline**: If the results are needed quickly, I stick to the basics so I can deliver fast.
- **What does the stakeholder like?** Some people just want a quick answer and are done, but others like to dig deeper and might ask for extra details later. If I think there will be follow-up questions, I include a bit more context even if it's not asked for yet.
- **Recurring requests**: If I feel like it might come up again, I'll check if the team wants a repeatable report or dashboard, so we're set for the future.
- **Looking at the bigger picture**: I want my work to help the whole team, not just solve one small problem. So I try to spot patterns, think about how my work fits into our process, and make things smoother for everyone.

I do my best to balance giving enough information to help others make good decisions, without overwhelming them or wasting time. If I'm not sure how much detail is needed, I check with the stakeholder and try to offer options. My goal isn't just to answer a question, but to make things easier, smarter, and more connected for our team.
