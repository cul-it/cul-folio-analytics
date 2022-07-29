-- This query finds the summary of the number of volumes, the primary subject heading, pub date, year acquired and total circs (Voyager and Folio) for all titles in an LC class and location

WITH parameters AS 
(
SELECT
	'Olin'::VARCHAR AS location_name_filter,
	-- enter a location name such as 'Music Reference', 'Math', 'ILR', 'Olin - Annex', etc.
	'HM'::VARCHAR AS lc_class_filter
	-- enter up to a 3-letter LC class
),


recs as 
(SELECT 
        ii.title,
        ii.id as instance_id,
        ii.hrid AS instance_hrid,
        he.holdings_id,
        he.holdings_hrid,
        invitems.id as item_id,
        invitems.hrid AS item_hrid,
        ll.location_name,
        CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
                CASE WHEN invitems.copy_number >'1' THEN CONCAT (' c.',invitems.copy_number) ELSE '' END) AS whole_call_number,
        is2.subject as primary_subject,
        string_agg (distinct is3.subject,' | ') as all_subjects,
        string_agg (distinct ip.date_of_publication,' | ')::VARCHAR as pub_date,
        (CASE WHEN ii.status_updated_date::DATE >'2021-07-01' then DATE_PART ('year',ii.status_updated_date::DATE) 
                ELSE DATE_PART('year',bib_master.create_date::DATE) END)::VARCHAR as instance_create_date,
        substring (he.call_number, '[A-Z]{1,3}') AS lc_class,
        substring (he.call_number, '\d{1,}\.{0,}\d{0,}\s{0,1}') AS class_number,
        he.type_name as holdings_type_name,
        CASE WHEN item.historical_charges IS NULL THEN 0 ELSE item.historical_charges END as voyager_historical_charges

FROM inventory_instances as ii 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN inventory_items AS invitems 
        ON he.holdings_id = invitems.holdings_record_id
        
        left join folio_reporting.instance_subjects as is2 
        on ii.id = is2.instance_id 
        
        left join folio_reporting.instance_subjects as is3 
        on ii.id = is3.instance_id 
        
        left join folio_reporting.instance_publication as ip 
        on ii.id = ip.instance_id
        
        left join folio_reporting.locations_libraries as ll 
        on he.permanent_location_id = ll.location_id 
        
        left join vger.item 
        on ii.hrid = item.item_id::VARCHAR
        
        left join vger.bib_master 
        on ii.hrid = bib_master.bib_id::VARCHAR
        
WHERE (ll.location_name = (SELECT location_name_filter FROM parameters) OR (SELECT location_name_filter FROM parameters) ='')
        AND ((substring (he.call_number, '[A-Z]{1,3}') = (SELECT lc_class_filter FROM parameters) OR (SELECT lc_class_filter FROM parameters) =''))
        AND ((is2.subject_ordinality = 1) OR (is2.subject_ordinality IS NULL))

GROUP BY 

        ii.title,
        ii.id,
        ii.hrid,
        he.holdings_id,
        he.holdings_hrid,
        invitems.id,
        invitems.hrid,
        ll.location_name,
        CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
                case when invitems.copy_number >'1' THEN CONCAT (' c.',invitems.copy_number) ELSE '' END),
        is2.subject,
        (CASE WHEN ii.status_updated_date::DATE >'2021-07-01' THEN DATE_PART ('year',ii.status_updated_date::DATE) 
                ELSE DATE_PART('year',bib_master.create_date::DATE) END)::VARCHAR,
        substring (he.call_number, '[A-Z]{1,3}'),
        substring (he.call_number, '\d{1,}\.{0,}\d{0,}\s{0,1}'),
        he.type_name,
        item.historical_charges
        ),

circs as 
(SELECT 
        recs.title,
        recs.instance_id,
        recs.instance_hrid,
        recs.holdings_id,
        recs.holdings_hrid,
        recs.item_id,
        recs.item_hrid,
        recs.location_name,
        recs.whole_call_number,
        recs.primary_subject,
        recs.all_subjects,
        recs.pub_date,
        recs.instance_create_date,
        recs.lc_class,
        recs.class_number,
        recs.holdings_type_name,
        recs.voyager_historical_charges,
        count(li.loan_id) as folio_loans
        
FROM recs 
        LEFT JOIN folio_reporting.loans_items as li 
        ON recs.item_id = li.item_id
        
GROUP BY 
        recs.title,
        recs.instance_id,
        recs.instance_hrid,
        recs.holdings_id,
        recs.holdings_hrid,
        recs.item_id,
        recs.item_hrid,
        recs.location_name,
        recs.whole_call_number,
        recs.primary_subject,
        recs.all_subjects,
        recs.pub_date,
        recs.instance_create_date,
        recs.lc_class,
        recs.class_number,
        recs.holdings_type_name,
        recs.voyager_historical_charges
),

final1 as 
(SELECT 
        circs.title,
        circs.instance_id,
        circs.instance_hrid,
        circs.holdings_id,
        circs.holdings_hrid,
        circs.item_id,
        circs.item_hrid,
        circs.location_name,
        circs.whole_call_number,
        circs.primary_subject,
        circs.all_subjects,
        circs.pub_date,
        substring (circs.pub_date,'\d{1,4}') as norm_pub_date,
        circs.instance_create_date,
        circs.lc_class,
        circs.class_number,
        jlbfd.bib_format_display as bib_format_name,
        circs.holdings_type_name,
        circs.voyager_historical_charges,
        circs.folio_loans
        --invitems.effective_shelving_order
        
FROM circs 
        LEFT JOIN srs_marctab as sm 
        on circs.instance_id::VARCHAR = sm.instance_id::VARCHAR
        
        LEFT JOIN local.jl_bib_format_display_csv AS jlbfd
        on substring(sm.content,7,2) = jlbfd.bib_format
        
        LEFT JOIN inventory_items as invitems 
        on circs.item_id = invitems.id

WHERE sm.field = '000'

ORDER BY invitems.effective_shelving_order COLLATE "C"
)

select 
final1.location_name,
final1.bib_format_name,
final1.lc_class,
final1.class_number::NUMERIC,
final1.primary_subject,
--final1.pub_date,
final1.norm_pub_date,
final1.instance_create_date,
count(final1.item_id) as number_of_items,
sum(final1.voyager_historical_charges)+sum(final1.folio_loans) as total_loans

from final1 

group by

final1.location_name,
final1.bib_format_name,
final1.lc_class,
final1.class_number::NUMERIC,
final1.primary_subject,
final1.norm_pub_date,
final1.instance_create_date

order by bib_format_name, class_number, norm_pub_date, instance_create_date

;
