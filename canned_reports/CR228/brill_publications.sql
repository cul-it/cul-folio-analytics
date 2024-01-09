-- 12-18-23: this query finds Brill print monographs publications at CUL and shows the LC class and class number, total circulation (Voyager and Folio)
-- most recent checkout, cost and fund (Folio only for now). Other data elements include Series, publication date and year added to collection.
-- The report will be used to make decisions about joining an ILPC cooperative Brill acquisitions program.
-- written by Joanne Leary; reviewed and tested by Sharon Markus
--1. Get all Folio circs (total circs, most recent checkout in Folio)

with foliocircs as 
(select 
	li.item_id,
	ie.item_hrid,
	max (li.loan_date::date) as max_folio_loan_date,
	case when count(distinct li.loan_id) is null then 0 else count (distinct li.loan_id) end as folio_circs
from folio_reporting.loans_items as li
	left join folio_reporting.item_ext as ie 
	on li.item_id = ie.item_id 
group by li.item_id, ie.item_hrid
),

-- 2. Get all Voyager circs (total circs, and most recent checkout in Voyager)

voycircs as 
(select 
	cta.item_id::varchar as item_hrid,
	max (cta.charge_date::date) as max_voyager_loan_date,
	case when count (distinct cta.circ_transaction_id) is null then 0 else count (distinct cta.circ_transaction_id) end as voyager_circs
from vger.circ_trans_archive as cta 
group by cta.item_id::varchar
),

-- 3. Combine to find total circs and most recent checkout overall

vfcircs as 
(select 
	coalesce (voycircs.item_hrid,foliocircs.item_hrid) as item_hrid,
	case when voycircs.voyager_circs is null then 0 else voycircs.voyager_circs end as voyager_circs,
	case when foliocircs.folio_circs is null then 0 else foliocircs.folio_circs end as folio_circs,
	coalesce (foliocircs.max_folio_loan_date, voycircs.max_voyager_loan_date) as most_recent_loan,
	((case when voycircs.voyager_circs is null then 0 else voycircs.voyager_circs end) + 
		(case when foliocircs.folio_circs is null then 0 else foliocircs.folio_circs end)) as total_circs

from voycircs 
full join foliocircs 
on voycircs.item_hrid = foliocircs.item_hrid
),

-- 4. Find Brill publications (through instance_publications table) and join to circulation data; exclude electronic resources (serv,remo)

main as 
(select 
	ii.hrid as instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ll.library_name,
	he.permanent_location_name,
	ii.title,
	trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', ie.enumeration,' ', ie.chronology,' ', 
		case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)) as whole_call_number,
	SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') as lc_class,
    trim (trailing '.' from SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}'))::numeric AS lc_class_number,
	string_agg (distinct iss.series,' | ') as series,
	imoi.name as mode_of_issuance_name,
	he.type_name as holdings_type_name,
	ie.material_type_name,
	ip.publisher as publisher,
	substring (ip.date_of_publication,'\d{4}') as pub_date,
	coalesce (bm.create_date::date, ii.metadata__created_date::date) as instance_create_date,
	substring ((coalesce (bm.create_date::date, ii.metadata__created_date::date))::varchar,'\d{4}') as year_added_to_collection,
	vfcircs.voyager_circs,
	vfcircs.folio_circs,
	vfcircs.total_circs,
	vfcircs.most_recent_loan,
	invitems.effective_shelving_order collate "C"

from inventory_instances as ii
	left join folio_reporting.instance_publication ip 
	on ii.hrid = ip.instance_hrid
	
	left join folio_reporting.instance_series as iss 
	on ii.hrid = iss.instance_hrid
	
	left join inventory_modes_of_issuance as imoi 
	on ii.mode_of_issuance_id = imoi.id
	
	left join folio_reporting.holdings_ext as he 
	on ii.id = he.instance_id
	
	left join folio_reporting.locations_libraries as ll 
	on he.permanent_location_id = ll.location_id
	
	left join folio_reporting.item_ext as ie 
	on he.holdings_id = ie.holdings_record_id
	
	left join inventory_items as invitems 
	on ie.item_id = invitems.id
	
	left join vfcircs on 
	ie.item_hrid= vfcircs.item_hrid
	
	left join vger.bib_master as bm 
	on ii.hrid = bm.bib_id::varchar

where ip.publisher ilike '%brill%'
and ip.publisher not similar to '%(Brilliant|Brilliance)%'
and (ii.discovery_suppress = 'False' or ii.discovery_suppress is null)
and (he.discovery_suppress = 'False' or he.discovery_suppress is null)
and imoi.name !='serial'
and he.permanent_location_name not like 'LTS%' and he.permanent_location_name !='serv,remo'

