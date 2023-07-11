-AHR128
--Olin and Kroch microform guides
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 7/11/2023

-- This query finds microform guides in Olin and Kroch libraries.

WITH recs AS 
(SELECT 
       ll.library_name,
       ii.title,
       he.permanent_location_name,
       trim (concat (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,' ',
       CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)) AS whole_call_number,
       string_agg (DISTINCT hn.note, ' | ') AS holdings_notes,
       string_agg (DISTINCT hs.STATEMENT,' | ') AS holdings_statements,
       string_agg (DISTINCT hss.STATEMENT, ' | ') AS supplements_statements,
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
       
       LEFT JOIN folio_reporting.holdings_statements AS hs
       ON he.holdings_id = hs.holdings_id
       
       LEFT JOIN folio_reporting.holdings_statements_supplements hss 
       ON he.holdings_id = hss.holdings_id
       
       LEFT JOIN folio_reporting.locations_libraries AS ll 
       ON he.permanent_location_id = ll.location_id 
       
       LEFT JOIN folio_reporting.item_ext AS ie 
       ON he.holdings_id = ie.holdings_record_id

WHERE 
       ll.library_name in ('Olin Library','Kroch Library Asia')
       AND concat (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix) SIMILAR TO '%(fiche|film|Fiche|Film|micro|Micro)%'
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

-- 2. Get the 300 field that describes the number of fiche or film, and mentions whether there is a guide

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

-- 3. Find other copies in the stacks or at the Annex: From the instances selected in the "recs" subquery, find the titles that have "guide" or "index" 
-- as part of the call number, holdings statements, index statements, supplements statements, field 300 or holdings notes.

shelved_in_stacks AS 
(SELECT 
       recs.instance_id,
       recs.instance_hrid,
       string_agg (DISTINCT ie.item_hrid,' | ') AS shelved_in_stacks_item_hrids,
       ll.library_name,
       he.permanent_location_name,
       string_agg (DISTINCT he.holdings_hrid,' | ') AS shelved_in_stacks_holdings_hrids,
       string_agg (DISTINCT trim (concat (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix)),' | ') AS shelved_in_stacks_whole_call_numbers,
       --string_agg (DISTINCT he.call_number,' | ') AS shelved_in_stacks_call_numbers,
       string_agg (distinct ie.barcode,' | ') AS shelved_in_stacks_item_barcodes,
       string_agg (DISTINCT hn.note,' | ') AS shelved_in_stacks_holdings_notes,
       field300.field300_content,
       string_agg (DISTINCT hs.STATEMENT, ' | ') AS shelved_in_stacks_holdings_statements,
       string_agg (DISTINCT hss.STATEMENT,' | ') AS shelved_in_stacks_supplements_statements,
       string_agg (DISTINCT hsi.statement,' | ') AS shelved_in_stacks_index_statements

FROM recs 
       left JOIN folio_reporting.holdings_ext AS he 
       ON recs.instance_id = he.instance_id 
       
       LEFT JOIN field300 
       ON recs.instance_hrid = field300.instance_hrid
       
       left JOIN folio_reporting.holdings_notes AS hn 
       ON he.holdings_hrid = hn.holdings_hrid
       
       LEFT JOIN folio_reporting.holdings_statements AS hs 
       ON he.holdings_id = hs.holdings_id
       
       left JOIN folio_reporting.holdings_statements_indexes AS hsi 
       ON he.holdings_id = hsi.holdings_id
       
       LEFT JOIN folio_reporting.holdings_statements_supplements AS hss 
       ON he.holdings_id = hss.holdings_id
       
       left JOIN folio_reporting.locations_libraries AS ll 
       ON he.permanent_location_id = ll.location_id
       
       left JOIN folio_reporting.item_ext AS ie 
       ON he.holdings_id = ie.holdings_record_id
       
WHERE 
       ll.library_name IN ('Olin Library','Kroch Library Asia','Library Annex')
       AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
       AND (hsi.STATEMENT SIMILAR TO '%(guide|Guide|index|Index)%' OR hss.STATEMENT SIMILAR TO '%(guide|Guide|index|Index)%'
              OR hn.note SIMILAR TO '%(guide|Guide|index|Index)%' 
              OR concat (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix) SIMILAR TO '%(guide|Guide|index|Index)%'
              OR field300.field300_content SIMILAR TO '%(guide|Guide|index|Index)%')
       AND concat (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix) NOT SIMILAR TO '%(fiche|film|Fiche|Film)%'
              
GROUP BY ll.library_name, recs.instance_id, recs.instance_hrid, he.permanent_location_name, field300.field300_content--, he.holdings_hrid, ie.item_hrid, he.call_number, ie.barcode
)

-- 4. Join the results of subqueries together by instance_hrid and limit the results to records that have Guide or Index in all the fields mentioned

SELECT distinct
       recs.library_name,
       recs.permanent_location_name,
       CASE WHEN recs.whole_call_number ILIKE '%fiche%' THEN 'Fiche'
              WHEN recs.whole_call_number ILIKE '%film%' THEN 'Film'
              ELSE 'Other' END AS microform_type,
       recs.title,
       recs.instance_hrid,
       recs.holdings_hrid,
       recs.item_hrid,
       recs.barcode,
       substring (recs.whole_call_number,'\d{1,}')::numeric AS film_or_fiche_number,
       recs.whole_call_number,
       recs.holdings_notes,
       recs.holdings_statements,
       recs.supplements_statements,
       recs.status_name,
       field300.field300_content,
       shelved_in_stacks.permanent_location_name AS shelved_in_stacks_perm_loc_name,
       shelved_in_stacks.shelved_in_stacks_whole_call_numbers,
       shelved_in_stacks.shelved_in_stacks_holdings_hrids,
       shelved_in_stacks.shelved_in_stacks_item_hrids,
       shelved_in_stacks.shelved_in_stacks_item_barcodes,
       shelved_in_stacks.shelved_in_stacks_holdings_statements,
       shelved_in_stacks.shelved_in_stacks_holdings_notes,
       shelved_in_stacks.shelved_in_stacks_supplements_statements,
       shelved_in_stacks.shelved_in_stacks_index_statements
       
FROM recs 
       LEFT JOIN field300 
       ON recs.instance_hrid = field300.instance_hrid
       
       LEFT JOIN shelved_in_stacks
       ON recs.instance_hrid = shelved_in_stacks.instance_hrid
       
WHERE 
       recs.whole_call_number SIMILAR TO '%(guide|Guide|index|Index)%' 
       OR recs.holdings_notes SIMILAR TO '%(guide|Guide|index|Index)%'
       OR recs.holdings_statements SIMILAR TO '%(guide|Guide|index|Index)%' 
       OR recs.supplements_statements SIMILAR TO '%(guide|Guide|index|Index)%'
       OR shelved_in_stacks.shelved_in_stacks_supplements_statements SIMILAR TO '%(guide|Guide|index|Index)%'
       OR shelved_in_stacks.shelved_in_stacks_holdings_statements SIMILAR TO '%(guide|Guide|index|Index)%'
       OR shelved_in_stacks.shelved_in_stacks_whole_call_numbers SIMILAR TO '%(guide|Guide|index|Index)%'
       OR shelved_in_stacks.shelved_in_stacks_holdings_notes SIMILAR TO '%(guide|Guide|index|Index)%'
       OR shelved_in_stacks.shelved_in_stacks_index_statements SIMILAR TO '%(guide|Guide|index|Index)%'
       OR field300.field300_content SIMILAR TO '%(guide|Guide|index|Index)%'
       
ORDER BY library_name, permanent_location_name, microform_type, film_or_fiche_number, recs.whole_call_number, recs.instance_hrid, recs.holdings_hrid, recs.item_hrid
;

