-- MCR 217
-- item_count_for_insurance

--Count physical items by location and library for university insurance purposes
-- NB: holdings without item records may indicate bound-withs, special collections, special formats or non-circulating materials.
-- The lack of an item record does not mean there are no holdings in the collection for a given title
--Query writer: Joanne Leary
--Date posted: 3/24/26

-- 1. Get all unsuppressed instance, holdings and item records; exclude 'serv,remo'

with recs as 
(select 
	current_date::date as todays_date,
	loclibrary__t.name as library_name,
	location__t.name as location_name,
	location__t.code as holdings_location_code,
	holdings_type__t.name as holdings_type,
	material_type__t.name as item_material_type,
	instance__t.id as instance_id,
	hrt.id as holdings_id,
	item__t.id as item_id
	
from folio_inventory.instance__t 
	left join folio_inventory.holdings_record__t as hrt 
	on instance__t.id = hrt.instance_id
	
	left join folio_inventory.holdings_type__t 
	on hrt.holdings_type_id = holdings_type__t.id
	
	left join folio_inventory.location__t 
	on hrt.permanent_location_id = location__t.id
	
	left join folio_inventory.loclibrary__t 
	on location__t.library_id = loclibrary__t.id
	
	left join folio_inventory.item__t 
	on hrt.id = item__t.holdings_record_id
	
	left join folio_inventory.material_type__t 
	on item__t.material_type_id = material_type__t.id

where (instance__t.discovery_suppress = false or instance__t.discovery_suppress is null)
	and (hrt.discovery_suppress = false or hrt.discovery_suppress is null)
	and ((item__t.discovery_suppress = false or item__t.discovery_suppress is null) or item__t.id is null) -- this allows for holdings without item records
	and location__t.code !='serv,remo'
)

-- 2. Count records by library, location, holdings type and material type

select 
	recs.todays_date,
	recs.library_name,
	recs.location_name,
	recs.holdings_location_code,
	recs.holdings_type,
	recs.item_material_type,
	count (distinct recs.instance_id) as count_of_instances,
	count (distinct recs.holdings_id) as count_of_holdings,
	count (distinct recs.item_id) as count_of_items

from recs 
group by 
	recs.todays_date,
	recs.library_name,
	recs.location_name,
	recs.holdings_location_code,
	recs.holdings_type,
	recs.item_material_type

order by recs.library_name, recs.location_name, recs.holdings_type, recs.item_material_type
;
