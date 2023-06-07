--AHR 124
--Olin K monographs with no holdings at the Annex 

--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 6/07/2023
--This query gets Olin Library K call number monographs, where there are no copies at the Annex 


With olin_recs as 
(select 
                ii.id as instance_id,
                ii.hrid as instance_hrid,
                ii.title,
                ll.library_name,
                he.permanent_location_name,
                he.type_name as holdings_type_name,
                instext.mode_of_issuance_name,
                he.holdings_id,
                he.holdings_hrid,
                invitems.hrid AS item_hrid,
                invitems.barcode,
                he.call_number,
                trim (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix,invitems.enumeration,invitems.chronology,
                                CASE WHEN invitems.copy_number >'1' THEN concat ('c.',invitems.copy_number) ELSE '' END)) as whole_call_number,
                SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') as lc_class,
                case when substring (he.call_number,2,1) = ' ' then 0 else substring (he.call_number,'\d{1,}\.{0,}\d{0,}')::numeric end as lc_class_number,
                trim (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}[a-z]{0,}')) AS first_cutter,
                trim (LEADING '.' FROM SUBSTRING (he.call_number, '\s{1}[A-Z]{1}\d{1,}x{0,}a{0,}b{0,}')) AS second_cutter,
                concat (ll.location_name,': ',case when hs.statement is null then 'No holdings statement' else string_agg (distinct hs.statement,' | ') end) as olin_holdings,
                concat ('https://newcatalog.library.cornell.edu/catalog/',ii.hrid) as catalog_url,
                invitems.effective_shelving_order

from inventory_instances as ii 
                left join folio_reporting.holdings_ext as he 
                on ii.id = he.instance_id
                
                LEFT JOIN inventory_items AS invitems 
                ON he.holdings_id = invitems.holdings_record_id
                
                left join folio_reporting.holdings_statements as hs 
                on he.holdings_id = hs.holdings_id
                
                left join folio_reporting.locations_libraries as ll 
                on he.permanent_location_id = ll.location_id
                
                LEFT JOIN folio_reporting.instance_ext AS instext 
                ON ii.id = instext.instance_id

where
                SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') like 'K%'
                and ll.library_name = 'Olin Library'
                and (he.discovery_suppress = 'False' or he.discovery_suppress is null)
                AND instext.mode_of_issuance_name != 'serial'  

group by 
                ii.id,
                ii.hrid,
                ii.index_title,
                ii.title,
                ll.library_name,
                he.permanent_location_name,
                he.type_name,
                instext.mode_of_issuance_name,
                he.holdings_id,
                he.holdings_hrid,
                invitems.hrid,
                invitems.enumeration,
                invitems.chronology,
                invitems.copy_number,
                invitems.barcode,
                he.call_number,
                trim (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix,invitems.enumeration,invitems.chronology,
                                CASE WHEN invitems.copy_number >'1' THEN concat ('c.',invitems.copy_number) ELSE '' END)),
                SUBSTRING (he.call_number,'^([a-zA-z]{1,3})'),
                case when substring (he.call_number,2,1) = ' ' then 0 else substring (he.call_number,'\d{1,}\.{0,}\d{0,}')::numeric end,
                trim (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}')),
                trim (LEADING '.' FROM SUBSTRING (he.call_number, '\s{1}[A-Z]{1}\d{1,}x{0,}a{0,}b{0,}')),
                ll.location_name,
                hs.statement,
                concat ('https://newcatalog.library.cornell.edu/catalog/',ii.hrid),
                invitems.effective_shelving_order
),

notes as 
(select 
                olin_recs.instance_hrid,
                olin_recs.holdings_id,
                olin_recs.title,
                string_agg (distinct hn.note,' | ') as holdings_notes

from olin_recs 
                left join folio_reporting.holdings_notes as hn 
                on olin_recs.holdings_id = hn.holdings_id 

group by
                olin_recs.instance_hrid,
                olin_recs.holdings_id,
                olin_recs.title
),

anx_locs as 
(select 
                olin_recs.instance_hrid,
                ll.library_name,
                string_agg (distinct he.permanent_location_name, ' | ') as annex_locations,
                concat (ll.location_name,': ',case when hs.statement is null then 'No holdings statement' else string_agg (distinct hs.statement,' | ') end) as annex_holdings
                
from olin_recs 
                left join folio_reporting.holdings_ext as he 
                on olin_recs.instance_id = he.instance_id 
                
                left join folio_reporting.holdings_statements as hs 
                on he.holdings_id = hs.holdings_id 
                
                left join folio_reporting.locations_libraries as ll 
                on he.permanent_location_id = ll.location_id

where ll.library_name ='Library Annex'
                and (he.discovery_suppress = 'False' or he.discovery_suppress is null)

group by 
                olin_recs.instance_hrid,
                ll.library_name,
                ll.location_name,
                hs.statement
)

select 
                olin_recs.permanent_location_name as olin_location,
                olin_recs.title,
                olin_recs.call_number,
                olin_recs.whole_call_number,
                olin_recs.instance_hrid,
                olin_recs.holdings_hrid,
                olin_recs.item_hrid,
                olin_recs.barcode,
                olin_recs.lc_class,
                olin_recs.lc_class_number,
                trim (olin_recs.first_cutter) as first_cutter,
                trim (olin_recs.second_cutter) as second_cutter,
                string_agg (distinct olin_recs.olin_holdings,' | ') as olin_holdings,
                string_agg (distinct anx_locs.annex_holdings,' | ') as annex_holdings,
                olin_recs.holdings_type_name,
                olin_recs.mode_of_issuance_name,
                string_agg (distinct notes.holdings_notes,' | ') as holdings_notes,
                olin_recs.catalog_url,
                olin_recs.effective_shelving_order
                
from olin_recs    
                left join notes 
                on olin_recs.holdings_id = notes.holdings_id

                left join anx_locs 
                on olin_recs.instance_hrid = anx_locs.instance_hrid 
                
WHERE anx_locs.annex_holdings is NULL

GROUP by
                olin_recs.permanent_location_name,
                olin_recs.title,
                olin_recs.call_number,
                olin_recs.whole_call_number,
                olin_recs.instance_hrid,
                olin_recs.holdings_hrid,
                olin_recs.item_hrid,
                olin_recs.barcode,
                olin_recs.lc_class,
                olin_recs.lc_class_number,
                trim (olin_recs.first_cutter),
                trim (olin_recs.second_cutter),
                olin_recs.holdings_type_name,
                olin_recs.mode_of_issuance_name,
                olin_recs.catalog_url,
                olin_recs.effective_shelving_order

order by lc_class, lc_class_number, first_cutter, second_cutter, effective_shelving_order collate "C"
;
