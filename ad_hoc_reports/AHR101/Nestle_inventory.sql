--AHR101
SELECT
	--ihi.item_id,
	ie.instance_hrid,
	ih.hrid AS holdings_hrid,
	ihi.hrid AS item_hrid,
	--ihi.holdings_id,
	--ihi.instance_id,
	ihi.title,
	ihi.material_type_name,
	ihi.barcode,
	ihi.call_number,
	ihi.item_copy_number,
	iext.status_name AS item_status_name,
	to_char(iext.status_date::DATE, 'mm/dd/yyyy') AS item_status_date,
	ihi.loan_type_name,
	--ih.permanent_location_id,
	--ll.location_id,
	ll.location_name,
	ll.library_name
FROM
	inventory_holdings AS ih
LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON
	ih.permanent_location_id = ll.location_id
LEFT JOIN folio_reporting.items_holdings_instances AS ihi 
        ON
	ih.id = ihi.holdings_id
LEFT JOIN folio_reporting.instance_ext AS ie 
        ON
	ihi.instance_id = ie.instance_id
LEFT JOIN folio_reporting.item_ext AS iext 
        ON
	ihi.item_id = iext.item_id
WHERE
	ll.library_name LIKE 'Nest%'
	AND ihi.material_type_name IN ('Equipment', 'Peripherals', 'Supplies', 'Laptop')
ORDER BY
	instance_hrid,
	holdings_hrid,
	item_hrid,
	title,
	call_number,
	item_copy_number;
