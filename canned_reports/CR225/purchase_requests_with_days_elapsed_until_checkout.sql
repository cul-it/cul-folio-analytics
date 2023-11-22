-- 11-8-23: Purchase requests with time to first checkout
-- This query gets purchase requests in Voyager and Folio and calculates the number of days between the request date and checkout date. 
-- Because there is no request date in the order record for Folio or Voyager, the po_line/line_item create date is used as an approximation of the request date.
-- Calculation of time to first checkout is very uncertain since POs are instance and holdings level, but checkouts are item level
-- Includes a filter for start and end fiscal years; returns all data if filters are left blank
-- Written by Joanne Leary and reviewed by Sharon Beltaine

WITH parameters as 
(select 
'FY2019'::varchar as start_fiscal_year_filter, -- enter a fiscal year name  (ex: FY2021) or leave blank
'FY2024'::varchar as end_fiscal_year_filter -- enter a fiscal year name (ex: FY2024) or leave blank
),

-- 1. Get all Voyager circs and find the first checkout date of each item record 

voycircs AS 
(SELECT
	cta.item_id::varchar AS item_hrid,
	min (cta.charge_date::date) AS first_checkout
	
	FROM vger.circ_trans_archive AS cta
	group by cta.item_id::varchar
	
),

-- 2. Get all Folio circs and get the first checkout date for each item record

foliocircs AS
(SELECT 
	 li.hrid AS item_hrid,
	 MIN (li.loan_date::date) first_checkout
	
	 FROM folio_reporting.loans_items AS li
	 GROUP BY li.hrid
),

-- 3. Join the Voyager circs to the Folio circs

allcircs AS
(SELECT 
	voycircs.item_hrid as voy_item_hrid,
	foliocircs.item_hrid as folio_item_hrid,
	voycircs.first_checkout as voy_first_checkout,
	foliocircs.first_checkout as folio_first_checkout

	FROM voycircs 
	FULL JOIN foliocircs 
	ON voycircs.item_hrid = foliocircs.item_hrid
	
WHERE (voycircs.item_hrid IS NOT NULL OR foliocircs.item_hrid IS NOT NULL)	
),

-- 4. Get the first checkout for each item record in the joined sets by applying the coalesce function for item_hrid and first checkout date

first_cko AS 
(SELECT
	COALESCE (allcircs.voy_item_hrid, allcircs.folio_item_hrid) AS item_hrid,
	COALESCE (allcircs.voy_first_checkout, allcircs.folio_first_checkout) AS first_checkout
	
	FROM allcircs 
),

-- 5. Get the purchase order lines where the "requester" field is not null

folio_req AS
(SELECT
	CASE WHEN date_part ('month', pol.metadata__created_date::date) < '7' THEN CONCAT ('FY', date_part ('year',pol.metadata__created_date::date)) 
		ELSE CONCAT ('FY', date_part ('year', pol.metadata__created_date::date)+1) END AS fiscal_year_requested,
	pol.metadata__created_date::date AS pol_create_date,
	pol.po_line_number,
	poi.pol_instance_hrid AS instance_hrid,
	poi.title,
	' - ' AS voyager_order_type,
	pol.order_format AS folio_order_format,
	STRING_AGG (DISTINCT SUBSTRING (ip.date_of_publication,'\d{4}'),' | ') AS pub_date,
	pol.requester,
	poll.pol_location_name AS location_name,
	pol.receipt_status,
	ilfd.finance_fund_code,
	ilfd.fund_name,
	'Folio' AS source

FROM po_lines AS pol
	LEFT JOIN folio_reporting.po_lines_locations AS poll 
	ON pol.id = poll.pol_id
	
	LEFT JOIN folio_reporting.po_instance AS poi 
	ON pol.id::uuid = poi.po_line_id::uuid
	
	LEFT JOIN folio_reporting.instance_publication AS ip 
	ON poi.pol_instance_hrid = ip.instance_hrid
	
	LEFT JOIN invoice_lines AS invl 
	ON pol.id = invl.po_line_id
	
	LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd 
	ON invl.id = ilfd.invoice_line_id	

WHERE pol.requester IS NOT NULL 

GROUP BY 
	CASE WHEN date_part ('month', pol.metadata__created_date::date) < '7' THEN CONCAT ('FY', date_part ('year',pol.metadata__created_date::date)) 
		ELSE CONCAT ('FY', date_part ('year', pol.metadata__created_date::date)+1) END,
	pol.metadata__created_date::date,
	pol.po_line_number,
	poi.pol_instance_hrid,
	poi.title,
	pol.order_format,
	pol.requester,
	poll.pol_location_name,
	pol.receipt_status,
	ilfd.finance_fund_code,
	ilfd.fund_name
),

