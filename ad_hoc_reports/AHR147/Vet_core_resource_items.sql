--AHR147
--Vet_core_resource_items
--This query finds a list of Vet Core Resource books with publication date, publisher and edition. 
--Requester: Lauren Mabry, who will be using it to make decisions about purchasing newer editions.
--Query writer: Joanne Leary (jl41)
--Date posted: 6/10/24

select 
	he.permanent_location_name,
	ii.hrid as instance_hrid,
	he.holdings_hrid,
	invitems.hrid as item_hrid,
	ii.title,
	trim (' | ' from string_agg (distinct instcont.contributor_name,' | ')) as author,
	concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
		case when invitems.copy_number >'1' then concat ('c.',invitems.copy_number) else '' end) as call_number,
	trim (' | ' from string_agg (distinct instpub.publisher,' | ')) as publisher,
	trim (' | ' from string_agg (distinct insted.edition,' | ')) as edition,
	substring (sm.content,8,4) as year_of_publication,
	trim (' | ' from string_agg (distinct iid.identifier,' | ')) as isbns

from inventory_instances as ii 
	left join folio_reporting.holdings_ext as he 
	on ii.id = he.instance_id 
	
	left join inventory_items as invitems 
	on he.holdings_id = invitems.holdings_record_id
	
	left join folio_reporting.instance_publication as instpub 
	on ii.id = instpub.instance_id 
	
	left join folio_reporting.instance_editions as insted 
	on ii.id = insted.instance_id 
	
	left join folio_reporting.instance_identifiers as iid 
	on ii.id = iid.instance_id 
	
	left join folio_reporting.instance_contributors as instcont 
	on ii.id = instcont.instance_id
	
	left join srs_marctab as sm 
	on ii.hrid = sm.instance_hrid

where he.permanent_location_name = 'Vet Core Resource'
	and (iid.identifier_type_name = 'ISBN' or iid.instance_id is null)
	and (he.discovery_suppress = 'False' or he.discovery_suppress is null)
	and sm.field = '008'

group by 
	he.permanent_location_name,
	ii.hrid,
	he.holdings_hrid,
	invitems.hrid,
	ii.title,
	concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
		case when invitems.copy_number >'1' then concat ('c.',invitems.copy_number) else '' end),
	sm.content,
	invitems.effective_shelving_order collate "C"

order by invitems.effective_shelving_order collate "C"
