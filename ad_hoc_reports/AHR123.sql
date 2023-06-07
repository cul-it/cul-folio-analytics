
--AHR123
--Asia items difficult to replace
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 6/07/2023


/*This query finds all items in Kroch Library Asia locations and shows the OCLC number, year of publication and item status. 
-- The results will be matched by OCLC number to holdings at other institutions, as part of project to identify items that are difficult to replace.
-- Items that are uniquely held at Cornell or that are otherwise designated as high-risk will be sent to the Annex.*/


-- 1. Get year of publication

WITH pubs AS 
(SELECT 
                sm.instance_hrid,
                substring (sm.CONTENT,8,4) AS year_of_publication
                
                FROM srs_marctab AS sm 
                WHERE sm.field = '008'
),

-- 2. Get OCLC numbers

oclc AS 
(SELECT 
                instid.instance_hrid,
                instid.identifier,
                substring (instid.identifier,'\d{1,}') AS oclc_number
                
                FROM folio_reporting.instance_identifiers AS instid
                WHERE instid.identifier_type_name = 'OCLC'
)

-- 3. Get items in Kroch Library Asia collections and join to year of publication and OCLC numbers

SELECT distinct
                ii.hrid AS instance_hrid,
                he.holdings_hrid,
                invitems.hrid AS item_hrid,
                invitems.barcode,
                string_agg (DISTINCT oclc.oclc_number,' | ') AS oclc_number,
                ll.library_name,
                ll.location_name,
                ii.title,
                string_agg (DISTINCT pubs.year_of_publication,' | ') AS year_of_publication,
                string_agg (DISTINCT il.LANGUAGE,' | ') AS primary_language,
                trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
                                CASE WHEN invitems.copy_number >'1' THEN concat ('c.',invitems.copy_number) ELSE '' END)) AS whole_call_number,
                string_agg (DISTINCT he.type_name,' | ') AS holdings_type_name,
                imt.name AS material_type_name,
                invitems.status__name AS item_status_name,

                invitems.status__date::date AS item_status_date,
                invitems.effective_shelving_order COLLATE "C"

FROM 
                inventory_instances AS ii 
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id 
                
                LEFT JOIN inventory_items AS invitems 
                ON he.holdings_id = invitems.holdings_record_id
                
                LEFT JOIN inventory_material_types imt 
                ON invitems.material_type_id = imt.id
                
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id 
                
                LEFT JOIN folio_reporting.instance_languages AS il 
                ON ii.id = il.instance_id 
                
                LEFT JOIN pubs
                ON ii.hrid = pubs.instance_hrid 
                
                LEFT JOIN oclc 
                ON ii.hrid = oclc.instance_hrid

WHERE 
                ll.library_name = 'Kroch Library Asia'
                AND (he.discovery_suppress = 'False' or he.discovery_suppress is null)
                AND (il.language_ordinality = 1 OR il.language_ordinality IS NULL)

GROUP BY 
                ii.hrid,
                he.holdings_hrid,
                invitems.hrid,
                invitems.barcode,
                ll.library_name,
                ll.location_name,
                ii.title,
                trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
                                CASE WHEN invitems.copy_number >'1' THEN concat ('c.',invitems.copy_number) ELSE '' END)),
                imt.name,
                invitems.status__name,
                invitems.status__date::date,
                invitems.effective_shelving_order COLLATE "C"
                
ORDER BY ll.location_name, invitems.effective_shelving_order COLLATE "C"
;

