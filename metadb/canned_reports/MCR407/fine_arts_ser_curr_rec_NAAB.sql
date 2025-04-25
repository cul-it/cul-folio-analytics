--MCR207
--Fine_Arts_ser_curr_rec_NAAB
--Last updated: 1/6/25

--This query estimates the number of physical serial titles currently received in the Mui Ho Fine Arts Library.
--It uses two queries that search via purchase order and via holding records notes, combines instance HRIDs, 
--and then dedupes. Used in fall of 2024 for NAAB reporting.



--start by getting instance_hrids via purchase orders:

WITH getall as
(SELECT distinct
              poi.id,
              poi.title_or_package,
              poi.order_format,
              pi.order_type, 
              poi.receipt_status,
              poi.purchase_order_id,
              pll.pol_location_name,
              pi.pol_instance_id,
              pi.pol_instance_hrid,
              marc__t.instance_id,
              substring(marc__t."content", 7, 2) AS leader0607
              
FROM folio_orders.po_line__t AS poi
              LEFT JOIN folio_derived.po_lines_locations pll 
              ON poi.id = pll.pol_id
              
              LEFT JOIN local_static.vs_po_instance as pi --folio_derived.po_instance AS pi -- need to change to local_shared.vs_po_instance 
              ON poi.instance_id = pi.pol_instance_id
              
              LEFT Join folio_source_record.marc__t 
              ON poi.instance_id = marc__t.instance_id
              
              LEFT JOIN folio_derived.instance_ext AS ie 
              ON poi.instance_id = ie.instance_id
              
              LEFT JOIN folio_derived.holdings_ext AS he 
              ON ie.instance_id = he.instance_id
              
WHERE  pll.pol_location_name ILIKE ANY (ARRAY ['Fine%']) -- for other locations, 
              --replace 'Fine%' here, adding more location_names if needed, separated BY commas. 
              --The pol_location_name appears to be the location_name in the 
              --folio_derived.locations_libraries table.
              AND (poi.order_format = 'Physical Resource' OR poi.order_format = 'P/E Mix')
              --AND poi.receipt_status !='Cancelled'---- --1/3/25 this is what JL most recently had --changed from "Ongoing" to allow for partially received titles
              AND (poi.receipt_status = 'Ongoing' OR poi.receipt_status = 'Partially Received'
              OR poi.receipt_status = 'Awaiting Receipt' OR poi.receipt_status = 'Pending') --LM added this 1/3/25
              --and pi.order_type !='One-Time' --(Is only One-Time or Ongoing)
              and pi.bill_to not like '%LTS Standing%' --JL added this
              and pi.ship_to not like '%LTS Standing%' -- JL added this
              AND marc__t.field = '000'
              AND (ie.discovery_suppress = FALSE OR ie.discovery_suppress IS NULL)
              AND (he.discovery_suppress::boolean = FALSE OR he.discovery_suppress IS NULL)
),

viapol AS
              (SELECT distinct
              getall.pol_instance_hrid
              
              FROM getall
              WHERE getall.leader0607 like '%s'
),

--now move on to getting instance_id via holdings notes:

marcformat AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             substring(marc__t."content", 7, 2) AS leader0607
       FROM folio_source_record.marc__t 
       WHERE marc__t.field = '000'
),

recs as 
(
              select distinct
                      ii.hrid as instance_hrid,
                      ii.title,
                      marcformat.leader0607,
                      ll.library_name,
                      he.permanent_location_name,
                      string_agg (distinct he.receipt_status,' | ') as receipt_status
                     
              from     folio_inventory.instance__t as ii 
                                           LEFT JOIN marcformat 
                                           ON ii.id = marcformat.instance_id
                                           
                      left join folio_derived.holdings_ext as he 
                      on ii.id = he.instance_id::UUID 
                      
                      left join folio_derived.locations_libraries as ll 
                      on he.permanent_location_id = ll.location_id
                      
              WHERE ll.location_name ILIKE ANY (ARRAY ['Fine%']) -- replace 'Fine%' here, adding more 
              --Location_names if needed, separated BY commas. Or use the WHERE statement below to use
              --a mix of library name and location code.
              --WHERE (ll.library_name = 'Mui Ho Fine Arts Library' or ll.location_code ILIKE ANY (ARRAY ['fine,anx']))
                      and (he.discovery_suppress::boolean = FALSE or he.discovery_suppress is NULL)
                      AND (ii.discovery_suppress = FALSE OR ii.discovery_suppress IS NULL)
              group by 
                      ii.hrid,
                      ii.title,
                      leader0607,
                      ll.library_name,
                      he.permanent_location_name
),

viahold AS
(select 
        --recs.library_name,
        --recs.location_code,
        --recs.receipt_status,
        recs.instance_hrid
        --recs.title
        FROM recs
        
        WHERE recs.leader0607 LIKE '%s'
        AND (recs.receipt_status ILIKE 'Cur%tly rec%'--ANY(ARRAY['Currently received%', '%| currently received%'])
               or recs.receipt_status ilike '%| currently received%') --needs TO be added because OF agging.
),
        
--now merge the two sets of instance_hrids together:
        
mergeit AS
(
              SELECT 
                             viapol.pol_instance_hrid AS instance_hrida
              FROM viapol
              
              UNION 
              
              SELECT
                             viahold.instance_hrid AS instance_hrida
              FROM viahold
)

--then count distinct

SELECT 
              count (DISTINCT mergeit.instance_hrida)
FROM mergeit
;

