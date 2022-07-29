WITH recs AS 

(SELECT DISTINCT

        ii.hrid AS instance_hrid,
        he.holdings_hrid,
        iext.item_hrid,
        ii.title,
        he.permanent_location_name,
        CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,
                CASE WHEN he.copy_number >'1' THEN CONCAT (' c.',he.copy_number) ELSE '' END) AS holdings_call_number,
        SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') AS lc_class,
        SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}') AS lc_class_number,
        bt.begin_pub_date AS voyager_pub_date,
        SUBSTRING (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}')  AS folio_pub_date,
        CASE WHEN SUBSTRING (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}') IS NULL THEN bt.begin_pub_date 
                ELSE SUBSTRING (string_agg (DISTINCT ip.date_of_publication,' | '),'\d{1,4}') END as pub_date,               
        he.type_name AS holdings_type_name,
        he.receipt_status,
        he.discovery_suppress,
        instsubj.subject AS primary_subject,
        string_agg (DISTINCT instsubj2.subject,' | ') AS all_subjects,
        instlang.language AS language_code,
        jllc."Language Name"

FROM folio_reporting.holdings_ext AS he 
        LEFT JOIN inventory_instances AS ii 
        ON he.instance_id = ii.id 
        
        LEFT JOIN vger.bib_text AS bt 
        ON ii.hrid = bt.bib_id::VARCHAR
        
        LEFT JOIN folio_reporting.item_ext AS iext 
        ON he.holdings_id = iext.holdings_record_id

        LEFT JOIN folio_reporting.instance_publication ip 
        ON ii.id = ip.instance_id
        
        LEFT JOIN folio_reporting.instance_subjects AS instsubj 
        ON ii.id = instsubj.instance_id 
               
        LEFT JOIN folio_reporting.instance_subjects AS instsubj2 
        ON ii.id = instsubj2.instance_id
               
        LEFT JOIN folio_reporting.instance_languages AS instlang 
        ON ii.id = instlang.instance_id
               
        LEFT JOIN local.jl_language_codes AS jllc 
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

        ii.hrid,
        he.holdings_hrid,
        iext.item_hrid,
        ii.title,
        he.permanent_location_name,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        he.copy_number,
        bt.begin_pub_date,
        he.type_name,
        he.receipt_status,
        he.discovery_suppress,
        instsubj.subject,
        instlang.language,
        jllc."Language Name"
    
ORDER BY he.permanent_location_name, lc_class, lc_class_number
)

SELECT 
        recs.*,
        CASE 
        WHEN substring (recs.pub_date,1,2) IS NULL THEN 'Undetermined'
       WHEN substring (recs.pub_date,1,2) = '15' THEN '16th century'
       WHEN substring (recs.pub_date,1,2) = '16' THEN '17th century'
       WHEN substring (recs.pub_date,1,2) = '17' THEN '18th century'
       WHEN substring (recs.pub_date,1,2) = '18' THEN '19th century'
       WHEN substring (recs.pub_date,1,2) = '19' THEN '20th century'
       WHEN substring (recs.pub_date,1,2) = '20' THEN '21st century'
       ELSE 'Undetermined' END AS pub_century
       
     FROM recs 
     ;
