-AHR135
--Vet_faculty_development_in_education
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 10/05/23
/*10-5-23: this query finds the circ usage since 2019 for the Faculty Development in Education collection at the Vet Library (from supplied barcodes)*/

WITH voycircs AS 
(SELECT
       cta.item_id::varchar AS item_hrid,
       date_part ('year',cta.charge_date::date) AS year_of_circulation,
       count (DISTINCT cta.circ_transaction_id) AS circs
       
       FROM vger.circ_trans_archive AS cta 
       WHERE date_part ('year',cta.charge_date::date)>='2019'
       GROUP BY cta.item_id::varchar, date_part ('year',cta.charge_date::date)
),

voycircsmax AS 
(SELECT 
       voycircs.item_hrid,
       max(voycircs.year_of_circulation) AS last_year_of_checkout
       FROM voycircs
       GROUP BY voycircs.item_hrid
),

foliocircs AS
(SELECT 
        li.hrid AS item_hrid,
       date_part ('year',li.loan_date::date) AS year_of_circulation,
       count (DISTINCT li.loan_id) AS circs
       
        FROM folio_reporting.loans_items AS li
       WHERE li.hrid IS NOT null
       GROUP BY li.hrid, date_part ('year',li.loan_date::date)
),

foliocircsmax AS 
(SELECT
       foliocircs.item_hrid,
       max (foliocircs.year_of_circulation) AS last_year_of_checkout
       FROM foliocircs 
       GROUP BY foliocircs.item_hrid
)

select 
       jvfdb.seq_no,
       invitems.barcode,
       ii.title,
       he.permanent_location_name as holdings_perm_loc_name,
       trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
              case when invitems.copy_number >'1' then concat ('c.',invitems.copy_number) else '' end)) as whole_call_number,      
       ie.status_name as item_status_name,
       to_char (ie.status_date::date,'mm/dd/yyyy') as item_status_date,
       string_agg (distinct hn.note,' | ') as holdings_notes,
       to_char (coalesce (item.create_date::date,invitems.metadata__created_date::date),'mm/dd/yyyy') as item_create_date,
       CASE when sum (voycircs.circs) IS NULL THEN 0 ELSE sum (voycircs.circs) END AS total_voyager_circs_2019_to_2020,
       CASE WHEN sum (foliocircs.circs) IS NULL THEN 0 ELSE sum (foliocircs.circs) END AS total_folio_circs_2021_to_2023,
       coalesce (foliocircsmax.last_year_of_checkout, voycircsmax.last_year_of_checkout)::varchar as most_recent_year_of_checkout,
       ii.hrid as instance_hrid,
       he.holdings_hrid,
       invitems.hrid as item_hrid
              
FROM inventory_instances AS ii 
       LEFT JOIN folio_reporting.holdings_ext AS he 
       ON ii.id = he.instance_id
       
       left join folio_reporting.holdings_notes as hn 
       on he.holdings_id = hn.holdings_id

       LEFT JOIN inventory_items AS invitems 
       ON he.holdings_id = invitems.holdings_record_id 
       
       left JOIN folio_reporting.item_ext AS ie 
       ON invitems.id = ie.item_id
       
       inner join local.jl_vet_fac_dev_barcodes jvfdb 
       on ie.barcode = jvfdb.barcode
       
       left join vger.item 
       on invitems.hrid = item.item_id::varchar
       
       LEFT JOIN voycircs 
       ON ie.item_hrid = voycircs.item_hrid
       
       LEFT JOIN voycircsmax 
       ON ie.item_hrid = voycircsmax.item_hrid
       
       LEFT JOIN foliocircs 
       ON ie.item_hrid = foliocircs.item_hrid
       
       LEFT JOIN foliocircsmax 
       ON ie.item_hrid = foliocircsmax.item_hrid
       

group by 
       jvfdb.seq_no,
       ii.hrid,
       he.holdings_hrid,
       invitems.hrid,
       he.permanent_location_name,
       ii.title,
       trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
              case when invitems.copy_number >'1' then concat ('c.',invitems.copy_number) else '' end)),
       ie.status_name,
       to_char (ie.status_date::date,'mm/dd/yyyy'), 
       invitems.barcode,
       to_char (coalesce (item.create_date::date,invitems.metadata__created_date::date),'mm/dd/yyyy'),
       coalesce (foliocircsmax.last_year_of_checkout, voycircsmax.last_year_of_checkout)::varchar
;
