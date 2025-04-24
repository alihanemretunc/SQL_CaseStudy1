SELECT *
FROM menu;

SELECT *
FROM sales;

SELECT *
FROM members;

-- 1 What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price) AS total_amount_spent
FROM menu m
JOIN sales s
	ON m.product_id = s.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT(order_date)) AS visit_days
FROM sales
GROUP BY customer_id
ORDER BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?

WITH ranked_sales AS (
  SELECT
    s.customer_id,
    s.product_id,
    m.product_name,
    ROW_NUMBER() OVER (
      PARTITION BY s.customer_id
      ORDER BY s.order_date, s.product_id
    ) AS rn
  FROM sales s
  JOIN menu m ON s.product_id = m.product_id
)
SELECT
  customer_id AS customer,
  product_name AS first_purchased_menu_item
FROM ranked_sales
WHERE rn = 1
ORDER BY customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT customer_id, product_name, COUNT(s.product_id) AS counter
FROM sales s
JOIN menu m
	ON s.product_id = m.product_id
WHERE s.product_id = (SELECT product_id
					  FROM sales
					  GROUP BY product_id
					  ORDER BY COUNT(product_id) DESC
					  LIMIT 1)
GROUP BY customer_id, product_name;

-- 5. Which item was the most popular for each customer?

WITH customer_orders AS
(
  SELECT s.customer_id, m.product_name,
         COUNT(*) AS order_count,
         RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS ranking
  FROM sales s
  JOIN menu m
      ON s.product_id = m.product_id
  GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name, order_count
FROM customer_orders
WHERE ranking = 1;

-- 6. Which item was purchased first by the customer after they became a member?

WITH item_rank_after_join_date AS
(
	SELECT m.customer_id AS customer_id,
		   product_name,
		   RANK() OVER(PARTITION BY m.customer_id ORDER BY order_date ASC) AS ranking
	FROM members m
	JOIN sales s
		ON m.customer_id = s.customer_id
		AND join_date < order_date
	JOIN menu me
		ON s.product_id = me.product_id
)
SELECT customer_id, product_name
FROM item_rank_after_join_date
WHERE ranking = 1;

-- 7. Which item was purchased just before the customer became a member?

WITH item_rank_before_join_date AS
(
	SELECT m.customer_id AS customer_id,
			   product_name,
			   RANK() OVER(PARTITION BY m.customer_id ORDER BY order_date DESC) AS ranking
	FROM members m
	JOIN sales s
		ON m.customer_id = s.customer_id
		AND order_date <= join_date
	JOIN menu me
		ON s.product_id = me.product_id
)
SELECT customer_id, product_name
FROM item_rank_before_join_date
WHERE ranking = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(*) AS total_items,
	   SUM(m.price) AS total_amount
FROM sales s
JOIN members mem
  ON s.customer_id = mem.customer_id
JOIN menu m
  ON s.product_id = m.product_id 
  AND s.order_date < mem.join_date
GROUP BY s.customer_id
ORDER BY customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?

SELECT s.customer_id, 
	   SUM(CASE WHEN m.product_name = 'sushi' THEN m.price * 10 * 2
		   ELSE m.price * 10
		   END) AS total_points
FROM sales s
JOIN menu m 
	ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT s.customer_id,
	   SUM(CASE WHEN s.order_date BETWEEN mem.join_date AND DATE_ADD(mem.join_date, INTERVAL 6 DAY)
				THEN m.price * 20  -- all items get 20 pts/$1 in first week
		   ELSE
		   CASE WHEN m.product_name = 'sushi' THEN m.price * 20  -- 2x points for sushi
           ELSE m.price * 10  -- normal points for others
		   END
		   END) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members mem ON s.customer_id = mem.customer_id
WHERE s.order_date <= '2021-01-31'
GROUP BY s.customer_id
ORDER BY customer_id;

-- Bonus 1

SELECT s.customer_id, s.order_date,
	   m.product_name, m.price,
	   CASE WHEN s.order_date >= mem.join_date THEN 'Y'
	   ELSE 'N'
	   END AS member
FROM sales s
JOIN menu m 
	ON s.product_id = m.product_id
LEFT JOIN members mem 
	ON s.customer_id = mem.customer_id
ORDER BY s.customer_id, s.order_date, product_name;

-- Bonus 2

WITH member_orders AS 
(
SELECT s.customer_id, s.order_date, 
        m.product_name, m.price,
        CASE WHEN mem.join_date IS NOT NULL AND s.order_date >= mem.join_date THEN 'Y'
		ELSE 'N'
        END AS member
FROM sales s
JOIN menu m 
	ON s.product_id = m.product_id
LEFT JOIN members mem 
	ON s.customer_id = mem.customer_id
)
SELECT customer_id, order_date,
	   product_name, price,
	   member,
	   CASE WHEN member = 'Y' THEN 
            DENSE_RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date, product_name)
	   ELSE NULL
	   END AS ranking
FROM member_orders;