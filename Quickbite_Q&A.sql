-- . Check all tables-- 
show tables;


-- . Check table structure
desc restaurant;
desc customer;
desc delivery_partner;
desc delivery_performance;
desc menu_items;
desc order_items;
desc orders;
desc rating;

-- . Check total number of records

SELECT COUNT(*) FROM customer;
SELECT COUNT(*) FROM delivery_partner;
SELECT COUNT(*) FROM delivery_performance;
SELECT COUNT(*) FROM menu_items;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM rating;
SELECT COUNT(*) FROM restaurant;

-- . View sample data
SELECT * FROM customer limit 100;
SELECT * FROM delivery_partner limit 100;
SELECT * FROM delivery_performance limit 100;
SELECT * FROM menu_items limit 100;
SELECT * FROM order_items limit 100;
SELECT * FROM orders limit 100;
SELECT * FROM rating limit 100;
SELECT * FROM restaurant limit 100;

-- 5. Check NULL values

SELECT * FROM restaurant
WHERE restaurant_id IS NULL;

SELECT * FROM customer
WHERE customer_id IS NULL;

SELECT * FROM delivery_partner
WHERE delivery_partner_id IS NULL;

SELECT * FROM delivery_performance
WHERE order_id IS NULL;

SELECT * FROM menu_items
WHERE menu_item_id IS NULL;

SELECT * FROM order_items
WHERE order_id IS NULL;

SELECT * FROM orders
WHERE order_id IS NULL;

SELECT * FROM rating
WHERE order_id IS NULL;

-- Primary Analysis (Based on Available data):

-- 1. Monthly Orders: Compare total orders across pre-crisis (Jan–May 2025) vs crisis
-- (Jun–Sep 2025). How severe is the decline?

