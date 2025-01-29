-- MCR194
-- checkouts and checkins by service point, material type, collection type and date range
--Query writer: Joanne Leary (jl41)
--Query posted on: 1/29/25

WITH parameters as -- (required)
(SELECT
        '2024-07-01' AS begin_date, -- enter date ranges in the format "yyyy-mm-dd"
        '2025-07-01' AS end_date, -- the end date will not be including in the results
        'Math Service Point'::VARCHAR AS service_point_name -- enter a service point name
),

recs AS 
(SELECT 
	acl.id AS action_id,
	acl.jsonb#>>'{loan,id}' AS loan_id,
	acl.jsonb#>>'{loan,itemId}' AS item_id,
	item.jsonb#>>'{hrid}' AS item_hrid,
	material_type__t.name AS material_type_name,
	acl.jsonb#>>'{loan,action}' AS action,
	(acl.jsonb#>>'{createdDate}')::DATE AS action_date,
	isp.name AS checkout_service_point_name,
	isp2.name AS checkin_service_point_name,
	users.jsonb #>> '{personal, lastName}' AS source_last_name,
	users.jsonb #>> '{personal, firstName}' AS source_first_name

FROM folio_circulation.audit_loan AS acl
	LEFT JOIN folio_inventory.service_point__t AS isp
	ON (acl.jsonb#>>'{loan,checkoutServicePointId}')::UUID = isp.id
	
	LEFT JOIN folio_inventory.service_point__t AS isp2
	ON (acl.jsonb#>>'{loan,checkinServicePointId}')::UUID = isp2.id
	
	LEFT JOIN folio_users.users 
	ON (acl.jsonb#>>'{loan,metadata,updatedByUserId}')::UUID = users.id
	
	LEFT JOIN folio_inventory.item 
	ON (acl.jsonb#>>'{loan,itemId}')::UUID = item.id
	
	LEFT JOIN folio_inventory.material_type__t 
	ON (item.jsonb#>>'{materialTypeId}')::UUID = material_type__t.id

WHERE acl.jsonb#>>'{loan,action}' IN ('checkedin','checkedout')
	AND users.jsonb #>>'{personal, lastName}' not ilike any (array ['app%','admin%','fs%','system%'])
	AND (acl.jsonb#>>'{createdDate}')::DATE >=  (SELECT begin_date FROM parameters)::DATE AND (acl.jsonb#>>'{createdDate}')::DATE < (SELECT end_date FROM parameters)::DATE 
	AND (isp.name = (SELECT service_point_name FROM parameters) or isp2.name = (SELECT service_point_name FROM parameters))
)

SELECT 
	current_date::DATE AS todays_date,
	(SELECT service_point_name FROM parameters) AS service_point_name,
	CONCAT ((SELECT begin_date FROM parameters)::DATE,' - ', (SELECT end_date FROM parameters)) AS date_range,
	DATE_PART ('Year',recs.action_date)::VARCHAR AS "year",
	DATE_PART ('month',recs.action_date) AS month_number,
    TO_CHAR (recs.action_date,'Mon') AS "month",
	CASE WHEN recs.actiON = 'checkedout' THEN 'Checkout' ELSE 'Checkin' END AS action_type,
	recs.material_type_name,
	CASE
        WHEN recs.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
        WHEN recs.material_type_name = 'Laptop' THEN 'Laptop'
        WHEN recs.material_type_name IS NULL THEN 'Equipment'
        WHEN recs.material_type_name ILIKE 'BD%' OR recs.material_type_name ILIKE 'ILL%' THEN 'ILLBD'
    ELSE 'Regular collection' END AS collection_type,
	COUNT (recs.action_id)

FROM recs 

GROUP BY 
	recs.action, year, month, month_number, material_type_name, collection_type
ORDER BY 
	year, month_number
;
