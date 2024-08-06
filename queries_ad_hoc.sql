 /* Basic Exploration of all tables */
 -- Table dim_customer
 select * from dim_customer;
 select count(1) as customer_count from dim_customer; -- 209
 
 -- Table dim_customer
 select * from dim_product;
 select count(1) as product_count from dim_product; -- 397
 
 -- Table fact_gross_price
 select * from fact_gross_price;
 select count(1) as row_count from fact_gross_price; -- 579
 
 -- Table fact_manufacturing_cost
 select * from fact_manufacturing_cost;
 select count(1) as row_count from fact_manufacturing_cost; -- 579
 
  -- Table fact_pre_invoice_deductions
 select * from fact_pre_invoice_deductions;
 select count(1) as row_count from fact_pre_invoice_deductions; -- 418
 
  -- Table fact_sales_monthly
 select * from fact_sales_monthly;
 select count(1) as row_count from fact_sales_monthly; -- 971631
 
 /* Ad-hoc Queries */
 /* Provide the list of markets in which customer  "Atliq  Exclusive"  operates its  business in the  APAC  region. */
 select distinct(market) as markets_AtliqExclusive_APACRegion from dim_customer
 where customer = 'Atliq Exclusive' and region = 'APAC';
 
 /* What is the percentage of unique product increase in 2021 vs. 2020? 
 The final output contains these fields: unique_products_2020, unique_products_2021, percentage_chg */
 with fy_2020 as(
 	 select count(distinct(product_code)) as unique_products_2020
     from fact_sales_monthly
     where fiscal_year = 2020
 ),
 fy_2021 as(
	 select count(distinct(product_code)) as unique_products_2021
     from fact_sales_monthly
     where fiscal_year = 2021
 )
 select unique_products_2020, unique_products_2021, 
	 concat(round((unique_products_2021 - unique_products_2020) / unique_products_2020 * 100, 2), '%') as percentage_chg
 from fy_2020, fy_2021;
 
 /* Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
 The final output contains 2 fields: segment, product_count */
 select segment, count(distinct(product)) as unique_product_count 
 from dim_product
 group by segment
 order by unique_product_count desc;
 
 /* Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
 The final output contains these fields: segment, product_count_2020, product_count_2021, difference */
 with fy2020 as(
	select dp.segment, count(distinct(fsm.product_code)) as product_count_2020 
	from fact_sales_monthly fsm
    left join dim_product dp
    on fsm.product_code = dp.product_code
    where fsm.fiscal_year = 2020
	group by dp.segment
 ),
 fy2021 as(
	select dp.segment, count(distinct(fsm.product_code)) as product_count_2021 
	from fact_sales_monthly fsm
    left join dim_product dp
    on fsm.product_code = dp.product_code
    where fsm.fiscal_year = 2021
	group by dp.segment
 )
 select fy2020.segment, product_count_2020, product_count_2021,
	(product_count_2021 - product_count_2020) as difference
 from fy2020
 inner join fy2021
 on fy2020.segment = fy2021.segment
 order by difference desc;
 
 /* Get the products that have the highest and lowest manufacturing costs. 
 The final output should contain these fields: product_code, product, manufacturing_cost */
 select fmc.product_code, product, manufacturing_cost 
 from fact_manufacturing_cost fmc
 left join dim_product dp
 on fmc.product_code = dp.product_code
 where manufacturing_cost = (
	select max(manufacturing_cost)from fact_manufacturing_cost
 ) or manufacturing_cost = (
	select min(manufacturing_cost)from fact_manufacturing_cost
 )
 order by manufacturing_cost desc;
 
/* Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
The final output contains these fields: customer_code, customer, average_discount_percentage */
select dc.customer_code, customer,
	ROUND(AVG(pre_invoice_discount_pct) * 100, 2) AS average_discount_percentage
from dim_customer dc 
left join fact_pre_invoice_deductions fpid 
on dc.customer_code = fpid.customer_code
where fiscal_year = 2021 and market = 'India'
group by dc.customer_code, customer
order by average_discount_percentage desc limit 5;

/* Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns:  Month, Year, Gross_sales_Amount */
-- multiple joins version
select 
	month(fsm.date) as Month,
    year(fsm.date) as Year,
	round(sum(fsm.sold_quantity * fgp.gross_price)/1000000, 2) as gross_sales_amount
from fact_sales_monthly fsm 
left join dim_customer dc
on fsm.customer_code = dc.customer_code
left join fact_gross_price fgp
on fgp.product_code = fsm.product_code and fgp.fiscal_year = fsm.fiscal_year
where dc.customer = 'Atliq Exclusive'
group by Year, Month;

-- CTEs version
with gross_table as(
	select date, fsm.customer_code, fgp.fiscal_year,
		(gross_price * sold_quantity) as gross_sales
	from fact_sales_monthly fsm 
	left join fact_gross_price fgp
	on fsm.product_code = fgp.product_code and fsm.fiscal_year = fgp.fiscal_year
),
customer as(
	select date, dc.customer_code, gross_sales
	from gross_table gt
    left join dim_customer dc
	on gt.customer_code = dc.customer_code
	where customer = 'Atliq Exclusive'
)
select month(date) as Month, year(date) as Year,
    round(sum(gross_sales) / 1000000, 2) as Gross_sales_amount
from customer
group by Month, Year;

/* In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity: Quarter, total_sold_quantity */
--  Note that fiscal_year  for Atliq Hardware starts from September(09)
select case
	when month(date) between 9 and 11 then 'Q1'
    when month(date) in (12, 1, 2) then 'Q2'
    when month(date) between 3 and 5 then 'Q3'
    when month(date) between 6 and 8 then 'Q4'
    end as Quarter,
	sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where fiscal_year = 2020
group by Quarter
order by total_sold_quantity desc;

/* Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields: channel, gross_sales_mln, percentage */
 with channel_gross_sales as (
	 select dc.channel,
		round(sum(fsm.sold_quantity * fgp.gross_price)/1000000, 2) as gross_sales_mln
	from fact_sales_monthly fsm 
	left join dim_customer dc
	on fsm.customer_code = dc.customer_code
	left join fact_gross_price fgp
	on fgp.product_code = fsm.product_code and fgp.fiscal_year = fsm.fiscal_year
	where fsm.fiscal_year = 2021
	group by channel
),
total_sum as (
	select sum(gross_sales_mln) AS tot_gross_sales_mln
	from channel_gross_sales
)
select channel_gross_sales.*,
    CONCAT(ROUND(channel_gross_sales.gross_sales_mln * 100 / total_sum.tot_gross_sales_mln , 2), "%") AS percentage
from channel_gross_sales, total_sum
order by gross_sales_mln desc;

/* Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields: division, product_code, product, total_sold_quantity, rank_order */
 with product_table as(
	 select dp.division, dp.product_code, dp.product, 
		sum(fsm.sold_quantity) as total_sold_quantity
	 from dim_product dp 
	 left join fact_sales_monthly fsm
	 on dp.product_code = fsm.product_code
	 where fsm.fiscal_year = 2021
	 group by fsm.product_code, dp.division, dp.product
),
ranking as (
	select product_table.*, 
		rank() over(partition by division order by total_sold_quantity desc) as rank_order
	from product_table
)
select * from ranking
where rank_order < 4;