WITH order_count AS
(
    SELECT
        COUNT(CASE WHEN order_timestamp BETWEEN '2025-01-01' AND '2025-05-31' THEN 1 END) AS pre_orders,
        COUNT(CASE WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30' THEN 1 END) AS crisis_orders
    FROM orders
)

SELECT
    pre_orders,
    crisis_orders,
    ROUND(
        (pre_orders - crisis_orders) * 100.0 / pre_orders,
        2
    ) AS decline_percentage
FROM order_count;

-- 2. Which top 5 city groups experienced the highest percentage decline in orders
-- during the crisis period compared to the pre-crisis period?

WITH city_orders AS
(
    SELECT
        c.city,
        SUM(o.order_timestamp BETWEEN '2025-01-01' AND '2025-05-31') AS pre_crisis_orders,
        SUM(o.order_timestamp BETWEEN '2025-06-01' AND '2025-09-30') AS crisis_orders
    FROM orders o
    JOIN customer c
        ON o.customer_id = c.customer_id
    GROUP BY c.city
)

SELECT
    city,
    pre_crisis_orders,
    crisis_orders,
    ROUND(
        (pre_crisis_orders - crisis_orders) * 100.0 / pre_crisis_orders,
        2
    ) AS decline_percentage
FROM city_orders
ORDER BY decline_percentage DESC
LIMIT 5;


-- 3. Among restaurants with at least 50 pre-crisis orders, which top 10 high-volume
-- restaurants experienced the largest percentage decline in order counts during
-- the crisis period?

WITH restaurant_orders AS
(
    SELECT
        r.restaurant_name,

        COUNT(CASE
                WHEN o.order_timestamp BETWEEN '2025-01-01' AND '2025-05-31'
                THEN 1
              END) AS pre_crisis_orders,

        COUNT(CASE
                WHEN o.order_timestamp BETWEEN '2025-06-01' AND '2025-09-30'
                THEN 1
              END) AS crisis_orders

    FROM orders o
    JOIN restaurant r
        ON o.restaurant_id = r.restaurant_id

    GROUP BY r.restaurant_name
)

SELECT
    restaurant_name,
    pre_crisis_orders,
    crisis_orders,

    ROUND(
        (pre_crisis_orders - crisis_orders) * 100.0 / pre_crisis_orders,
        2
    ) AS decline_percentage

FROM restaurant_orders

WHERE pre_crisis_orders >= 50

ORDER BY decline_percentage DESC

LIMIT 10;

-- 4. Cancellation Analysis: What is the cancellation rate trend pre-crisis vs crisis,
-- and which cities are most affected?

-- Cancellation Rate: Pre-Crisis vs Crisis-- 

SELECT
    CASE
        WHEN order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        ELSE 'Crisis'
    END AS period,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN is_cancelled = 'Y' THEN 1 END) AS cancelled_orders,
    ROUND(
        COUNT(CASE WHEN is_cancelled = 'Y' THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate
FROM orders
WHERE order_timestamp BETWEEN '2025-01-01' AND '2025-09-30'
GROUP BY period;

-- Most Affected Cities

SELECT
    c.city,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN o.is_cancelled = 'Y' THEN 1 END) AS cancelled_orders,
    ROUND(
        COUNT(CASE WHEN o.is_cancelled = 'Y' THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate
FROM orders o
JOIN customer c
ON o.customer_id = c.customer_id
WHERE o.order_timestamp BETWEEN '2025-06-01' AND '2025-09-30'
GROUP BY c.city
ORDER BY cancellation_rate DESC;

-- 5. Delivery SLA: Measure average delivery time across phases. Did SLA
-- compliance worsen significantly in the crisis period?

SELECT
    CASE
        WHEN o.order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        ELSE 'Crisis'
    END AS period,
    ROUND(AVG(d.actual_delivery_time_mins), 2) AS avg_delivery_time
FROM orders o
JOIN delivery_performance d
ON o.order_id = d.order_id
WHERE o.order_timestamp BETWEEN '2025-01-01' AND '2025-09-30'
GROUP BY period;

-- 6. Ratings Fluctuation: Track average customer rating month-by-month. Which
-- months saw the sharpest drop?

SELECT
    DATE_FORMAT(o.order_timestamp, '%Y-%m') AS month,
    ROUND(AVG(r.rating),2) AS avg_rating,
    ROUND(
        AVG(r.rating) - LAG(AVG(r.rating)) OVER(ORDER BY DATE_FORMAT(o.order_timestamp,'%Y-%m')),
        2
    ) AS rating_change
FROM orders o
JOIN rating r
ON o.order_id = r.order_id
GROUP BY month
ORDER BY rating_change;

-- 7. Sentiment Insights: During the crisis period, identify the most frequently
-- occurring negative keywords in customer review texts. (Hint: Use a Word Cloud
-- visual in Power BI to visualize the findings.)

SELECT
    review_text
FROM rating
WHERE review_timestamp BETWEEN '2025-06-01' AND '2025-09-30'
AND sentiment_score < 0;



-- 8. Revenue Impact: Estimate revenue loss from pre-crisis vs crisis (based on
-- subtotal, discount, and delivery fee).

-- Revenue Comparison-- 

SELECT
    CASE
        WHEN order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        ELSE 'Crisis'
    END AS period,
    ROUND(SUM(subtotal_amount),2) AS subtotal,
    ROUND(SUM(discount_amount),2) AS discount,
    ROUND(SUM(delivery_fee),2) AS delivery_fee,
    ROUND(SUM(subtotal_amount - discount_amount + delivery_fee),2) AS revenue
FROM orders
WHERE order_timestamp BETWEEN '2025-01-01' AND '2025-09-30'
GROUP BY period;

-- Revenue Loss Percentage

WITH revenue AS
(
    SELECT
        CASE
            WHEN order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
            ELSE 'Crisis'
        END AS period,
        SUM(subtotal_amount - discount_amount + delivery_fee) AS revenue
    FROM orders
    WHERE order_timestamp BETWEEN '2025-01-01' AND '2025-09-30'
    GROUP BY period
)

SELECT
    MAX(CASE WHEN period='Pre-Crisis' THEN revenue END) AS pre_revenue,
    MAX(CASE WHEN period='Crisis' THEN revenue END) AS crisis_revenue,
    ROUND(
        (MAX(CASE WHEN period='Pre-Crisis' THEN revenue END)
        - MAX(CASE WHEN period='Crisis' THEN revenue END))
        * 100.0 /
        MAX(CASE WHEN period='Pre-Crisis' THEN revenue END),
        2
    ) AS revenue_loss_pct
FROM revenue;

-- 9. Loyalty Impact: Among customers who placed five or more orders before the
-- crisis, determine how many stopped ordering during the crisis, and out of those,
-- how many had an average rating above 4.5?

WITH pre_customers AS
(
    SELECT customer_id
    FROM orders
    WHERE order_timestamp < '2025-06-01'
    GROUP BY customer_id
    HAVING COUNT(*) >= 5
),
crisis_customers AS
(
    SELECT DISTINCT customer_id
    FROM orders
    WHERE order_timestamp >= '2025-06-01'
      AND order_timestamp < '2025-10-01'
),
customer_rating AS
(
    SELECT
        customer_id,
        AVG(rating) AS avg_rating
    FROM rating
    GROUP BY customer_id
)

SELECT
    COUNT(*) AS stopped_customers,
    COUNT(CASE WHEN r.avg_rating > 4.5 THEN 1 END) AS high_rating_stopped_customers
FROM pre_customers p
LEFT JOIN crisis_customers c
ON p.customer_id = c.customer_id
JOIN customer_rating r
ON p.customer_id = r.customer_id
WHERE c.customer_id IS NULL;

-- 10.Customer Lifetime Decline: Which high-value customers (top 5% by total
-- spend before the crisis) showed the largest drop in order frequency and ratings
-- during the crisis? What common patterns (e.g., location, cuisine preference,
-- delivery delays) do they share?


-- High-value customers with order and rating decline

WITH high_value AS
(
    SELECT customer_id
    FROM
    (
        SELECT
            customer_id,
            NTILE(100) OVER(ORDER BY SUM(total_amount) DESC) AS p
        FROM orders
        WHERE order_timestamp < '2025-06-01'
        GROUP BY customer_id
    ) t
    WHERE p <= 5
)

SELECT
    h.customer_id,

    COUNT(CASE WHEN o.order_timestamp < '2025-06-01' THEN 1 END) AS pre_orders,
    COUNT(CASE WHEN o.order_timestamp >= '2025-06-01' THEN 1 END) AS crisis_orders,

    ROUND(AVG(CASE WHEN r.review_timestamp < '2025-06-01' THEN r.rating END),2) AS pre_rating,
    ROUND(AVG(CASE WHEN r.review_timestamp >= '2025-06-01' THEN r.rating END),2) AS crisis_rating

FROM high_value h
JOIN orders o
ON h.customer_id = o.customer_id
LEFT JOIN rating r
ON h.customer_id = r.customer_id

GROUP BY h.customer_id

ORDER BY (pre_orders - crisis_orders) DESC;

-- Common Pattern

WITH high_value AS
(
    SELECT customer_id
    FROM
    (
        SELECT
            customer_id,
            NTILE(100) OVER(ORDER BY SUM(total_amount) DESC) AS p
        FROM orders
        WHERE order_timestamp < '2025-06-01'
        GROUP BY customer_id
    ) t
    WHERE p <= 5
)

SELECT
    c.city,
    COUNT(*) AS customers
FROM high_value h
JOIN customer c
ON h.customer_id = c.customer_id
GROUP BY c.city
ORDER BY customers DESC;
