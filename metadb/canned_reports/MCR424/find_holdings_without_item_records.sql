-- find_holdings_without_item_records.sql
-- 7-8-26: Find holdings without item records. Exclude suppressed instances and holdings and serv,remo location. 
-- written by: Joanne Leary
-- Exclude holdings notes indicating bound-withs and filmed-withs
-- Capture instance format category from 007 field where one exists, to help understand why the holdings have no item records 

with field007 as 
(select 
marc__t.instance_hrid,
case 
		when substring (marc__t.content,1,1) is null then null
		when substring (marc__t.content,1,1) = 'a' then 'map'
		when substring (marc__t.content,1,1) = 'c' then 'electronic resource'
		when substring (marc__t.content,1,1) = 'd' then 'globe'
		when substring (marc__t.content,1,1) = 'f' then 'tactile material'
		when substring (marc__t.content,1,1) = 'g' then 'projected graphic'
		when substring (marc__t.content,1,1) = 'h' then 'microform'
		when substring (marc__t.content,1,1) = 'k' then 'non-projected graphic'
		when substring (marc__t.content,1,1) = 'm' then 'motion picture'
		when substring (marc__t.content,1,1) = 'o' then 'kit'
		when substring (marc__t.content,1,1) = 'q' then 'notated music'
		when substring (marc__t.content,1,1) = 'r' then 'remote-sensing image'
		when substring (marc__t.content,1,1) = 's' then 'sound recording' 
		when substring (marc__t.content,1,1) = 't' then 'text'
		when substring (marc__t.content,1,1) = 'v' then 'videorecording' 
		when substring (marc__t.content,1,1) = 'z' then 'unspecified' 
		else null end as field007_code_translation
from local_derived.marc__t 
where marc__t.field = '007'
),

recs as 
(select 
	current_date::date as todays_date,
	instance__t.hrid as instance_hrid,
	hrt.hrid as holdings_hrid,
	instance__t.title,
	trim (concat (hrt.call_number_prefix,' ',hrt.call_number,' ',hrt.call_number_suffix)) as holdings_call_number,
	loclibrary__t.name as library_name,
	location__t.name as location_name,
	location__t.code as holdings_location_code,
	holdings_type__t.name as holdings_type,
	string_agg (distinct hn.note,' | ') as holdings_note,
	string_agg (distinct hs.holdings_statement,' | ') as holdings_statement,
	string_agg (distinct field007.field007_code_translation,' | ') as field007_format_category
	
from folio_inventory.instance__t 
	left join folio_inventory.holdings_record__t as hrt 
	on instance__t.id = hrt.instance_id
	
	left join field007 
	on instance__t.hrid = field007.instance_hrid
	
	left join folio_derived.holdings_notes as hn 
	on hrt.id = hn.holding_id
	
	left join folio_derived.holdings_statements as hs 
	on hrt.id = hs.holdings_id
	
	left join folio_inventory.holdings_type__t 
	on hrt.holdings_type_id = holdings_type__t.id
	
	left join folio_inventory.location__t 
	on hrt.permanent_location_id = location__t.id
	
	left join folio_inventory.loclibrary__t 
	on location__t.library_id = loclibrary__t.id
	
	left join folio_inventory.item__t 
	on hrt.id = item__t.holdings_record_id

where (instance__t.discovery_suppress = false or instance__t.discovery_suppress is null)
	and (hrt.discovery_suppress = false or hrt.discovery_suppress is null)
	and location__t.code !='serv,remo'
	and item__t.id is null
	and ((hn.note not like '%31924%' and hn.note not ilike '%bound%with%' and hn.note not ilike '%filmed%with%') or hn.note is null)
	and ((hs.holdings_statement not like '%31924%' and hs.holdings_statement not ilike '%bound%with%' and hs.holdings_statement not ilike '%filmed%with%') or hs.holdings_statement is null)
	
group by 
current_date::date,
	instance__t.hrid,
	hrt.hrid,
	instance__t.title,
	trim (concat (hrt.call_number_prefix,' ',hrt.call_number,' ',hrt.call_number_suffix)),
	loclibrary__t.name,
	location__t.name,
	location__t.code,
	holdings_type__t.name
	)
	
select 
	recs.library_name,
	recs.location_name,
	recs.holdings_type,
	recs.field007_format_category,
	count (distinct recs.instance_hrid) as count_of_instances,
	count (distinct recs.holdings_hrid) as count_of_holdings

from recs 
group by 
	recs.library_name,
	recs.location_name,
	recs.holdings_type,
	recs.field007_format_category
	
order by library_name, location_name, holdings_type
	;

