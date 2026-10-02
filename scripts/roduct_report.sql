/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/
-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS
WITH products AS (
SELECT 
    f.order_number,
    f.customer_key,
    p.product_key,
    p.product_name,
    p.category,
    p.subcategory,
    f.order_date,
    f.sales_amount,
    f.quantity,
    p.cost
FROM gold.fact_sales f 
LEFT JOIN gold.dim_products p
ON        f.product_key = p.product_key
WHERE order_date IS NOT NULL
)
, product_aggregations AS (
SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    MAX(order_date) AS last_sale_date,
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT customer_key) AS unique_total_customers,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) AS life_span,
    ROUND(AVG(CAST(sales_amount AS FLOAT)/NULLIF(quantity, 0)),1) AS avg_selling_price
FROM products
GROUP BY 
    product_key,
    product_name,
    category,
    subcategory,
    cost
)
-- checking the sales range
/* SELECT 
    MIN(total_sales), --> 2430
    MAX(total_sales)  -->1373454
FROM product_level_metrics */ 

SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    DATEDIFF(month, last_sale_date, GETDATE()) AS recency_in_months,
    total_orders,
    total_sales,
    CASE WHEN total_sales >= 1000000 THEN 'High Performer'
         WHEN total_sales BETWEEN 500000 AND  1000000 THEN 'Mid range'
         ELSE 'Low Performer'
    END AS product_segments,
    total_quantity,
    unique_total_customers,
    life_span,
    avg_selling_price,
    -- calculating average order revenue
    CASE WHEN total_orders = 0 THEN 0 -- here i have doubt, so we can also write total_sales(which is obviously 0)
         ELSE total_sales / total_orders
    END AS avg_order_revenue,
    -- calculating average monthly revenue
    CASE WHEN life_span  = 0 THEN total_sales
         ELSE total_sales / life_span
    END AS avg_monthly_revenue
FROM product_aggregations



