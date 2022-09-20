WITH parameters AS 
(SELECT
        'Uris Library'::varchar AS library_filter -- examples: 'Uris Library', 'Mathematics Library', 'Library Annex'  
),

folio_circs AS 
        (SELECT
                li.item_id,
                li.hrid,
                COUNT(li.loan_id)::INTEGER AS folio_circ_count
        
        FROM folio_reporting.loans_items AS li 
        
        GROUP BY li.item_id, li.hrid
),

voy_circs AS 
        (SELECT 
                item.item_id::varchar,
                item.historical_charges::INTEGER AS voyager_circ_count
        
        FROM vger.item 
)

select 
        ll.library_name,
        ii.title,
        string_agg (distinct ic.contributor_name,' | ') as author,
        he.permanent_location_name,
        TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, invitems.enumeration, invitems.chronology,
                        CASE WHEN invitems.copy_number >'1' THEN concat ('c.', invitems.copy_number) ELSE '' END)) AS whole_call_number,
        substring (sm.content,8,4) as year_of_publication,
        sum(folio_circs.folio_circ_count) + sum(voy_circs.voyager_circ_count) as total_circs,
        he.type_name as holdings_type_name,
        ii.hrid as instance_hrid,
        he.holdings_hrid,
        invitems.hrid as item_hrid,
        SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') AS lc_class,
        SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')::numeric AS lc_class_number,
        instsubj.subject as primary_subject,
        invitems.effective_shelving_order COLLATE "C"

from inventory_instances as ii
        left join folio_reporting.holdings_ext as he 
        on ii.id = he.instance_id
        
        left join folio_reporting.instance_contributors as ic 
        on ii.id = ic.instance_id
        
        left join folio_reporting.instance_subjects as instsubj 
        on ii.id = instsubj.instance_id
        
        left join folio_reporting.locations_libraries as ll 
        on he.permanent_location_id = ll.location_id 
        
        left join inventory_items as invitems 
        on he.holdings_id = invitems.holdings_record_id
        
        left join srs_marctab as sm 
        on sm.instance_hrid = ii.hrid
        
        left join folio_circs 
        on ii.hrid = folio_circs.hrid 
        
        left join voy_circs 
        on ii.hrid = voy_circs.item_id::varchar

where  ll.library_name = (SELECT library_filter FROM parameters)
        and sm.field = '008'
        and (he.type_name = 'Monograph' or he.type_name like 'Multi%')
        and (he.discovery_suppress = 'False' or he.discovery_suppress IS NULL)
        and (instsubj.subject_ordinality = 1 or instsubj.subject_ordinality IS NULL)
        
group by 
        ll.library_name,
        ii.title,
        sm.content,
        he.type_name,
        ii.hrid,
        he.holdings_hrid,
        invitems.hrid,
        he.permanent_location_name,
        he.call_number_prefix, 
        he.call_number, 
        he.call_number_suffix, 
        invitems.enumeration, 
        invitems.chronology,
        invitems.copy_number,
        instsubj.subject,
        invitems.effective_shelving_order
        
order by invitems.effective_shelving_order COLLATE "C"
;

