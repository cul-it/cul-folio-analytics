-AHR128
--Olin and Kroch microfilm guides
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 6/22/2023

-- This query finds microfilm guides in Olin and Kroch libraries.

WITH recs AS 
(SELECT 
                ll.library_name,
                ii.title,
                he.permanent_location_name,
                trim (concat (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,' ',
                CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)) AS whole_call_number,
                string_agg (DISTINCT hn.note, ' | ') AS holdings_notes,
                ii.id AS instance_id,
                ii.hrid AS instance_hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ie.barcode,
                ie.status_name

FROM inventory_instances AS ii 
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id
                
                LEFT JOIN folio_reporting.holdings_notes AS hn 
                ON he.holdings_id = hn.holdings_id
                
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id 
                
                LEFT JOIN folio_reporting.item_ext AS ie 
                ON he.holdings_id = ie.holdings_record_id

WHERE 
                ll.library_name in ('Olin Library','Kroch Library Asia')
                AND he.call_number ILIKE '%film%'
                AND (ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL) 
                AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
                
GROUP BY 
                ll.library_name,
                ii.title,
                he.permanent_location_name,
                trim (concat (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,' ',
                CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)),
                ii.id,
                ii.hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ie.barcode,
                ie.status_name
),

field300 AS 
(SELECT 
                recs.instance_hrid,
                string_agg (DISTINCT sm.CONTENT,' | ') AS field300_content
                
                FROM recs 
                LEFT JOIN srs_marctab AS sm 
                ON recs.instance_hrid = sm.instance_hrid 
                
                WHERE sm.field = '300' 
                GROUP BY recs.instance_hrid
),

shelved_in_stacks AS 
(SELECT 
                recs.instance_id,
                recs.instance_hrid,
                ie.item_hrid,
                ll.library_name,
                he.permanent_location_name,
                he.holdings_hrid,
                he.call_number,
                ie.barcode,
                string_agg (DISTINCT hn.note,' | ') AS shelved_in_stacks_holdings_notes,
                string_agg (DISTINCT hsi.statement,' | ') AS shelved_in_stacks_statements

FROM recs 
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON recs.instance_id = he.instance_id 
                
                LEFT JOIN folio_reporting.holdings_notes AS hn 
                ON he.holdings_hrid = hn.holdings_hrid
                
                LEFT JOIN folio_reporting.holdings_statements_indexes AS hsi 
                ON he.holdings_id = hsi.holdings_id
                
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id
                
                LEFT JOIN folio_reporting.item_ext AS ie 
                ON he.holdings_id = ie.holdings_record_id
                
WHERE 
                (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
                
                AND 
                (((ll.library_name = 'Kroch Library Asia'
                                AND he.call_number NOT ILIKE '%film%'
                                AND hsi.STATEMENT ILIKE '%guide%')
                
                OR
                
                (ll.library_name ='Olin Library'
                                AND he.call_number NOT ILIKE '%film%'
                                AND hn.note ILIKE '%guide%')
                ))
                
GROUP BY ll.library_name, recs.instance_id, recs.instance_hrid, he.permanent_location_name, he.holdings_hrid, ie.item_hrid, he.call_number, ie.barcode
)

SELECT
                recs.library_name,
                recs.permanent_location_name,
                recs.title,
                recs.instance_hrid,
                recs.holdings_hrid,
                recs.item_hrid,
                substring (recs.whole_call_number,'\d{1,}')::numeric AS film_number,
                recs.whole_call_number,
                recs.holdings_notes,
                recs.barcode,
                recs.status_name,
                field300.field300_content,
                shelved_in_stacks.holdings_hrid AS shelved_in_stacks_holdings_hrid,
                shelved_in_stacks.item_hrid AS shelved_in_stacks_item_hrid,
                shelved_in_stacks.permanent_location_name AS shelved_in_stacks_perm_loc_name,
                shelved_in_stacks.call_number AS shelved_in_stacks_call_number,
                shelved_in_stacks.shelved_in_stacks_holdings_notes,    
                shelved_in_stacks.shelved_in_stacks_statements,
                shelved_in_stacks.barcode AS shelved_in_stacks_barcode
                
FROM recs 
                LEFT JOIN field300 
                ON recs.instance_hrid = field300.instance_hrid
                
                LEFT JOIN shelved_in_stacks
                ON recs.instance_hrid = shelved_in_stacks.instance_hrid
                
WHERE recs.whole_call_number ILIKE '%guide%'

ORDER BY library_name, permanent_location_name, film_number, recs.whole_call_number
;
