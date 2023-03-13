--AHR100
--New and Noteworthy Books
SELECT
	he.holdings_hrid,
	ie.item_hrid,
	ihi.title,
	--he.holdings_id,
	he.permanent_location_name,
	he.temporary_location_name,
	he.call_number_prefix,
	he.call_number,
	he.call_number_suffix,
	--he.instance_id,
	he.type_name,
	ie.permanent_loan_type_name,
	ie.temporary_loan_type_name,
	ihi.material_type_name,
	ihi.loan_type_name,
	--ihi.holdings_record_id,
	--ihi.instance_id,
	ihi.barcode,
	--li.item_id,
	li.loan_date,
	li.loan_due_date,
	li.renewal_count,
	li.loan_policy_name
FROM
	folio_reporting.holdings_ext AS he
LEFT JOIN folio_reporting.items_holdings_instances AS ihi 
        ON
	he.holdings_id = ihi.holdings_id
LEFT JOIN folio_reporting.item_ext AS ie 
        ON
	ihi.item_id = ie.item_id
LEFT JOIN folio_reporting.loans_items AS li 
        ON
	ie.item_id = li.item_id
WHERE
	he.call_nUmber_prefix = 'New & Noteworthy'
	AND li.loan_date >'2021/11/01'
ORDER BY
	loan_date;
