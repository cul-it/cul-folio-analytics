--AHR122
--Olin_childrens_lit_LC_class_PZ

WITH pubyear AS 
(SELECT 
                sm.instance_hrid,
                substring (sm.CONTENT,8,4) AS year_of_publication
                FROM srs_marctab AS sm 
                WHERE sm.field = '008'
),

foliocircs AS 
(SELECT 
                li.item_id,
                count (li.loan_id) AS folio_circs
                FROM folio_reporting.loans_items AS li 
                GROUP BY li.item_id
)

SELECT 
                ll.library_name,
                ll.location_name,
                ii.title,
                string_agg (DISTINCT ic.contributor_name,' | ') AS author,
                pubyear.year_of_publication,
                CASE WHEN item.create_date::date < ie.created_date::date THEN item.create_date::date 
                                ELSE ie.created_date::date END AS date_added_to_collection,
                CASE WHEN CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) ilike '%+++%' THEN '+++'
                                WHEN CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) ilike '%++%' THEN '++'
                                WHEN CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) ilike '%+%' THEN '+' 
                                ELSE ' - ' END AS "size",
                TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
                CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)) AS whole_call_number,
                ii.hrid AS instance_hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ie.barcode,
                ie.material_type_name,
                ie.status_name AS item_status_name,
                ie.status_date::date AS item_status_date,
                CASE WHEN item.historical_charges IS NULL THEN 0 ELSE item.historical_charges END AS voyager_circs,
                CASE WHEN foliocircs.folio_circs IS NULL THEN 0 ELSE foliocircs.folio_circs END AS folio_circs,
                CASE WHEN item.historical_charges IS NULL THEN 0 ELSE item.historical_charges END + CASE WHEN foliocircs.folio_circs IS NULL THEN 0 
                                ELSE foliocircs.folio_circs END AS total_circs

FROM inventory_instances AS ii 
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id 
                
                LEFT JOIN folio_reporting.instance_contributors AS ic 
                ON ii.id = ic.instance_id
                
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id
                
                LEFT JOIN folio_reporting.item_ext AS ie 
                ON he.holdings_id = ie.holdings_record_id
                
                LEFT JOIN inventory_items AS invitems 
                ON ie.item_id = invitems.id
                
                LEFT JOIN foliocircs 
                ON ie.item_id = foliocircs.item_id
                
                LEFT JOIN vger.item 
                ON ie.item_hrid = item.item_id::varchar
                
                LEFT JOIN pubyear 
                ON ii.hrid = pubyear.instance_hrid

WHERE 
                ll.library_name = 'Olin Library'
                AND substring (he.call_number,'[A-Za-z]{2}')= 'PZ'
                AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
                AND ie.item_id IS NOT NULL 
                AND he.call_number NOT ILIKE '%Icelandic%'
                AND he.call_number_prefix NOT ILIKE '%Icelandic%'

GROUP BY 
                ll.library_name,
                ll.location_name,
                ii.title,
                pubyear.year_of_publication,
                ie.created_date::date,
                item.create_date::date,
                he.call_number_prefix,
                he.call_number,
                he.call_number_suffix,
                ie.enumeration,
                ie.chronology,
                ie.copy_number,
                ii.hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ie.barcode,
                ie.material_type_name,
                ie.status_name,
                ie.status_date::date,
                item.historical_charges,
                foliocircs.folio_circs,
                invitems.effective_shelving_order COLLATE "C"

ORDER BY "size", invitems.effective_shelving_order COLLATE "C"
;
