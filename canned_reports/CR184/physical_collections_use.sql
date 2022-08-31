WITH loans AS 

(SELECT 
	li.loan_id,
	CASE WHEN li.renewal_count IS NULL THEN '0' ELSE li.renewal_count END AS renew_count,
	ll.library_name,
	li.patron_group_name,
	li.hrid,
	li.loan_date,
	li.loan_policy_name,
	li.material_type_name,
	CASE 
		WHEN li.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment' 
		WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
		WHEN li.hrid IS NULL AND li.loan_policy_name LIKE '3 hours%' THEN 'Equipment'
		WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
		ELSE 'Regular' END AS collection_type,
	li.current_item_effective_location_id,
	li.item_effective_location_name_at_check_out,
	ll.location_id,
	ll.location_name
	
	FROM folio_reporting.loans_items AS li 
	LEFT JOIN folio_reporting.locations_libraries AS ll 
	ON li.item_effective_location_id_at_check_out = ll.location_id 

WHERE li.loan_date >= '2021-07-01'
)

---Main query --

SELECT 
  loan_date,	
  library_name,
	patron_group_name,
	collection_type,
	material_type_name,
	COUNT(loan_id) AS number_of_checkouts,
	sum(renew_count) AS number_of_renewals,
	COUNT(loan_id) + sum(renew_count) AS total_charges_and_renewals

FROM loans 

GROUP BY 
        loan_date,
	library_name,
	item_effective_location_name_at_check_out,
	patron_group_name,
	collection_type,
	material_type_name

ORDER BY
	library_name, patron_group_name, collection_type
