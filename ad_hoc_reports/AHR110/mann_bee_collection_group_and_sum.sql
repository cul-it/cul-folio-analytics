WITH recs AS 
(SELECT DISTINCT
       he.permanent_location_name,
       iext.title,
       iext.instance_hrid,
       he.holdings_hrid,
       ii.hrid AS item_hrid,
       he.discovery_suppress,
       he.call_number_prefix,
       he.call_number AS main_location_call_no,
       he.call_number_suffix,
       he.copy_number,
       CONCAT (he.call_number_prefix,' ',he.call_number,' ', he.call_number_suffix,
          CASE WHEN he.copy_number >'1' THEN CONCAT (' c.',he.copy_number) ELSE '' END) AS holdings_call_number,
       SUBSTRING (call_number,'^([a-zA-z]{1,3})') AS lc_class,
       SUBSTRING (call_number,'\d{1,}\.{0,}\d{0,}')::NUMERIC AS lc_class_number,
       he.type_name AS holdings_type_name,
       he.receipt_status,
       SUBSTRING (STRING_AGG (DISTINCT ip.date_of_publication,' | '),'\d{1,4}')  AS pub_date,
       
       CASE 
        WHEN substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}') IS NULL THEN ' No pub date '
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '13' THEN '14th century'
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '14' THEN '15th century'
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '15' THEN '16th century'
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '16' THEN '17th century'
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '17' THEN '18th century'
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '18' THEN '19th century'
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '19' THEN '20th century'
       WHEN substring (substring (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}'),1,2) = '20' THEN '21st century'
       ELSE 'Undetermined' END AS pub_date_range,
       
       instsubj.subject AS primary_subject,
       STRING_AGG (DISTINCT instsubj2.subject,' | ') AS all_subjects,
       instlang.language AS language_code,
       jllc."Language Name"
       
       
       FROM folio_reporting.holdings_ext AS he
               LEFT JOIN folio_reporting.instance_ext AS iext 
               ON he.instance_id = iext.instance_id
               
               LEFT JOIN inventory_items AS ii 
               ON he.holdings_id = ii.holdings_record_id 
               
               LEFT JOIN folio_reporting.instance_publication AS ip 
               ON iext.instance_id = ip.instance_id
               
               LEFT JOIN folio_reporting.instance_subjects AS instsubj 
               ON iext.instance_hrid = instsubj.instance_hrid 
               
               LEFT JOIN folio_reporting.instance_subjects AS instsubj2 
               ON iext.instance_hrid = instsubj2.instance_hrid
               
               LEFT JOIN folio_reporting.instance_languages AS instlang 
               ON iext.instance_hrid = instlang.instance_hrid
               
               LEFT JOIN local.jl_language_codes as jllc 
               ON instlang.language = jllc."Language Code" 
                                        
       WHERE (he.permanent_location_name LIKE 'Geneva%' OR he.permanent_location_name LIKE 'Mann%')
                AND (SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') = 'QL'
                AND SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')::NUMERIC >=563
                AND SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')::NUMERIC <=569.4
                AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
                AND (instsubj.subject_ordinality = 1 OR instsubj.subject_ordinality IS NULL)
                AND (instlang.language_ordinality = 1 OR instlang.language_ordinality IS NULL)
                )

        OR 
        
                (he.permanent_location_name LIKE 'Geneva%' or he.permanent_location_name LIKE 'Mann%')
                AND (SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') = 'SF'
                AND (SUBSTRING  (he.call_number,'\d{1,}\.{0,}\d{0,}')::NUMERIC >=521)
                AND (SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')::NUMERIC <=539)
                AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
                AND (instsubj.subject_ordinality = 1 OR instsubj.subject_ordinality IS NULL)
                AND (instlang.language_ordinality = 1 OR instlang.language_ordinality IS NULL)
                )
        
        GROUP BY 
               he.permanent_location_name,
               iext.title,
               iext.instance_hrid,
               he.holdings_id,
               he.holdings_hrid,
               ii.hrid,
               he.discovery_suppress,
               he.call_number_prefix,
               he.call_number,
               he.call_number_suffix,
               he.copy_number,
               CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,
                        CASE WHEN he.copy_number >'1' THEN CONCAT (' c.',he.copy_number) ELSE '' END),
               SUBSTRING (he.call_number,'^([a-zA-z]{1,3})'),
                   SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')::NUMERIC,
               he.type_name,
               he.receipt_status,
               instsubj.subject,
               instlang.language,
               jllc."Language Name"
),

counts AS 
(SELECT 
        recs.permanent_location_name,
        recs.holdings_type_name,
        recs.lc_class,
        recs.lc_class_number,
        recs.primary_subject,
        recs.instance_hrid,
        recs.pub_date,
        recs.pub_date_range,
        recs.language_code,
        recs."Language Name",
        count (recs.item_hrid) as number_of_volumes

FROM recs 

GROUP BY 
        recs.permanent_location_name,
        recs.holdings_type_name,
        recs.lc_class,
        recs.lc_class_number,
        recs.primary_subject,
        recs.instance_hrid,
        recs.pub_date,
        recs.pub_date_range,
        recs.language_code,
        recs."Language Name"
)

SELECT 
        counts.permanent_location_name,
        counts.holdings_type_name,
        counts.lc_class,
        counts.lc_class_number,
        counts.primary_subject,
        counts.pub_date_range,
        counts.language_code,
        counts."Language Name",
        COUNT (counts.instance_hrid) AS number_of_titles,
        SUM (counts.number_of_volumes) AS number_of_vols

FROM counts 

GROUP BY 
        counts.permanent_location_name,
        counts.holdings_type_name,
        counts.lc_class,
        counts.lc_class_number,
        counts.primary_subject,
        counts.pub_date_range,
        counts.language_code,
        counts."Language Name"
;
