-- MCR204
-- missing_lost_claimed_returned
--This query finds items whose status is missing, lost, or claimed returned.
--Changes from the LDP query: no Voyager data included. Also, extracted the 300 field separately and the most recent discharge and discharge location are from the from folio_inventory.item__ json blob; repositioned library filter to end of query.

--Original query writer: Joanne Leary (jl41)
--Query ported to Metadb by Joanne leary (jl41)
--Query reviewed by Linda Miller (lm15) and Vandana Shah (vp25)
--Query posted on 6/7/24


WITH parameters AS 
(
SELECT 
''::VARCHAR AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc. or leave blank for all libraries. See list of libraries at https://confluence.cornell.edu/display/folioreporting/Locations
),


most_rec_discharge AS  
(SELECT 
        item__.id,
        jsonb_extract_path_text (item__.jsonb,'hrid') AS item_hrid,
        jsonb_extract_path_text (item__.jsonb,'lastCheckIn','dateTime')::timestamp AS most_recent_discharge,
        service_point__t.name AS most_recent_discharge_location

FROM folio_inventory.item__ 
        LEFT JOIN folio_inventory.service_point__t 
        ON jsonb_extract_path_text (item__.jsonb,'lastCheckIn','servicePointId')::UUID = service_point__t.id
),

field_300 AS 
(SELECT
        srs.instance_hrid,
        STRING_AGG (DISTINCT srs."content",' | ') AS pagination_size

FROM folio_source_record.marc__t AS srs

WHERE srs.field = '300'
GROUP BY srs.instance_hrid
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
        most_rec_discharge.most_recent_discharge,
        most_rec_discharge.most_recent_discharge_location,
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

FROM folio_derived.instance_ext AS instext 
        LEFT JOIN folio_derived.holdings_ext AS he  
        ON instext.instance_id = he.instance_id 
        
        LEFT JOIN folio_derived.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id 
        
        LEFT JOIN folio_derived.item_ext AS itemext 
        ON he.holdings_id = itemext.holdings_record_id 
        
        LEFT JOIN folio_inventory.item__t AS ii 
        ON itemext.item_id = ii.id 
        
        LEFT JOIN most_rec_discharge
        ON ii.id = most_rec_discharge.id
        
        LEFT JOIN folio_derived.item_notes AS itemnotes 
        ON itemext.item_id = itemnotes.item_id 
        
        LEFT JOIN field_300 
        ON instext.instance_hrid = field_300.instance_hrid

WHERE 
itemext.status_name SIMILAR TO '%(issing|ost|laim|navail)%'

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
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        itemext.item_id,
        itemext.material_type_name,
        he.type_name,
        itemext.status_name,
        itemext.status_date::date,
        most_rec_discharge.most_recent_discharge,
        most_rec_discharge.most_recent_discharge_location,
        field_300.pagination_size,
        ii.effective_shelving_order
),

loan1 AS 
(SELECT 
        recs.item_id,
        recs.item_hrid,
        MAX (li.loan_date) AS most_recent_loan

        FROM recs 
        LEFT JOIN folio_derived.loans_items AS li 
        ON recs.item_id = li.item_id 
        
        GROUP BY 
        recs.item_hrid, recs.item_id
),

loan2 AS 
(SELECT 
        loan1.item_id,
        loan1.item_hrid,
        loan1.most_recent_loan, 
        ug.user_last_name,
        ug.user_first_name,
        uu.active AS patron_status
        
        FROM loan1 
        LEFT JOIN folio_derived.loans_items AS li 
        ON loan1.most_recent_loan = li.loan_date 
                AND loan1.item_id = li.item_id
        
        LEFT JOIN folio_users.users__t AS uu 
        ON li.user_id = uu.id
        
        LEFT JOIN folio_derived.users_groups AS ug
        ON uu.id = ug.user_id
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
recs.most_recent_discharge::date,
recs.most_recent_discharge_location,
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
LEFT JOIN loan2 
ON recs.item_hrid = loan2.item_hrid

WHERE (recs.library_name = (SELECT owning_library_name_filter FROM parameters) OR (SELECT owning_library_name_filter FROM parameters) = '')

ORDER BY library_name, permanent_location_name, effective_shelving_order COLLATE "C"
;
