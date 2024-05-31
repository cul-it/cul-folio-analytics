--AHR145
--WorldCat_OCLC_numbers_matched_to_catalog
-- This query finds catalog matches to a list of WorldCat OCLC numbers, and finds Folio circulation totals by patron group.
-- For checkouts after 2-9-23, shows the patron department and college (when that data existed in the patron record).

--Query writer: Joanne Leary (jl41)
--Date posted: 5/31/24

SELECT 
	aoup.row_id,
	aoup.worldcat_oclc_number,
	TRIM (SUBSTRING (iid.identifier,8,15)) AS catalog_oclc_number,
	ii.hrid as instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ii.discovery_suppress as instance_suppress,
	he.discovery_suppress as holdings_suppress,
	he.permanent_location_name,
	li.patron_group_name,
	cs.custom_fields__department,
	cs.custom_fields__college,
	cs.department_code,
	COUNT (DISTINCT li.loan_id) AS count_of_circs 

FROM local.adam_over_under_poc AS aoup 
	LEFT JOIN folio_reporting.instance_identifiers AS iid
	ON concat ('(OCoLC)',aoup.worldcat_oclc_number) = iid.identifier
	
	LEFT JOIN inventory_instances as ii
	ON iid.instance_id = ii.id
	
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	LEFT JOIN folio_reporting.item_ext AS ie 
	ON he.holdings_id = ie.holdings_record_id 
	
	LEFT JOIN folio_reporting.loans_items AS li 
	ON ie.item_id = li.item_id
	
	LEFT JOIN local_core.circ_snapshot4 AS cs 
	ON li.loan_id = cs.loan_id
	
WHERE (iid.identifier_type_name = 'OCLC' or iid.instance_hrid is null)

GROUP BY 
	aoup.row_id,
	aoup.worldcat_oclc_number,
	TRIM (SUBSTRING (iid.identifier,8,15)),
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	he.permanent_location_name,
	li.patron_group_name,
	cs.custom_fields__department,
	cs.custom_fields__college,
	cs.department_code,
	ii.discovery_suppress,
	he.discovery_suppress
	
ORDER BY aoup.row_id, instance_hrid, holdings_hrid, item_hrid, li.patron_group_name
