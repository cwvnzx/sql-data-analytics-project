/* Change Over Time trends 
   Aggregated Measure By Dimension
*/
-- By Year
SELECT 
YEAR(order_date) AS order_year,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date)

-- By Month, this gives the seasonality of our business
SELECT 
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)

-- How many new customers were added each year


/* Cumulative Analysis */ 
-- Calculate the total_sales per month
-- and the running total of sales over time
SELECT 
	order_date,
	total_sales,
	SUM(total_sales) OVER (PARTITION BY YEAR(order_date) ORDER BY order_date) AS running_total_sales
FROM (
		SELECT 
		DATETRUNC(month,order_date) AS order_date,
		SUM(sales_amount) AS total_sales
		FROM gold.fact_sales
		WHERE order_date IS NOT NULL
		GROUP BY DATETRUNC(month,order_date)
	  ) t

-- Calculate the total_sales per year
-- and the running total of sales over time

SELECT 
	order_date,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales
FROM (
		SELECT 
		DATETRUNC(year,order_date) AS order_date,
		SUM(sales_amount) AS total_sales
		FROM gold.fact_sales
		WHERE order_date IS NOT NULL
		GROUP BY DATETRUNC(year,order_date)
	  ) t

/* Performance Analysis */

/* Analyze the yearly performance of products by 
   comparing their sales to both the average sales
   performance of the product and te previous year's
   sales. */
   WITH yearly_product_sales AS (
   SELECT 
   YEAR(f.order_date) AS order_year,
   p.product_name,
   SUM(f.sales_amount) AS current_sales
   FROM gold.fact_sales f
   LEFT JOIN gold.dim_products p
   ON        f.product_key = p.product_key
   WHERE f.order_date IS NOT NULL
   GROUP BY YEAR(f.order_date), p.product_name
   )
   SELECT 
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above avg'
	     WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below avg'
		 ELSE 'avg'
	END AS 'avg_change',
	-- Year-Over-Year Analysis
	LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year ) py_sales,
	current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year ) AS diff_pysales,
	CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year ) > 0 THEN 'Increase'
	     WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year ) < 0 THEN 'Decrease'
		 ELSE 'No Change'
	END AS 'py_change'
   FROM yearly_product_sales
   ORDER BY product_name, order_year

   /* Part To Whole Analysis (Proportional Analysis) */ 
--  which categories contribute the most to the overall sales.
WITH category_sales AS (
SELECT  
	p.category,
	SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f 
LEFT JOIN gold.dim_products p
ON        f.product_key = p.product_key
GROUP BY p.category)

SELECT 
	category,
	total_sales,
	SUM(total_sales) OVER () overall_sales,
	CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100,2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC

WITH category_sales AS (
SELECT  
	p.category,
	SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f 
LEFT JOIN gold.dim_products p
ON        f.product_key = p.product_key
GROUP BY p.category)
-- total_sales -> total_nr_of_orders
-- total_sales -> total_nr_of_customers

SELECT 
	category,
	total_sales,
	SUM(total_sales) OVER () overall_sales,
	CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100,2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC


/* Data Segmentation */
-- Segment products into cost ranges and count how 
-- many products fall into each segment
SELECT  -- first let us check the range of cost of the products
	MIN(cost) min_cost,
	MAX(cost) max_cost
FROM gold.dim_products

WITH product_segments AS (
SELECT 
	product_key,
	product_name,
	cost,
	CASE WHEN cost < 100 THEN 'Below 100'
		 WHEN cost BETWEEN 100 AND 500 THEN '100 - 500'
		 WHEN cost BETWEEN 500 AND 1000 THEN '500 - 1000'
		 ELSE 'Above 1000'
	END cost_range
FROM gold.dim_products
)
SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC

/* Group customers into three segments based on 
their spending behavior:
	- VIP : Customers with atleast 12 months of 
	  history and spending more than 5000 euros
	- Regular : Customers with atleast 12 months 
	  of history but spending 5000 euros or less
	- New : Customers with a lifespan < 12 months
   And find the total number of customers by each group */

WITH customer_spending AS (
SELECT 
	c.customer_key,
	SUM(f.sales_amount) AS total_spending,
	MIN(f.order_date) AS first_order,
	MAX(f.order_date) AS last_order,
	DATEDIFF(month, MIN(f.order_date), MAX(f.order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON        f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT 
	customer_segment,
	COUNT(customer_key) AS total_customers
FROM (
		SELECT 
			customer_key,
			total_spending,
			lifespan,
			CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
				 WHEN lifespan >= 12 AND total_spending < 5000 THEN 'Regular'
				 ELSE 'New'
			END AS customer_segment
		FROM customer_spending
	  )t
GROUP BY customer_segment
ORDER BY total_customers DESC

