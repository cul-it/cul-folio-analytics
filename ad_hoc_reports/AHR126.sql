--AHR126
--ILR Inventory Query
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 6/07/2023


--This is an ad-hoc query for ILR that finds all items in a given call number range and shows various bibliographic fields (contributors, year of publication, size/pagination) and item status. It does not show circs. It will be re-used with different call number ranges as needed, since ILR will be doing an ongoing inventory.
-- This is an inventory query that finds all items in call number range HD1 - HD30 at ILR


WITH field_300 AS 
                (SELECT 
                                sm.instance_hrid,
                                string_agg (DISTINCT sm.CONTENT,' | ') AS size_pagination
                FROM srs_marctab AS sm
                WHERE sm.field = '300'
                GROUP BY sm.instance_hrid 
),

pubs AS 
(SELECT
                                sm.instance_hrid,
                                substring(sm.CONTENT,8,4) AS year_of_publication
                FROM srs_marctab AS sm 
                WHERE sm.field = '008'
),

contrib AS 
(SELECT 
                                ic.instance_hrid,
                                string_agg (DISTINCT ic.contributor_name,' | ') AS contributors

                FROM folio_reporting.instance_contributors AS ic              
                GROUP BY ic.instance_hrid
)

SELECT 
                ll.library_name,
                ll.location_name,
                ii.hrid AS instance_hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ii.title,
                contrib.contributors,
                --contrib.contributors,
                trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology, 
                                CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)) AS whole_call_number,
                ie.barcode,
                pubs.year_of_publication,
                ie.material_type_name,
                ie.status_name AS item_status_name,
                to_char (ie.status_date::date,'mm/dd/yyyy') AS item_status_date,
                substring (he.call_number, '^[A-Za-z]{1,3}') AS lc_class,
                trim (TRAILING '.' FROM substring (he.call_number, '\d{1,}\.{0,}\d{0,}')) AS lc_class_number,
                field_300.size_pagination

FROM inventory_instances AS ii 
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id 
                
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id 
                
                LEFT JOIN inventory_items AS invitems 
                ON he.holdings_id = invitems.holdings_record_id 
                
                LEFT JOIN folio_reporting.item_ext AS ie 
                ON invitems.id = ie.item_id 
                
                LEFT JOIN field_300 
                ON ii.hrid = field_300.instance_hrid
                
                LEFT JOIN pubs 
                ON ii.hrid = pubs.instance_hrid
                
                LEFT JOIN contrib
                ON ii.hrid = contrib.instance_hrid

WHERE 
                ll.library_name = 'ILR Library'
                AND substring (he.call_number, '^[A-Za-z]{1,3}') = 'HD'
                AND trim (TRAILING '.' FROM substring (he.call_number, '\d{1,}\.{0,}\d{0,}'))::NUMERIC >=1 
                AND trim (TRAILING '.' FROM substring (he.call_number, '\d{1,}\.{0,}\d{0,}'))::NUMERIC <=30
                AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)

GROUP BY 
                ll.library_name,
                ll.location_name,
                ii.hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ii.title,
                contrib.contributors,
                trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology, 
                                CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)),
                ie.barcode,
                pubs.year_of_publication,
                ie.material_type_name,
                ie.status_name,
                to_char (ie.status_date::date,'mm/dd/yyyy'),
                substring (he.call_number, '^[A-Za-z]{1,3}'),
                trim (TRAILING '.' FROM substring (he.call_number, '\d{1,}\.{0,}\d{0,}')),
                field_300.size_pagination,
                invitems.effective_shelving_order
                
ORDER BY ll.library_name, ll.location_name, invitems.effective_shelving_order COLLATE "C"
;
