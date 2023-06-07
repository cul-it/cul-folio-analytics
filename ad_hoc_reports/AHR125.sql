--AHR125
--Mann S 599 call numbers with circs since 2015
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 6/07/2023

--This query finds Mann S 599 items for possible transfer to the Annex

WITH voycircs AS 
(SELECT
                cta.item_id::varchar AS item_hrid,
                date_part ('year',cta.charge_date::date) AS year_of_circulation,
                count (DISTINCT cta.circ_transaction_id) AS circs
                
                FROM vger.circ_trans_archive AS cta 
                WHERE date_part ('year',cta.charge_date::date)>='2015'
                GROUP BY cta.item_id::varchar, date_part ('year',cta.charge_date::date)
),

voycircsmax AS 
(SELECT 
                voycircs.item_hrid,
                max(voycircs.year_of_circulation) AS last_year_of_checkout
                FROM voycircs
                GROUP BY voycircs.item_hrid
),

foliocircs AS
(SELECT 
                 li.hrid AS item_hrid,
                date_part ('year',li.loan_date::date) AS year_of_circulation,
                count (DISTINCT li.loan_id) AS circs
                
                 FROM folio_reporting.loans_items AS li
                WHERE li.hrid IS NOT null
                GROUP BY li.hrid, date_part ('year',li.loan_date::date)
),

foliocircsmax AS 
(SELECT
                foliocircs.item_hrid,
                max (foliocircs.year_of_circulation) AS last_year_of_checkout
                FROM foliocircs 
                GROUP BY foliocircs.item_hrid
),

pub_year AS 
(SELECT
                sm.instance_hrid,
                substring (sm.CONTENT,8,4) AS year_of_publication
                FROM srs_marctab AS sm 
                WHERE sm.field = '008'
),

mannrecs AS 
(SELECT 
                ll.library_name,
                he.permanent_location_name,
                ii.title,
                ii.hrid AS instance_hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ie.barcode,
                ie.status_name AS item_status_name,
                to_char (ie.status_date::date,'mm/dd/yyyy') AS item_status_date,
                he.call_number,
                concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
                                CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END) AS whole_call_number,
                string_agg (DISTINCT hs.STATEMENT,' | ') AS mann_holdings_statements,
                substring (he.call_number,'^[A-Za-z]{1,3}') AS lc_class,
                trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')) AS lc_class_number,
                trim (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}')) AS first_cutter, 
                he.type_name AS holdings_type_name,
                ie.material_type_name,
                pub_year.year_of_publication,
                CASE when sum (voycircs.circs) IS NULL THEN 0 ELSE sum (voycircs.circs) END AS total_voyager_circs_since_2015,
                CASE WHEN sum (foliocircs.circs) IS NULL THEN 0 ELSE sum (foliocircs.circs) END AS total_folio_circs,
                COALESCE (foliocircsmax.last_year_of_checkout::varchar, voycircsmax.last_year_of_checkout::varchar,'-') AS last_year_of_checkout,
                invitems.effective_shelving_order

FROM inventory_instances AS ii 
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id 
                
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id 
                
                LEFT JOIN folio_reporting.holdings_statements AS hs 
                ON he.holdings_id = hs.holdings_id
                
                LEFT JOIN inventory_items AS invitems 
                ON he.holdings_id = invitems.holdings_record_id 
                
                LEFT JOIN folio_reporting.item_ext AS ie 
                ON invitems.id = ie.item_id 
                
                LEFT JOIN voycircs 
                ON ie.item_hrid = voycircs.item_hrid
                
                LEFT JOIN voycircsmax 
                ON ie.item_hrid = voycircsmax.item_hrid
                
                LEFT JOIN foliocircs 
                ON ie.item_hrid = foliocircs.item_hrid
                
                LEFT JOIN foliocircsmax 
                ON ie.item_hrid = foliocircsmax.item_hrid
                
                LEFT JOIN pub_year
                ON ii.hrid = pub_year.instance_hrid

WHERE ll.library_name = 'Mann Library'
                AND substring (he.call_number,'^[A-Za-z]{1,3}') = 'S'
                AND trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}'))::NUMERIC >= 599
                AND trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}'))::NUMERIC < 600
                AND (he.discovery_suppress = 'False' or he.discovery_suppress is NULL)

GROUP BY 
                ll.library_name,
                he.permanent_location_name,
                ii.title,
                ii.hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ie.barcode,
                ie.status_name,
                to_char (ie.status_date::date,'mm/dd/yyyy'),
                he.call_number,
                concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
                                CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END),
                substring (he.call_number,'^[A-Za-z]{1,3}'),
                trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')),
                trim (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}')),
                pub_year.year_of_publication,
                he.type_name,
                ie.material_type_name,
                foliocircsmax.last_year_of_checkout::varchar,
                voycircsmax.last_year_of_checkout::varchar,
                invitems.effective_shelving_order
                
ORDER BY he.permanent_location_name, invitems.effective_shelving_order COLLATE "C"
),

annex_hold AS 
(SELECT 
                mannrecs.instance_hrid,
                ll.library_name,
                string_agg (distinct ll.location_name,' | ') AS annex_locations,
                string_agg (DISTINCT he.holdings_hrid,' | ') AS annex_holdings_hrids,
                string_agg (DISTINCT concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix),' | ') AS annex_call_numbers,
                string_agg (DISTINCT hs.STATEMENT,' | ') AS annex_holdings_statements
                
FROM mannrecs 
                LEFT JOIN inventory_instances AS ii 
                ON mannrecs.instance_hrid = ii.hrid 
                
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id 
                
                LEFT JOIN folio_reporting.holdings_statements AS hs
                ON he.holdings_id = hs.holdings_id
                
                LEFT JOIN folio_reporting.locations_libraries ll 
                ON he.permanent_location_id = ll.location_id

WHERE ll.library_name = 'Library Annex'
                AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)

GROUP BY mannrecs.instance_hrid, ll.library_name
)

SELECT 
                mannrecs.library_name,
                mannrecs.permanent_location_name,
                mannrecs.title,
                mannrecs.instance_hrid,
                mannrecs.holdings_hrid,
                mannrecs.item_hrid,
                mannrecs.barcode,
                mannrecs.item_status_name,
                mannrecs.item_status_date,
                mannrecs.whole_call_number,
                mannrecs.mann_holdings_statements,
                mannrecs.lc_class,
                mannrecs.lc_class_number,
                mannrecs.first_cutter,
                mannrecs.holdings_type_name,
                mannrecs.material_type_name,
                mannrecs.year_of_publication,
                mannrecs.total_voyager_circs_since_2015,
                mannrecs.total_folio_circs,
                mannrecs.last_year_of_checkout,
                annex_hold.annex_locations,
                annex_hold.annex_holdings_hrids,
                annex_hold.annex_call_numbers,
                annex_hold.annex_holdings_statements
                
FROM mannrecs 
LEFT JOIN annex_hold
ON mannrecs.instance_hrid = annex_hold.instance_hrid

ORDER BY mannrecs.permanent_location_name, mannrecs.lc_class_number, mannrecs.first_cutter, mannrecs.effective_shelving_order COLLATE "C"
;
