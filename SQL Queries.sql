------------------------------------------- Exploring The Dataset -------------------------------------------------


-- 1- Find the total Revenue by each Customer

/* 
This query selects the customer IDs from the tableRetail table
then calculates the revenue for each customer using the SUM and OVER analytical functions.

The SUM() function calculates the total revenue by multiplying the Price and Quantity columns, 
and the OVER() function partitions the calculation result by Customer_ID so that each customer's revenue is calculated separately.

Use DISTINCT to avoid Redundancy, and ORDER BY revenue DESC to be more readable.
*/

SELECT DISTINCT Customer_ID,
-- calculate the revenue for each customer by multiplying the "Price" and "Quantity", and summing them up
            SUM(Price * Quantity) OVER (PARTITION BY Customer_ID) AS Revenue
FROM tableRetail
ORDER BY Revenue DESC;

-------------------------------------------------------------------------------------------------------------------------

-- 2- Find the top selling Products per Quantity

/*

This query selects all  stock codes and the total quantity sold for each stock code.

The SUM() function calculates the total quantity sold for each stock code,
and OVER() function partitions the data based on stock code.

Use DISTINCT to avoid redundancy, and ORDER BY total_quantity DESC to get the top sells

*/

SELECT DISTINCT StockCode, SUM(Quantity) OVER (PARTITION BY StockCode) AS Total_Quantity
FROM tableRetail
ORDER BY Total_Quantity DESC;

-------------------------------------------------------------------------------------------------------------------------------

-- 3- Find the monthly revenue for the top 5 customers

/*

This query uses CTEs to find the monthly revenue for the top 5 customers based on their total revenue.

The first CTE: CustomersRev, calculates the total revenue earned per customer per month and the total revenue earned per customer overall.
Then the result is ordered by total revenue in descending order to find the highest customers.

The second CTE: topCustomers, uses the CustomersRev CTE to rank the customers based on total revenue earned, using the DENSE_RANK() analytical function.

The final SELECT statement retrieves all data from the topCustomers CTE where the customer ranking is less than or equal to 5.
To find the monthly revenue for the top 5 cutomers based on thier total revenue.

*/

