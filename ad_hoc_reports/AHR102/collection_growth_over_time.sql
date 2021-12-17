with bibs as 
                (select 
                bib_id,
                year_bib_created
                
                from local.jl_bibid_year_lc_csv
                ),

main as 
(select distinct
        bibs.bib_id,
        bibs.year_bib_created,
                case when bibs.year_bib_created is null 
                then substring(ie.record_created_date,1,4)
                else bibs.year_bib_created
            end as year_acquired,
        ie.instance_hrid,
        ie.instance_id,
        he.holdings_hrid,
        he.type_name,
        ie.title,
        to_char(ie.record_created_date::DATE,'mm/dd/yyyy') as instance_create_date,
        to_char(ie.cataloged_date::DATE,'mm/dd/yyyy') as cataloged_date,
        ll.library_name,
        he.permanent_location_name,
        he.call_number,
        substring(he.call_number,1,2) as lc_class,
        invi.effective_shelving_order


from 
        folio_reporting.instance_ext as ie 
        left join bibs 
        on ie.instance_hrid = bibs.bib_id
        
        left join folio_reporting.holdings_ext as he
        on ie.instance_id = he.instance_id 

        left join folio_reporting.locations_libraries as ll 
        on he.permanent_location_id = ll.location_id
        
        left join inventory_items as invi 
        on he.holdings_id = invi.holdings_record_id
        

where 
        (ie.record_created_date >'2021-07-01'
        and substring(he.call_number,1,2) in ('QC','QD'))
        or bibs.year_bib_created <'2022'
        ),
        
subj as 
        (select 
        main.instance_id,
        "is".instance_id as sinstanceid,
        "is".subject as subjects 
        
        from folio_reporting.instance_subjects as "is"
        left join main on main.instance_id = "is".instance_id
        )

--Final step

select 
        main.instance_hrid,
        main.instance_id,
        main.year_acquired,
        main.holdings_hrid,
        main.type_name,
        main.title,
        main.instance_create_date,
        main.library_name,
        main.permanent_location_name,
        main.call_number,
        main.lc_class,
        subj.subjects,
        main.effective_shelving_order
        
from main
        left join subj
        on main.instance_id = subj.sinstanceid


order by main.effective_shelving_order;
        
