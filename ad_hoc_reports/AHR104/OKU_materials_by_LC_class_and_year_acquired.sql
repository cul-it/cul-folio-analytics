/* This finds Voyager data for the last five fiscal years of newly acquired items in OKU (7/1/16 - 6/30/21). Groups by LC class, bib format, number of volumes and total checkouts. Consolidated count of items by LC class and year acquired, not individual data for each item. Needs historical Voyager data, because we don't have year acquired in Folio.*/

with raw as (
	select 
		bt.bib_id::VARCHAR,
		mm.mfhd_id::VARCHAR,
		item.item_id::VARCHAR,
		bt.title,
		bf.bib_format_display,
		substring(bmst.create_date::VARCHAR,1,4) as year_acquired,
		bt."language",
		bmst.suppress_in_opac as bib_suppress,
		mm.suppress_in_opac as mfhd_suppress,
		"location".location_name,
		mm.display_call_no,
		CASE 
			WHEN mm.call_no_type = '0' THEN SUBSTRING (mm.normalized_call_no,'^[a-zA-z]{1,3}')
			ELSE '-' END as lc_class,
	(case 
		when date_part('month',bmst.create_date) < '7' then date_part('year',bmst.create_date) 
		ELSE date_part('year',bmst.create_date)+1 END)::VARCHAR as fiscal_year,
	case when item.historical_charges::INTEGER >'0' then '1' else '0' end as circed_or_not,
	
	item.historical_charges::INTEGER

	from vger.bib_master as bmst
		inner join vger.bib_text as bt 
		on bmst.bib_id = bt.bib_id
		
		inner join vger.bib_mfhd as bmf 
		on bt.bib_id = bmf.bib_id 
		
		left join vger.bib_format_display as bf 
		on bt.bib_format = bf.bib_format
		
		inner join vger.mfhd_master as mm 
		on bmf.mfhd_id = mm.mfhd_id 
		
		inner join vger."location" 
		on mm.location_id = "location".location_id 
		
		inner join vger.mfhd_item as mi 
		on mm.mfhd_id = mi.mfhd_id 
		
		inner join vger.item 
		on mi.item_id = item.item_id 
		
		left join vger.circ_policy_locs as cpl 
		on "location".location_id = cpl.location_id 
		
		left join vger.circ_policy_group as cpg 
		on cpl.circ_group_id = cpg.circ_group_id

where cpg.circ_group_name like 'Olin%'
	and bmst.create_date >'2016-07-01'
	and mm.suppress_in_opac = 'N'
	and bmst.suppress_in_opac = 'N'

order by "location".location_name, mm.normalized_call_no
)

select 
raw.location_name,
raw.lc_class,
raw.fiscal_year,
raw.bib_format_display,
raw."language" as language_code,
count(raw.item_id) as number_of_items,
sum(raw.circed_or_not::INTEGER) as number_of_items_that_circed,
case when sum(raw.historical_charges) is null then '0' else sum(raw.historical_charges) end as total_circs

from raw 

group by 
raw.location_name,
raw.lc_class,
raw.fiscal_year,
raw.bib_format_display,
raw."language"

order by location_name, raw.lc_class, fiscal_year, bib_format_display, language_code;
;