-- Select DISTINCT customers and calculate revenue for each month and the total revenue
WITH CustomersRev AS (
  SELECT DISTINCT Customer_ID,
              TO_CHAR(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI'), 'MM-YYYY') AS orderMonth,
              SUM(Price * Quantity) OVER (PARTITION BY Customer_ID, TO_CHAR(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI'), 'MM-YYYY')) AS RevenuePerMonth,
              SUM(Price * Quantity) OVER (PARTITION BY Customer_ID) AS totalRevenue
  FROM tableRetail
  ORDER BY totalRevenue DESC
),

-- Using previous CTE, rank customers by total revenue,
-- so each cutomer will get a rank starts from 1 based on his total revenue
topCustomers AS (
    SELECT Customer_ID, orderMonth, RevenuePerMonth, totalRevenue,
                DENSE_RANK () OVER (ORDER BY totalRevenue DESC) AS rnk
    FROM CustomersRev

)
-- Using the previuos CTE, select the top 5 customers based on thier total revenue
SELECT *
FROM topCustomers
WHERE rnk <=5

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 4- Find the total revenue per month

/*

This query finds the total revenue in each month.

The SUM() function calculates the total revenue by multiply quantity sold by price of each one.
and OVER() function partitions the data based on month in "MM-YYYY" format

Use DISTINCT to avoid redundancy, and ORDER BY ordermonth ASC in "YYYY-MM" format 
to order per year then month.

*/

  SELECT DISTINCT TO_CHAR(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI'), 'YYYY-MM') AS orderMonth,
              SUM(Price * Quantity) OVER (PARTITION BY TO_CHAR(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI'), 'MM-YYYY')) AS RevenuePerMonth
  FROM tableRetail
  ORDER BY orderMonth;
  
-------------------------------------------------------------------------------------------------------------------------
-- 5- Find the percentage of total revenue generated by each customer

/*

This query calculates the total revenue and percentage of total revenue for each customer in the tableRetail.
It uses the SUM() fumction with "OVER (PARTITION BY)"  the customer_id to calculate the total revenue for each customer.
and then calculates the percentage of total revenue for each customer using the total revenue and the total revenue of all customers.

Use DISTINCT to avoid redundancy, and ORDER BY total_revenue DESC for better read.
*/

SELECT DISTINCT Customer_ID,
            SUM(Price * Quantity) OVER (PARTITION BY Customer_ID) AS total_revenue,
            CONCAT (ROUND ((SUM(Price * Quantity) OVER (PARTITION BY Customer_ID) / SUM(Price * Quantity) OVER ()) * 100,2),'%') AS Percentage_of_Total_Revenue
FROM tableRetail
ORDER BY total_revenue DESC;

----------------------------------------------------------------------------------------------------------------------------

-- 6- Find the top 10 customers by revenue, their most popular product and its revenue


/*

This query uses CTEs to find the top 10 customers by revenue, thier top product and its revenue.

The first CTE: Customer_Revenue, calculates the total revenue earned per customer.

The second CTE: Customer_Product, finds the total quantity and revenue for each product purchased by each customer, the total quantity that customer bought, and the product revenue from this customer.

The third CTE: Ranked_Products, uses Customer_Product CTE to assign a rank to each product for each customer based on the total quantity of the product purchased by the customer, so the top product can be extracted.

The final SELECT statement retrieves all data from the Customer_Product and Ranked_Products CTEs where the product ranking is 1 and cutomer ranking is less than or equal to 10
to get the most popular product for each customer with their total revenue.

*/


-- Get the total revenue for each customer and assign a rank based on the revenue
WITH Customer_Revenue AS (
  SELECT Customer_ID, SUM(Price * Quantity) AS Revenue,
              DENSE_RANK () OVER (ORDER BY SUM(Price * Quantity) DESC) AS rnk
  FROM tableRetail
  GROUP BY Customer_ID

),
-- Get the total quantity and revenue for each product purchased by each customer
Customer_Product AS (
  SELECT DISTINCT Customer_ID, StockCode, SUM(Quantity) AS Total_Quantity,
              SUM(Quantity * Price) AS product_revenue
  FROM tableRetail
  GROUP BY Customer_ID, StockCode
),
-- Rank the products for each customer based on their total quantity purchased
Ranked_Products AS (
  SELECT Customer_ID, StockCode, Total_Quantity, product_revenue,
  RANK() OVER (PARTITION BY Customer_ID ORDER BY Total_Quantity DESC) AS rnk
  FROM Customer_Product
)
-- Join the customer revenue and product data to get the most popular product for each customer with their total revenue
SELECT cr.Customer_ID, cr.Revenue AS total_revenue, rp.StockCode AS Most_Popular_Product, rp.Total_Quantity, rp.product_revenue
FROM Customer_Revenue cr
JOIN Ranked_Products rp 
ON cr.Customer_ID = rp.Customer_ID
WHERE rp.rnk = 1 AND cr.rnk <=10
ORDER BY cr.rnk;

------------------------------------------------------------------------------------------------------------------------------
-- 7- Find the top 10 products by revenue, thier total revenue, and their monthly revenue:

/*

This query uses CTEs to find the monthly revenue for the top 10 products by revenue.

The first CTE: Products_rev, finds the total revenue for each product and ranks them by revenue.

The second CTE: top_products, selects the top 10 products by revenue. 

The final SELECT statement retrieves all data from the top_products,
and orders the results by stock code and month.

*/

-- find the total revenue for each product and rank them by the total revenue
WITH Products_rev AS (
  SELECT StockCode,
              SUM(Price * Quantity) AS Revenue,
              DENSE_RANK () OVER (ORDER BY SUM(Price * Quantity) DESC) AS rnk
  FROM tableRetail
  GROUP BY StockCode
  ORDER BY Revenue DESC
),
-- select the top 10 product by total revenue
top_products AS(
    SELECT * FROM Products_rev
    WHERE rnk <=10

)
SELECT DISTINCT StockCode,
            TO_CHAR(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI'), 'YYYY-MM') AS Month,
            SUM(Price * Quantity) OVER (PARTITION BY StockCode, TO_CHAR(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI'), 'YYYY-MM')) AS monthly_revenue,
            SUM(Price * Quantity) OVER(PARTITION BY StockCode) AS total_revenue
FROM tableRetail
WHERE StockCode IN (SELECT StockCode FROM top_products)
ORDER BY StockCode, Month;

------------------------------------------------------------------------------------------------------------------------------
-- 8- Find the top 10 most frequently purchased items, thier total quantity, and their total revenue

/*

This query uses CTEs to find the top 10 products with the highest total quantity sold and their total revenue.

The first CTE: products_quantity, calculate the total quantity and total revenue for each product.

The second CTE: topProductsQuan,  ranks the product based on the total quantity.

The final SELECT statement retrieves all data for these top 10 products from the topProductsQuan.

*/

-- find the total quantity and totla revenue for each product
WITH products_quantity AS (

    SELECT 
        DISTINCT StockCode,
        SUM(Quantity) OVER (PARTITION BY StockCode) AS TotalQuantity,
        SUM(Quantity * Price) OVER (PARTITION BY StockCode) AS TotalRevenue    
    FROM 
        tableRetail
    ORDER BY 
        SUM(Quantity) OVER (PARTITION BY StockCode) DESC
-- ranks the product based on the total quantity
), topProductsQuan AS (

    SELECT StockCode, TotalQuantity, TotalRevenue,
                DENSE_RANK () OVER (ORDER BY TotalQuantity DESC) AS rnk
    FROM products_quantity
           
)

SELECT StockCode, TotalQuantity, TotalRevenue
FROM topProductsQuan
WHERE rnk <=10;


----------------------------------------------------------------------------------------------------------------------------

-- 9- Find the average basket size (average number of items purchased per transaction) for each customer

/*

This query displays the number of orders, total sold quantities, and average basket size for each unique customer.
It counts the number of orders for each customer, and the total quantities that bought from each user,
then calculate the average basket size by divide the total quantities on the number of orders for each customer

*/

SELECT DISTINCT Customer_ID,
           COUNT (*) OVER (PARTITION BY Customer_ID) AS NumberOfOrders,
           SUM (Quantity) OVER (PARTITION BY Customer_ID) AS total_sold_quantities,
           ROUND (AVG(Quantity) OVER (PARTITION BY Customer_ID), 2) AS AvgBasketSize
FROM tableRetail
ORDER BY AvgBasketSize DESC;

----------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------RFM MODEL----------------------------------------------------------------------

-- RFM (Monetary) Model

/*

This query uses the CTEs to calculate the RFM scores and find the customers segments based on thier scores.

The first CTE: ref_date, defines the reference date as the maximum date in the InviceDate.

The second CTE: customer_rfm,  calculates the RFM (recency, frequency, monetary) score for each customer, using the reference date.

The third CTE: scores,  calculates the FM score for each customer, based on the RFM scores calculated in the customer_rfm CTE.

The final SELECT statement assigns a customer segment to each customer, based on their R and FM scores.
*/

WITH
-- Extract the Maximum Date in the InvoiceDate column as a reference date
    ref_date AS (
        SELECT
                    MAX(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI')) AS reference_date,
                    TO_CHAR(MAX(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI')), 'DD') AS reference_day
        FROM tableRetail
    ),
    
-- Find the recency, frequency, monetary values
    customer_rfm AS (
        SELECT 
            Customer_ID,
            TO_CHAR(ref_date.reference_date - MAX(TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI')), '9999999') AS recency,
            COUNT(DISTINCT Invoice) AS frequency,
            SUM(Price * Quantity) AS monetary
        FROM tableRetail
        CROSS JOIN ref_date
        GROUP BY Customer_ID, ref_date.reference_date
    ),
    scores AS (
-- Find the average F and M scores
        SELECT Customer_ID, recency, frequency, monetary, r_score,
                    NTILE(5) OVER (ORDER BY AVG (f_score + m_score)) AS fm_score
        FROM(
-- use NTILE() to devide the customers into equal groups based on the RFM values
            SELECT Customer_ID, recency, frequency, monetary,
                NTILE (5) OVER (ORDER BY CAST(recency AS INT) DESC) AS r_score,
                NTILE (5) OVER (ORDER BY frequency ) AS f_score,
                NTILE(5) OVER (ORDER BY monetary ) AS m_score
            FROM customer_rfm
            )
        GROUP BY Customer_ID, recency, frequency, monetary, r_score
    )
-- Assign segments to customers based on thier RFM scores
SELECT Customer_ID, recency, frequency, monetary, r_score, fm_score,
            CASE
                WHEN (r_score = 5 AND (fm_score = 5 OR fm_score = 4))
                    OR (r_score = 4 AND fm_score = 5) THEN 'Champions'
                WHEN (fm_score = 2 AND (r_score = 5 OR r_score = 4))
                    OR (fm_score = 3 AND (r_score = 3 OR r_score = 4)) 
                        THEN 'Potential Loyalists'
                WHEN (r_score = 3 AND (fm_score = 5 OR fm_score = 4)) 
                    OR (r_score = 4 AND fm_score = 4 )
                    OR (r_score = 5 AND fm_score = 3)
                        THEN 'Loyal Customers'
                WHEN r_score = 5 AND fm_score = 1 
                        THEN 'Recent Customers'
                WHEN fm_score = 1 AND (r_score = 3 OR r_score = 4)
                        THEN 'Promising'
                WHEN r_score = 2 AND (fm_score = 3 OR fm_score = 2)
                OR (r_score = 3 AND fm_score = 2)
                        THEN 'Customers Needing Attention'
                WHEN (r_score = 2 AND (fm_score = 5 OR fm_score = 4 OR fm_score = 1))
                OR (r_score = 1 AND fm_score = 3)
                        THEN 'At Risk'
                WHEN r_score = 1 AND (fm_score = 5 OR fm_score = 4)
                        THEN 'Cant Lose Them'
                WHEN r_score = 1 AND fm_score = 2 
                        THEN 'Hibernating'
                WHEN r_score = 1 AND fm_score = 1 
                        THEN 'Lost'
                
            END 
            AS cust_segment
FROM scores;


---------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------Daily Transactions----------------------------------------------------------------------


-- 1- Find the maximum number of consecutive days a customer made purchases

/*

This query uses the CTEs to calculate calculate the maximum number of consecutive days for each customer made a purchase.

The first CTE: consecutive_days, uses the LAG function to compare the current date with the previous date and assign a value of 1 if the dates are consecutive, or 0 if they are not.
It is partitioned by customer and ordered by calendar date.

The second CTE: running_total, calculates the total consecutive days for each purchase using the SUM function over the is_consecutive column.
It is partitioned by customer and ordered by calendar date.

The final SELECT statement selects the distinct cust_id values from the running_total CTE and calculates the maximum number of consecutive days for each customer using the MAX function over the total_consecutive_days column.
*/

-- find the consecutive days for each cutomer
WITH consecutive_days AS (
  SELECT 
    cust_id,
    calendar_dt,
    CASE
      WHEN calendar_dt = LAG(calendar_dt) OVER (PARTITION BY cust_id ORDER BY calendar_dt) + 1
      THEN 1
      ELSE 0
    END AS is_consecutive
  FROM dailycustomers
),

-- Find the total consecutive days

running_total AS (
  SELECT 
    cust_id,
    calendar_dt,
    SUM(is_consecutive) OVER (PARTITION BY cust_id ORDER BY calendar_dt) AS total_consecutive_days
  FROM consecutive_days
)

-- select the max consecutive days
SELECT 
  DISTINCT cust_id,
  MAX(total_consecutive_days) OVER (PARTITION BY cust_id) AS max_consecutive_days
FROM running_total;

----------------------------------------------------------------------------------------------------

-- 2- Find the days/transactions does it take a customer to reach a spent threshold of 250 L.E

/*

This query uses the CTEs to calculate the average number of days or transactions it takes for a customer to reach a spend threshold of 250 LE.

The first CTE:  customer_spend,  calculates the total amount spent by each customer, using a window function to accumulate the spend over time.

The second CTE: customer_days, joins the dailycustomers table with customer_spend and uses a window function to count the number of distinct days each customer has made a purchase.

The third CTE: customer_threshold, calculates the number of days it takes for each customer to reach a spend of 250 LE,
using another window function to find the minimum number of days preceding the threshold date.

The final SELECT statement selects the cust_id and days_to_250 columns from the customer_threshold CTE,
filtering out any NULL values which is the customers didn't reach 250 LE, and grouping by cust_id and days_to_250.
*/

-- find total amount spent by each customer
WITH customer_spend AS (
  SELECT 
    cust_id,
    SUM(amt_le) OVER (PARTITION BY cust_id ORDER BY calendar_dt) AS total_spend
  FROM dailycustomers
),

-- find the number of distinct days each customer has made a purchase
customer_days AS (
  SELECT 
    dc.cust_id, cs.total_spend,
    COUNT(DISTINCT dc.calendar_dt) OVER (PARTITION BY dc.cust_id ) AS num_days
  FROM dailycustomers dc
  JOIN customer_spend cs
  ON dc.cust_id = cs.cust_id
),

-- find the number of days it takes for each customer to reach a spend of 250 LE
customer_threshold AS (
  SELECT 
    cust_id,
    MIN(num_days) OVER (PARTITION BY cust_id ORDER BY num_days ASC 
                        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS days_to_250
  FROM customer_days
  WHERE total_spend >= 250
)
SELECT 
  cust_id,
  days_to_250 AS threshold_of_250
FROM customer_threshold
WHERE days_to_250 IS NOT NULL
GROUP BY cust_id, days_to_250;
