--MCR220 - Voyager and Folio circ counts with parameters
	--Query writer: Joanne Leary (jl41)
	--Query reviewer: Vandana Shah (vp25)
	--Date posted: 8/15/23
	-- 12-20-24: revised for Metadb

/*This query finds total Voyager and Folio circ usage for given parameters: LC class, library, title, instance hrid and/or language.

NOTE: It's best to comment out any of the WHERE statement parameters that you're not using, or the query will take an eternity to run.
However, DO NOT comment out the "language ordinality" condition, even if you comment out the language_filter parameter. */

WITH parameters AS 
(SELECT 
       ''::varchar as instance_hrid_filter,
       'QP'::varchar as lc_class_filter,
       '%Mann%'::varchar as library_filter,
       '%%'::varchar as title_filter,
       ''::varchar as language_filter
),

pubdate as 
(select 
       sm.instance_hrid,
       substring (sm.content,8,4) as year_of_publication

from folio_source_record.marc__t as sm --srs_marctab as sm 
where sm.field = '008'
),

items AS 
(SELECT 
        ll.library_name,
        ii.title,
        ii.hrid as instance_hrid,
        he.holdings_hrid,
        invitems.hrid as item_hrid,
        ii.discovery_suppress as instance_suppress,
        he.discovery_suppress as holdings_suppress,       
        he.permanent_location_name,
        SUBSTRING (he.call_number, '^([a-zA-Z]{1,3})') as lc_class,
        TRIM (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix, invitems.enumeration, invitems.chronology,
                CASE WHEN invitems.copy_number >'1' THEN concat ('c.',invitems.copy_number) ELSE '' END)) AS whole_call_number,
        string_agg (distinct he.type_name,' | ') as holdings_type_name,
        string_agg (distinct ie.material_type_name,' | ') as material_type_name,
        il.instance_language as primary_language,
        pubdate.year_of_publication,
        coalesce (item.create_date::date, jsonb_extract_path_text (itm.jsonb,'metadata','createdDate')::date) as item_create_date, --invitems.metadata__created_date::date) as item_create_date,
        max (cta.charge_date::date) as most_recent_voyager_circ,
        max (li.loan_date::date) as most_recent_folio_circ,
        COUNT (li.loan_id) AS folio_circs,
        item.historical_charges::integer AS voyager_circs,
        invitems.effective_shelving_order

FROM folio_inventory.instance__t as ii  
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON ii.id = he.instance_id::UUID
        
        left join folio_derived.instance_languages as il 
        on ii.id = il.instance_id::UUID
        
        left join pubdate 
        on ii.hrid = pubdate.instance_hrid
        
        left join folio_derived.locations_libraries ll 
        on he.permanent_location_id::UUID = ll.location_id::UUID
        
        LEFT JOIN folio_inventory.item__t as invitems 
        ON he.id = invitems.holdings_record_id::UUID 
        
        left join folio_derived.item_ext as ie 
        on invitems.id = ie.item_id::UUID
        
        left join folio_inventory.item as itm
        on invitems.id = itm.id
        
        LEFT JOIN vger.item 
        ON invitems.hrid::varchar = item.item_id::varchar
        
        left join vger.circ_trans_archive as cta 
        on item.item_id = cta.item_id
        
        LEFT JOIN folio_derived.loans_items AS li 
        ON invitems.id = li.item_id::UUID

WHERE 
       --((select instance_hrid_filter from parameters) = '' or ii.hrid = (SELECT instance_hrid_filter FROM parameters))
       --and 
       ((select lc_class_filter from parameters) = '' or SUBSTRING (he.call_number, '^([a-zA-Z]{1,3})') = (select lc_class_filter from parameters))
       and ((select library_filter from parameters) ilike '' or ll.library_name ilike (select library_filter from parameters))
       --and ((select ii.title from parameters) = '' or ii.title ilike (select title_filter from parameters))
       --and (il.instance_language = (select language_filter from parameters) or (select language_filter from parameters) = '')
       and (il.language_ordinality = 1 or il.language_ordinality is null)

GROUP BY 
        ll.library_name,
        ii.title,
        ii.hrid,
        he.holdings_hrid,
        invitems.hrid,
        ii.discovery_suppress,
        he.discovery_suppress,
        he.permanent_location_name,
        il.instance_language,
        pubdate.year_of_publication,
        item.create_date,
        coalesce (item.create_date::date, jsonb_extract_path_text (itm.jsonb,'metadata','createdDate')::date),        
        SUBSTRING (he.call_number, '^([a-zA-Z]{1,3})'),
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix, 
        invitems.enumeration,
        invitems.chronology,
        invitems.copy_number,
        item.historical_charges::integer,
        invitems.effective_shelving_order
)

SELECT 
        items.library_name,
        items.permanent_location_name,
        items.title,
        items.instance_hrid,
        items.holdings_hrid,
        items.item_hrid,
        items.instance_suppress,
        items.holdings_suppress,
        items.primary_language,
        items.year_of_publication,
        items.item_create_date,
        items.lc_class,
        items.whole_call_number,
        string_agg (distinct items.holdings_type_name,' | ') as holdings_type_name,
        string_agg (distinct items.material_type_name,' | ') as material_type_name,
        sum (case when items.voyager_circs is null then 0 else items.voyager_circs end) as voyager_and_notis_circs,
        sum (items.folio_circs) as folio_circs,
        coalesce (items.most_recent_folio_circ, items.most_recent_voyager_circ) as most_recent_checkout,
        case when SUM (items.folio_circs) + SUM (items.voyager_circs) is null then 0 else SUM (items.folio_circs) + SUM (items.voyager_circs) end AS total_circs

FROM items 

GROUP BY 
        items.library_name,
        items.permanent_location_name,
        items.title,
        items.instance_hrid,
        items.holdings_hrid,
        items.item_hrid,
        items.instance_suppress,
        items.holdings_suppress,
        items.primary_language,
        items.year_of_publication,
        items.item_create_date,
        items.lc_class,
        items.whole_call_number,
        items.most_recent_voyager_circ,
        items.most_recent_folio_circ,
        items.effective_shelving_order
        

ORDER BY items.permanent_location_name,
items.effective_shelving_order COLLATE "C"
;
