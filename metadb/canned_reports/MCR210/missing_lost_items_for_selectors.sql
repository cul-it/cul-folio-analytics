--MCR210
--Missing_Lost_items_for_selectors
--This query is specifically for selectors and it shows Missing and Lost items with different fields included that are useful in making replacement decisions. 

--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 11/13/2024


WITH parameters AS 
(SELECT 
'%Mann%'::varchar AS library_name_filter -- required
),

pubyear AS
(SELECT 
                sm.instance_hrid,
                substring (sm.content,8,4) AS year_of_publication
FROM folio_source_record.marc__t as sm --srs_marctab AS sm 
WHERE sm.field = '008'
),

folio_circs AS 
(SELECT 
                li.item_id,
                count(DISTINCT li.loan_id) AS folio_checkouts,
                max (li.loan_date::timestamp) AS most_recent_folio_checkout
FROM folio_derived.loans_items AS li 
GROUP BY li.item_id 
),

voycircs AS 
(SELECT 
                cta.item_id::varchar,
                max(cta.charge_date::timestamp) AS most_recent_voyager_checkout
FROM vger.circ_trans_archive cta 
GROUP BY cta.item_id::varchar
),

isbns AS 
(SELECT 
                iid.instance_id,
                iid.identifier_type_name,
                string_agg (DISTINCT substring (iid.identifier,'\d{9,}X{0,1}'),' | ') AS isbn_number 
FROM folio_derived.instance_identifiers AS iid
WHERE iid.identifier_type_name = 'ISBN' -- does not include "Invalid ISBN"

GROUP BY iid.instance_id, iid.identifier_type_name
),


issns AS 
(SELECT 
                iid.instance_id,
                iid.identifier_type_name,
                string_agg (DISTINCT substring (iid.identifier,'\d{4,}\-\d{4}'),' | ') AS issn_number 
FROM folio_derived.instance_identifiers AS iid
WHERE iid.identifier_type_name = 'ISSN'

GROUP BY iid.instance_id, iid.identifier_type_name
),

authors AS 
(SELECT
                ic.instance_id,
                ic.contributor_name AS primary_contributor
FROM folio_derived.instance_contributors AS ic 
WHERE ic.contributor_ordinality = 1 

),

publshr AS
(SELECT
                ip.instance_id,
                string_agg (DISTINCT ip.publisher,' | ') AS publisher
FROM folio_derived.instance_publication AS ip
WHERE ip.publisher !=''
GROUP BY ip.instance_id
),

lang AS 
(SELECT 
                il.instance_id,
                il.instance_language AS primary_language 
FROM folio_derived.instance_languages AS il 
WHERE il.language_ordinality = 1
),

recs AS 
(SELECT 
                ll.library_name,
                ii.title,
                authors.primary_contributor,
                he.permanent_location_name as holdings_location_name,
                itemext.effective_location_name as item_effective_location_name,
                TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, itemext.enumeration, itemext.chronology,
                                CASE WHEN itemext.copy_number >'1' THEN concat ('c.', itemext.copy_number) ELSE '' END)) AS whole_call_number,
                ii.hrid AS instance_hrid,
                ii.id AS instance_id,
                he.holdings_hrid,
                itemext.item_hrid,
                itemext.barcode,
                string_agg (distinct itemnote.note,' | ') as item_notes,
                ii.discovery_suppress AS instance_suppress,
                he.discovery_suppress::boolean AS holdings_suppress,
                itemext.material_type_name,
                he.type_name AS holdings_type_name,               
                publshr.publisher,
                pubyear.year_of_publication,
                lang.primary_language,
                isbns.isbn_number,
                issns.issn_number,
                string_agg (DISTINCT itemnotes.note,' | ') AS item_note,
                itemext.status_name AS item_status_name,
                to_char (itemext.status_date::DATE,'mm/dd/yyyy') AS item_status_date,
                to_char ((CASE WHEN item.create_date::date < itemext.created_date::date THEN item.create_date::date 
                                ELSE itemext.created_date::date END)::date,'mm/dd/yyyy') AS item_create_date,
                to_char (voycircs.most_recent_voyager_checkout::date,'mm/dd/yyyy') AS most_recent_voyager_checkout,
                to_char (folio_circs.most_recent_folio_checkout::date,'mm/dd/yyyy') AS most_recent_folio_checkout,
                CASE WHEN item.historical_charges::integer IS NULL THEN 0 ELSE item.historical_charges::integer END AS total_voyager_checkouts,
                CASE WHEN folio_circs.folio_checkouts::integer IS NULL THEN 0 ELSE folio_circs.folio_checkouts::integer END AS total_folio_charges,
                invitems.effective_shelving_order
                
