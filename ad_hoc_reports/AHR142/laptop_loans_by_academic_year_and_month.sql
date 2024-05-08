--AHR142
--laptop_loans_by_academic_year_and_month
--This query finds laptop loans by library and Academic Year, and breaks it down by month, type of loan (hourly or extended loan) and type of laptop (Dell or Mac).
-- The academic year runs from August 1 through May 31. The query compares the most recent two years; Nestle library is excluded.
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 4/16/24

WITH items AS (
SELECT 
	iext.item_id,
	iext.item_hrid,
	iext.barcode,
	iext.effective_location_id,
	iext.effective_location_name,
	iext.effective_call_number_prefix,
	iext.effective_call_number,
	iext.copy_number,
	ll.library_name,
	iext.material_type_name

FROM folio_reporting.item_ext as iext 
	left join folio_reporting.locations_libraries as ll 
	on iext.effective_location_id = ll.location_id

WHERE iext.material_type_name = 'Laptop'
	OR iext.barcode = '31924123681144'
),

loans AS (
SELECT 
	items.library_name,
	case when li.loan_date::date is null then null else date_part ('year',li.loan_date::date) end as calendar_year,
	CASE 
		WHEN (li.loan_date >= '2022-08-01' AND li.loan_date <'2023-06-01') then 'AY 22-23' else 'AY 23-24' end as academic_year,
		--li.loan_date IS NULL THEN NULL else date_part ('year',li.loan_date::date) end as calendar_year,
		--WHEN DATE_PART ('month', li.loan_date::DATE) > 6 THEN CONCAT ('FY ', DATE_PART ('year',li.loan_date::DATE)+1) 
		--ELSE CONCAT ('FY ',DATE_PART ('year',li.loan_date::DATE)) END AS fiscal_year,
	case when li.loan_date is null then null else date_part ('month',li.loan_date) end as month_number,
	case when li.loan_date is null then '' else TO_CHAR (li.loan_date::TIMESTAMP, 'Month') end AS month_name,
	CASE WHEN items.effective_call_number ILIKE '%mac%' THEN 'Mac' ELSE 'Dell' END AS laptop_type,
	CASE 
		when li.loan_policy_name LIKE '%week%'THEN 'Extended loan'
		WHEN li.loan_policy_name IS NULL THEN ' - '
		ELSE 'Hourly Loan'
		END AS loan_type,
	items.effective_location_name,
	items.effective_call_number_prefix,
	items.effective_call_number,
	items.copy_number,
	items.item_hrid,
	items.barcode,
	items.material_type_name,
	COUNT (li.loan_id) AS number_of_loans

	FROM items 
		left join folio_reporting.loans_items as li
		on items.item_id = li.item_id
	
	WHERE (li.loan_date >= '2022-08-01' AND li.loan_date <'2023-06-01')
		OR (li.loan_date >= '2023-08-01' AND li.loan_date <'2024-06-01')
		OR li.loan_date is null
	
GROUP BY 
	items.library_name,
	case when li.loan_date::date is null then null else date_part ('year',li.loan_date::date) end,
	CASE WHEN (li.loan_date >= '2022-08-01' AND li.loan_date <'2023-06-01') then 'AY 22-23' else 'AY 23-24' end,
		--WHEN li.loan_date IS NULL THEN NULL else date_part ('year',li.loan_date::date) end, 
		--WHEN DATE_PART ('month', li.loan_date::DATE) > 6 THEN CONCAT ('FY ', DATE_PART ('year',li.loan_date::DATE)+1) 
		--ELSE CONCAT ('FY ',DATE_PART ('year',li.loan_date::DATE)) end,
	case when li.loan_date is null then null else date_part ('month',li.loan_date) end,
	case when li.loan_date is null then '' else TO_CHAR (li.loan_date::TIMESTAMP, 'Month') end,
	CASE WHEN items.effective_call_number ILIKE '%mac%' THEN 'Mac' ELSE 'Dell' END,
	CASE 
		WHEN li.loan_policy_name like '%week%'THEN 'Extended loan'
		WHEN li.loan_policy_name is null THEN ' - '
		ELSE 'Hourly Loan'
		END,
	items.effective_location_name,
	items.effective_call_number_prefix,
	items.effective_call_number,
	items.copy_number,
	items.item_hrid,
	items.barcode,
	items.material_type_name
	
	ORDER BY library_name, loan_type)
	
-- Main query --

SELECT distinct
	
	loans.library_name,
	
	loans.academic_year,
	loans.calendar_year,
	--loans.calendar_year,
	--loans.fiscal_year,
	loans.laptop_type,
	loans.effective_location_name,
	loans.effective_call_number_prefix,
	loans.effective_call_number,
	loans.copy_number,
	loans.item_hrid,
	loans.barcode,
	loans.loan_type,
	loans.material_type_name,
	loans.month_number,
	loans.month_name,
	--loans.effective_call_number,
	--count(loans.item_hrid) as number_of_distinct_items,
	sum(loans.number_of_loans) as number_of_checkouts
	--sum(loans.number_of_loans) / count(loans.item_hrid) as loans_per_item

from loans
where loans.library_name not like 'Nest%'

group by 
	
	loans.library_name,
	
	loans.academic_year,
	loans.calendar_year,
	--loans.calendar_year,
	--loans.fiscal_year,
	loans.laptop_type,
	loans.effective_location_name,
	loans.effective_call_number_prefix,
	loans.effective_call_number,
	loans.copy_number,
	loans.item_hrid,
	loans.barcode,
	loans.loan_type,
	loans.material_type_name,
	loans.month_number,
	loans.month_name
	--loans.effective_call_number,

order by effective_location_name, academic_year, calendar_year, month_number, laptop_type, effective_call_number, copy_number, loans.item_hrid;
