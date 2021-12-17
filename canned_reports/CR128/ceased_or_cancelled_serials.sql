WITH parameters AS (
SELECT 
'Olin'::varchar AS location_filter --enter the location name IN BETWEEN the two % signs
),

inst AS
(SELECT 
       he.instance_id AS main_location_instance_id,
       iext.instance_hrid,
       he.holdings_id,
       he.holdings_hrid,
       he.call_number_prefix,
       he.call_number AS main_location_call_no,
       he.call_number_suffix,
       he.type_name,
       he.receipt_status
       
       FROM folio_reporting.holdings_ext AS he
               LEFT JOIN folio_reporting.instance_ext as iext 
               ON he.instance_id = iext.instance_id

       
       WHERE he.permanent_location_name = (SELECT location_filter FROM parameters)
       --and substring (he.call_number,1,3) like 'QA%'
       AND he.type_name = 'Serial'
           AND he.receipt_status = 'Not currently received'
           AND he.call_number != ''
       ),
       
 nts AS
(SELECT
    he.holdings_id,
    he.instance_id,
    string_agg(DISTINCT nt."note", ' | ') AS holdings_notes
    
    FROM folio_reporting.holdings_notes AS nt
    LEFT JOIN folio_reporting.holdings_ext AS he on he.holdings_id = nt.holdings_id
    
    GROUP BY he.holdings_id, he.instance_id
    ),
    
 statements AS 
 (SELECT

        holdings_id,
        string_agg(DISTINCT hs."statement", ' | ') AS holdings_summary
        
        FROM folio_reporting.holdings_statements AS hs 
        
        GROUP BY holdings_id
        ),
        
numvols AS 
 (SELECT
       holdings_id,

       count (ihi.item_id) AS number_of_volumes
       
        FROM folio_reporting.items_holdings_instances AS ihi
       LEFT JOIN inventory_items AS ii 
        ON ihi.item_id = ii.id
       
        GROUP BY holdings_id
       ),

main AS 
  (SELECT distinct

       inst.call_number_prefix,
       inst.main_location_call_no,
       inst.call_number_suffix,
       iext.instance_hrid,
       he.holdings_hrid,
       he.permanent_location_name,
       he.call_number_prefix as other_call_no_prefix,
       he.call_number AS other_location_call_number,
       he.call_number_suffix as other_loc_suffix,
       iext.title,
       iext.discovery_suppress AS suppress_instance,
       he.discovery_suppress AS suppress_holdings,
       he.type_name AS holdings_type_name,
       he.receipt_status,
       statements.holdings_summary,     
       nts.holdings_notes,      
       numvols.number_of_volumes   
              
FROM 
       inst           
       left JOIN folio_reporting.instance_ext as iext ON inst.main_location_instance_id = iext.instance_id
       left JOIN folio_reporting.holdings_ext as he ON iext.instance_id = he.instance_id
       left JOIN public.inventory_holdings AS ih ON he.holdings_id = ih.id
       LEFT JOIN statements ON ih.id = statements.holdings_id
       LEFT JOIN nts ON he.holdings_id = nts.holdings_id
       LEFT JOIN numvols ON he.holdings_id = numvols.holdings_id 
       
WHERE inst.main_location_call_no > ''
       --and ie.discovery_suppress = 'false'
       --and he.discovery_suppress = 'false'
           AND (he.permanent_location_name = (SELECT location_filter FROM parameters) OR he.permanent_location_name LIKE '%Annex%')

ORDER BY 
       inst.main_location_call_no, iext.instance_hrid, he.permanent_location_name, he.holdings_hrid, iext.title, he.call_number
       ),

main2 AS      
(SELECT
           main.call_number_prefix,
       main.main_location_call_no,
       main.call_number_suffix,
       main.instance_hrid,
       main.holdings_hrid,
       ii.effective_shelving_order,
       main.permanent_location_name,
       main.other_call_no_prefix,
       main.other_location_call_number,
       main.other_loc_suffix,
       main.title,
       main.suppress_instance,
       main.suppress_holdings,
       main.holdings_type_name,
       main.receipt_status,
       main.holdings_summary,
       main.holdings_notes,
       main.number_of_volumes
       
FROM main 
           LEFT JOIN folio_reporting.holdings_ext as he on he.holdings_hrid = main.holdings_hrid
           LEFT JOIN folio_reporting.items_holdings_instances as ihi on he.holdings_id = ihi.holdings_record_id
           LEFT JOIN inventory_items as ii on ihi.item_id = ii.id

       
ORDER BY 
          main.main_location_call_no, ii.effective_shelving_order, main.instance_hrid, main.holdings_hrid
          )
 --including effective_shelving_order gives many duplicates but is needed to order the results, so in the final query it is omitted.         
 SELECT DISTINCT
 	   main2.call_number_prefix,
       main2.main_location_call_no,
       main2.call_number_suffix,
       main2.instance_hrid,
       main2.holdings_hrid,
     --  ii.effective_shelving_order,
       main2.permanent_location_name,
       main2.other_call_no_prefix,
       main2.other_location_call_number,
       main2.other_loc_suffix,
       main2.title,
       main2.suppress_instance,
       main2.suppress_holdings,
       main2.holdings_type_name,
       main2.receipt_status,
       main2.holdings_summary,
       main2.holdings_notes,
       main2.number_of_volumes
 
    FROM main2
    ;


     
