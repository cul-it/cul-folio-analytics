--CR204
--missing_lost_claimed_returned

WITH parameters AS 
(SELECT 
'%%'::VARCHAR AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc. or leave blank for all libraries. See list of libraries at https://confluence.cornell.edu/display/folioreporting/Locations
),

field_300 AS 
(SELECT 
sm.instance_hrid,
string_agg (DISTINCT sm.content,' | ') AS pagination_size

FROM srs_marctab AS sm
WHERE sm.field = '300'
GROUP BY sm.instance_hrid 
),

recs AS 
(SELECT
ll.library_name,
he.permanent_location_name,
instext.title,
TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, ii.enumeration, ii.chronology,
CASE WHEN ii.copy_number >'1' THEN concat ('c.', ii.copy_number) ELSE '' END)) AS whole_call_number,
ii.barcode,
itemext.status_name,
itemext.status_date::DATE AS item_status_date, 
CASE WHEN ii.last_check_in__date_time IS NULL THEN NULL 
ELSE TO_CHAR (ii.last_check_in__date_time::TIMESTAMP, 'mm/dd/yyyy hh:mi am') END AS last_folio_check_in,
MAX (TO_CHAR (cta.discharge_date::TIMESTAMP,'mm/dd/yyyy hh:mi am')) AS last_voyager_check_in,
isp.name AS last_folio_check_in_service_point,
field_300.pagination_size,
STRING_AGG (DISTINCT itemnotes.note,' | ') AS item_note,
itemext.material_type_name,
he.type_name,
instext.instance_hrid,
he.holdings_hrid,
itemext.item_hrid,
instext.discovery_suppress AS instance_suppress,
he.discovery_suppress AS holdings_suppress,
itemext.item_id,
ii.effective_shelving_order

FROM folio_reporting.instance_ext AS instext
LEFT JOIN folio_reporting.holdings_ext AS he 
ON instext.instance_id = he.instance_id

LEFT JOIN folio_reporting.locations_libraries AS ll 
ON he.permanent_location_id = ll.location_id

LEFT JOIN folio_reporting.item_ext AS itemext 
ON he.holdings_id = itemext.holdings_record_id

LEFT JOIN inventory_items AS ii 
ON itemext.item_id = ii.id

LEFT JOIN vger.circ_trans_archive AS cta 
ON ii.hrid::VARCHAR = cta.item_id::VARCHAR

LEFT JOIN inventory_service_points AS isp 
ON ii.last_check_in__service_point_id = isp.id

LEFT JOIN folio_reporting.item_notes AS itemnotes
ON itemext.item_id = itemnotes.item_id

LEFT JOIN field_300 --srs_marctab AS srs 
ON instext.instance_hrid = field_300.instance_hrid

WHERE itemext.status_name SIMILAR TO '%(issing|ost|laim|navail)%'

GROUP BY 
ll.library_name,
he.permanent_location_name,
instext.title,
he.call_number_prefix,
he.call_number,
he.call_number_suffix,
ii.enumeration,
ii.chronology,
ii.copy_number,
ii.barcode,
instext.discovery_suppress,
he.discovery_suppress,
field_300.pagination_size,
instext.instance_hrid,
he.holdings_hrid,
itemext.item_hrid,
itemext.item_id,
itemext.material_type_name,
he.type_name,
itemext.status_name,
itemext.status_date::date,
ii.last_check_in__date_time,
isp.name,
ii.effective_shelving_order
),

loan1 AS 
(SELECT 
recs.item_id,
recs.item_hrid,
MAX (li.loan_date) AS most_recent_loan
FROM recs 
LEFT JOIN folio_reporting.loans_items AS li 
ON recs.item_id = li.item_id 

GROUP BY 
recs.item_hrid, recs.item_id
),

loan2 AS 
(SELECT 
loan1.item_id,
loan1.item_hrid,
loan1.most_recent_loan, 
uu.personal__last_name AS user_last_name,
uu.personal__first_name AS user_first_name,
uu.active AS patron_status

FROM loan1 
LEFT JOIN folio_reporting.loans_items AS li 
ON loan1.most_recent_loan = li.loan_date 
AND loan1.item_id = li.item_id

LEFT JOIN user_users AS uu 
ON li.user_id = uu.id
)

SELECT 
TO_CHAR (CURRENT_DATE::date,'mm/dd/yyyy') AS todays_date,
recs.library_name,
recs.permanent_location_name,
recs.title,
recs.whole_call_number,
recs.barcode,
recs.status_name,
recs.item_status_date, 
COALESCE (recs.last_folio_check_in, recs.last_voyager_check_in,'-') AS last_check_in_date, 
COALESCE (recs.last_folio_check_in_service_point,location.Location_name,'-') AS last_check_in_location, 
recs.pagination_size,
recs.item_note,
recs.material_type_name,
recs.type_name as holdings_type_name,
recs.instance_hrid,
recs.holdings_hrid,
recs.item_hrid,
recs.instance_suppress,
recs.holdings_suppress,
loan2.user_last_name,
loan2.user_first_name,
CASE WHEN loan2.patron_status = 'True' THEN 'Active' WHEN loan2.patron_status = 'False' THEN 'Expired' ELSE ' - ' END AS patron_status,
to_char (loan2.most_recent_loan::timestamp,'mm/dd/yyyy hh:mi am') AS most_recent_loan,
recs.effective_shelving_order COLLATE "C"

FROM recs 
LEFT JOIN vger.circ_trans_archive AS cta 
ON recs.last_voyager_check_in = TO_CHAR (cta.discharge_date::TIMESTAMP,'mm/dd/yyyy hh:mi am') 
AND recs.item_hrid = cta.item_id::VARCHAR

LEFT JOIN vger.location 
ON cta.discharge_location = location.location_id

LEFT JOIN loan2 
ON recs.item_hrid = loan2.item_hrid

WHERE (recs.library_name ilike (SELECT owning_library_name_filter FROM parameters) OR (SELECT owning_library_name_filter FROM parameters) = '')

ORDER BY library_name, permanent_location_name, effective_shelving_order COLLATE "C"
;