FROM folio_inventory.instance__t as ii  
                LEFT JOIN folio_derived.holdings_ext AS he 
                ON ii.id = he.instance_id::UUID 
                
                LEFT JOIN folio_derived.item_ext AS itemext 
                ON he.holdings_id = itemext.holdings_record_id 
                
                LEFT JOIN folio_inventory.item__t as invitems  
                ON itemext.item_id::UUID = invitems.id
                
                left join folio_derived.item_notes as itemnote
                on itemext.item_id = itemnote.item_id
                
                LEFT JOIN vger.item 
                ON itemext.item_hrid = item.item_id::varchar
                
                LEFT JOIN voycircs
                ON itemext.item_hrid = voycircs.item_id::varchar
                
                LEFT JOIN folio_derived.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id 
                
                LEFT JOIN folio_derived.item_notes AS itemnotes 
                ON itemext.item_id = itemnotes.item_id 
                
                LEFT JOIN pubyear 
                ON ii.hrid = pubyear.instance_hrid
                
                LEFT JOIN isbns 
                ON ii.id = isbns.instance_id::UUID
                
                LEFT JOIN issns 
                ON ii.id = issns.instance_id::UUID
                
                LEFT JOIN authors 
                ON ii.id = authors.instance_id::UUID
                
                LEFT JOIN publshr
                ON ii.id = publshr.instance_id::UUID
                
                LEFT JOIN lang 
                ON ii.id = lang.instance_id::UUID
                
                LEFT JOIN folio_circs 
                ON itemext.item_id = folio_circs.item_id 

WHERE ll.library_name ilike (SELECT library_name_filter FROM parameters)
AND itemext.status_name in ('Missing','Long missing','Declared lost','Lost and paid','Aged to lost') 
and itemext.material_type_name not in ('Supplies','Peripherals','Laptop','Keys','Locker Keys','Equipment','Room Keys','Umbrella','ILL MATERIAL','BD MATERIAL')

GROUP BY 
                ii.hrid,
                ii.id,
                he.holdings_hrid,
                itemext.item_hrid,
                publshr.publisher,
                item.historical_charges,
                ii.discovery_suppress,
                he.discovery_suppress,
                itemext.material_type_name,
                he.type_name,
                ll.library_name,
                he.permanent_location_name,
                itemext.effective_location_name,
                ii.title,
                lang.primary_language,
                authors.primary_contributor,
                he.call_number_prefix, 
                he.call_number, 
                he.call_number_suffix, 
                itemext.enumeration, 
                itemext.chronology,
                itemext.copy_number,
                itemext.barcode,
                itemext.status_name,
                itemext.status_date::DATE,
                pubyear.year_of_publication,
                isbns.isbn_number,
                issns.issn_number,
                item.create_date::date,
                itemext.created_date::date,
                voycircs.most_recent_voyager_checkout,
                folio_circs.most_recent_folio_checkout,
                item.historical_charges::integer,
                folio_circs.folio_checkouts::integer,
                invitems.effective_shelving_order 
),

otherlibs AS 

(SELECT 
                recs.instance_hrid,
                string_agg (DISTINCT he.permanent_location_name,' | ') AS all_holdings_locations

FROM recs 
                LEFT JOIN folio_derived.holdings_ext AS he 
                ON recs.instance_id = he.instance_id::UUID
                
                LEFT JOIN folio_derived.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id
where (he.discovery_suppress = 'false' or he.discovery_suppress is null)                
GROUP BY recs.instance_hrid
)

SELECT 
                recs.library_name,
                recs.title,
                recs.primary_contributor,
                recs.holdings_location_name,
                recs.item_effective_location_name,
                recs.whole_call_number,
                recs.instance_hrid,
                recs.holdings_hrid,
                recs.item_hrid,
                recs.barcode,
                recs.instance_suppress,
                recs.holdings_suppress,
                recs.material_type_name,
                recs.holdings_type_name,
                recs.publisher,
                recs.year_of_publication,
                recs.primary_language,
                --recs.isbn_number,
                --recs.issn_number,
                COALESCE (recs.isbn_number, recs.issn_number,'') AS isbn_or_issn,
                recs.item_create_date,
                recs.item_note,
                recs.item_status_name,
                recs.item_status_date,               
                recs.total_voyager_checkouts + recs.total_folio_charges AS total_voyager_and_folio_checkouts,
                --recs.most_recent_folio_checkout,
                --recs.most_recent_voyager_checkout,
                CASE WHEN recs.total_voyager_checkouts > 0 AND COALESCE (recs.most_recent_folio_checkout, recs.most_recent_voyager_checkout, ' - ') = ' - ' THEN 'pre-Voyager' 
                                ELSE COALESCE (recs.most_recent_folio_checkout, recs.most_recent_voyager_checkout, ' - ') END AS most_recent_checkout,
                otherlibs.all_holdings_locations
                
FROM recs 
                LEFT JOIN otherlibs 
                ON recs.instance_hrid = otherlibs.instance_hrid
                
ORDER BY recs.holdings_location_name, recs.effective_shelving_order COLLATE "C", recs.title
;