group by 
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ll.library_name,
	he.permanent_location_name,
	ii.title,	
	trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', ie.enumeration,' ', ie.chronology,' ', 
		case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)),
	SUBSTRING (he.call_number,'^([a-zA-z]{1,3})'),
    trim (trailing '.' from SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}'))::numeric,
	imoi.name,
	he.type_name,
	ie.material_type_name,
	ip.publisher,
	substring (ip.date_of_publication,'\d{4}'),
	coalesce (bm.create_date::date, ii.metadata__created_date::date),
	substring ((coalesce (bm.create_date::date, ii.metadata__created_date::date))::varchar,'\d{4}'),
	vfcircs.voyager_circs,
	vfcircs.folio_circs,
	vfcircs.total_circs,
	vfcircs.most_recent_loan,
	invitems.effective_shelving_order collate "C"
	
order by invitems.effective_shelving_order collate "C"
)
	
-- 5. Get rid of combinatorial rows by aggregating fields and counting items. Find invoice cost for Folio purchases. Put results in approximate call number order
-- using LC class, LC class number.


SELECT distinct
    main.instance_hrid,
	string_agg (distinct main.holdings_hrid,' | ') as holdings_hrids,
	string_agg (distinct main.item_hrid,' | ') as item_hrids,
	count (distinct main.item_hrid) as count_of_items,
	string_agg (distinct main.library_name,' | ') as library_names,
	string_agg (distinct main.permanent_location_name,' | ') as permanent_location_names,
	string_agg (distinct main.title,' | ') as title,
	string_agg (distinct main.whole_call_number,' | ') as call_numbers,
	string_agg (distinct main.lc_class,' | ') as lc_class,
    string_agg (distinct main.lc_class_number::varchar,' | ') as lc_class_numbers,
	string_agg (distinct main.series,' | ') as series,
	string_agg (distinct main.mode_of_issuance_name,' | ') as modes_of_issuance,
	string_agg (distinct main.holdings_type_name,' | ') as holdings_type_names,
	string_agg (distinct main.material_type_name,' | ') as material_type_names,
	string_agg (distinct main.publisher,' | ') as publishers,
	string_agg (distinct main.pub_date,' | ') as pub_date,
	main.instance_create_date,
	main.year_added_to_collection,
	case when sum (main.voyager_circs) is null then 0 else sum (main.voyager_circs) end as voyager_circs,
	case when sum (main.folio_circs) is null then 0 else sum (main.folio_circs) end as folio_circs,
	case when sum (main.total_circs) is null then 0 else sum (main.total_circs) end as total_circs,
	string_agg (distinct to_char (main.most_recent_loan::date,'mm/dd/yyyy'),' | ') as most_recent_loan,        
    string_agg (distinct case 
	  when po_lines.metadata__created_date is null then null 
	  when date_part ('month',po_lines.metadata__created_date::date) <'7' then concat ('FY' ,date_part ('year',po_lines.metadata__created_date::date)) 
      else concat ('FY', date_part ('year',po_lines.metadata__created_date::date)+1) 
      end,' | ') as fiscal_year_ordered,       
    po_lines.po_line_number,
    invoice_lines.quantity,
    invoice_invoices.vendor_invoice_no,
    invoice_lines.invoice_line_number,
    fg.name AS finance_group_name,
    ilfd.fund_name as folio_fund_name,
    ilfd.finance_fund_code as folio_fund_code,
    case when ilfd.fund_distribution_type = 'percentage' 
		then ((ilfd.invoice_line_total*ilfd.fund_distribution_value)/100)::numeric(12,2) else ilfd.fund_distribution_value end as cost

FROM main 
		left join folio_reporting.po_instance
		on main.instance_hrid = po_instance.pol_instance_hrid

		left join po_lines
        on po_instance.po_line_number = po_lines.po_line_number
              
        LEFT JOIN invoice_lines 
        ON po_lines.id = invoice_lines.po_line_id
        
        LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd
        ON invoice_lines.id = ilfd.invoice_line_id
        
        left join finance_funds as ff 
        on ilfd.finance_fund_code = ff.code 
        
        left join finance_group_fund_fiscal_years fgffy 
        on ff.id = fgffy.fund_id 
        
        left join finance_groups as fg 
        on fgffy.group_id = fg.id
        
        LEFT JOIN invoice_invoices 
        ON invoice_lines.invoice_id = invoice_invoices.id
 
group by 
	main.instance_hrid,
	main.instance_create_date,
	main.year_added_to_collection,                 
    po_lines.po_line_number,
    invoice_lines.quantity,
    invoice_invoices.vendor_invoice_no,
    invoice_lines.invoice_line_number,
    fg.name,
    ilfd.fund_name,
    ilfd.finance_fund_code,
    ilfd.fund_distribution_value,
    case when ilfd.fund_distribution_type = 'percentage' 
	then ((ilfd.invoice_line_total*ilfd.fund_distribution_value)/100)::numeric(12,2) else ilfd.fund_distribution_value end
  
order by string_agg (distinct main.lc_class,' | '), string_agg (distinct main.lc_class_number::varchar,' | '), string_agg (distinct main.whole_call_number,' | '), po_lines.po_line_number, invoice_invoices.vendor_invoice_no, invoice_lines.invoice_line_number

;