-- 6. Get the Voyager line items where the "requestor" field is not null

voy_req AS

(SELECT DISTINCT
	CASE WHEN date_part ('month', li.create_date::date) < '7' THEN CONCAT ('FY', date_part ('year',li.create_date::date)) 
		ELSE CONCAT ('FY', date_part ('year', li.create_date::date)+1) END AS fiscal_year_requested,
	li.create_date::date AS pol_create_date,
	li.line_item_id::varchar AS po_line_number,
	li.bib_id::VARCHAR AS instance_hrid,
	bt.title,
	STRING_AGG (distinct po_type.po_type_desc,' | ') AS voyager_order_type,
	' - ' AS folio_order_format,
	STRING_AGG (DISTINCT bt.begin_pub_date,' | ') AS pub_date,
	STRING_AGG (DISTINCT li.requestor,' | ') AS requester,
	location.location_name,
	STRING_AGG (DISTINCT po_status.po_status_desc,' | ') AS receipt_status,	
	STRING_AGG (DISTINCT fund.fund_code,' | ') AS finance_fund_code,
	STRING_AGG (DISTINCT fund.fund_name,' | ') AS fund_name,
	'Voyager' AS source

FROM vger.line_item AS li	
	LEFT JOIN vger.bib_text AS bt 
	ON li.bib_id = bt.bib_id
	
	LEFT JOIN vger.line_item_copy AS lic 
	ON li.line_item_id = lic.line_item_id
	
	LEFT JOIN vger.fund 
	ON lic.use_fund = fund.fund_id
		AND lic.use_ledger = fund.ledger_id
	
	LEFT JOIN vger.line_item_notes AS lin 
	ON li.line_item_id = lin.line_item_id 
		AND li.po_id = lin.po_id
		
	LEFT JOIN vger.purchase_order AS po 
	ON li.po_id = po.po_id 
	
	LEFT JOIN vger.po_type 
	ON po.po_type = po_type.po_type
	
	LEFT JOIN vger.po_status 
	ON po.po_status = po_status.po_status
	
	LEFT JOIN vger.bib_mfhd AS bm 
	ON bt.bib_id = bm.bib_id
	
	LEFT JOIN vger.mfhd_master AS mm 
	ON bm.mfhd_id = mm.mfhd_id
	
	LEFT JOIN vger.line_item_copy_status AS lics 
	ON lic.line_item_id = lics.line_item_id 
		AND bm.mfhd_id = lics.mfhd_id
		AND lics.mfhd_id = mm.mfhd_id
	
	LEFT JOIN vger.location 
	ON lic.location_id = location.location_id
	
WHERE li.requestor IS NOT NULL
	AND mm.suppress_in_opac = 'N'
	
GROUP BY
	bt.title,
	li.bib_id::VARCHAR,
	location.location_name,
	li.create_date,
	li.line_item_id::varchar,
	CASE WHEN date_part ('month', li.create_date::date) < '7' THEN CONCAT ('FY', date_part ('year',li.create_date::date)) 
		ELSE CONCAT ('FY', date_part ('year', li.create_date::date)+1) END	
),

-- 7. Combine the Folio requests and the Voyager requests

