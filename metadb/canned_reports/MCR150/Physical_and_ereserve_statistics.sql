-- MCR150 - Physical and e-reserve statistics 
-- Fall 2024 reserves - 12-18-24
--This query shows the physical checkouts and online clicks for items on reserve at all libraries, for the semester indicated. 

--Query writer: Joanne Leary (jl41)
--Posted on: 12/18/24

WITH itemids AS 
	(SELECT 
		jl.itembarcode AS jl_item_barcode,
		ie.barcode AS ie_item_barcode,
		ie.item_id,
		ie.item_hrid
	FROM local_static.jl_fall_2024_12_18_24 AS jl
	INNER JOIN folio_derived.item_ext AS ie 
	ON jl.itembarcode = ie.barcode
),

loans AS 
	(SELECT 
		ie.item_id,
		jl.itembarcode,
		COUNT (li.loan_id) AS number_of_loans
	
	FROM local_shared.jl_fall_2024_12_18_24 AS jl 
		LEFT JOIN folio_derived.item_ext AS ie 
		ON jl.itembarcode = ie.barcode
		
		LEFT JOIN folio_derived.loans_items AS li 
		ON li.item_id = ie.item_id
	
	WHERE li.loan_date::date >= '2024-08-15'
	AND li.loan_date::date < '2024-12-31'
	
	GROUP BY ie.item_id, jl.itembarcode
)

SELECT DISTINCT
	jl.*,
	itemids.item_hrid AS folio_item_hrid,
	CASE WHEN jl.numberofusers = 0 THEN 0 ELSE jl.numberofusers END AS total_ereserve_users,
	CASE WHEN jl.totalclicks IS NULL THEN 0 ELSE jl.totalclicks END AS total_ereserve_clicks,
	CASE WHEN loans.number_of_loans IS NULL THEN 0 ELSE loans.number_of_loans END AS total_physical_loans

FROM local_static.jl_fall_2024_12_18_24 AS jl 
	LEFT JOIN loans 
	ON jl.itembarcode = loans.itembarcode
	
	LEFT JOIN itemids 
	ON jl.itembarcode = itemids.jl_item_barcode
	
ORDER BY pickuplocation, processinglocation, deptfinal, coursenumber, instructordisplayname, itemtitle, author
;