combo AS
(SELECT 
	folio_req.* 
	FROM folio_req 
UNION
	SELECT voy_req.*
	FROM voy_req

ORDER BY fiscal_year_requested, title
),

-- 8. From the results above, join to holdings and item tables, and get the first checkout of the items by joining to the "first_cko" subquery

combo2 AS
(SELECT
	combo.fiscal_year_requested,
	MIN (combo.pol_create_date) AS min_pol_create_date,
	combo.po_line_number,
	combo.instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	first_cko.first_checkout,
	CASE WHEN 
		first_cko.first_checkout < MIN (combo.pol_create_date) 
		THEN 0 
		ELSE first_cko.first_checkout - MIN (combo.pol_create_date) END AS days_til_first_checkout,
	combo.title,
	combo.folio_order_format,
	combo.voyager_order_type,
	STRING_AGG (DISTINCT combo.pub_date,' | ') AS pub_date,
	combo.requester,
	combo.location_name,
	combo.receipt_status,	
	combo.finance_fund_code,
	combo.fund_name,
	combo.source
	
FROM combo 
	LEFT JOIN inventory_instances AS ii 
	ON combo.instance_hrid = ii.hrid 
	
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	LEFT JOIN folio_reporting.item_ext AS ie 
	ON he.holdings_id = ie.holdings_record_id 
	
	LEFT JOIN first_cko 
	ON ie.item_hrid = first_cko.item_hrid

WHERE combo.location_name = he.permanent_location_name 

GROUP BY 
	combo.fiscal_year_requested,
	combo.po_line_number,
	combo.instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	first_cko.first_checkout,
	combo.title,
	combo.folio_order_format,
	combo.voyager_order_type,
	combo.requester,
	combo.location_name,
	combo.receipt_status,	
	combo.finance_fund_code,
	combo.fund_name,
	combo.source
)

-- 9. Make the final cut of requested items by selecting Requester field entries that have certain terms and not others. Do not show holdings or item hrids
-- because purchase orders are not created at the item level, and there is no way to eliminate extraneous item records that are linked to instance and holdings

SELECT DISTINCT
	combo2.fiscal_year_requested,
	combo2.min_pol_create_date,
	combo2.po_line_number,
	combo2.instance_hrid,
	--combo2.holdings_hrid,
	--combo2.item_hrid,
	MIN (combo2.first_checkout) AS first_checkout,
	MIN (combo2.days_til_first_checkout) AS days_til_first_checkout,
	combo2.title,
	combo2.folio_order_format,
	combo2.voyager_order_type,
	combo2.pub_date,
	combo2.requester,
	combo2.location_name,
	combo2.receipt_status,	
	combo2.finance_fund_code,
	combo2.fund_name,
	combo2.source
	
FROM combo2

WHERE (combo2.fiscal_year_requested >= (SELECT start_fiscal_year_filter FROM parameters) OR (SELECT start_fiscal_year_filter FROM parameters) = '')
	AND (combo2.fiscal_year_requested <= (SELECT end_fiscal_year_filter FROM parameters) OR (SELECT end_fiscal_year_filter FROM parameters)= '')
	AND combo2.requester SIMILAR TO '%(REQ|Dr|Prof|@|req|notify|RES|pickup|Pickup|Pick up|pick up)%'
	AND combo2.requester NOT SIMILAR TO '%(no request|n/a|na|no req|No requestor|No requester)%'
	
GROUP BY 
	combo2.fiscal_year_requested,
	combo2.min_pol_create_date,
	combo2.po_line_number,
	combo2.instance_hrid,
	--combo2.holdings_hrid,
	--combo2.item_hrid,
	combo2.title,
	combo2.folio_order_format,
	combo2.voyager_order_type,
	combo2.pub_date,
	combo2.requester,
	combo2.location_name,
	combo2.receipt_status,	
	combo2.finance_fund_code,
	combo2.fund_name,
	combo2.source
	
ORDER BY combo2.fiscal_year_requested, combo2.title
;
