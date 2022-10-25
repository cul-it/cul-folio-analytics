--CR192
--Withdrawn_items

WITH parameters AS 
        (SELECT 
        '20210701'AS begin_date, -- enter a begin date in the format 'yyyymmdd'
        '20230701'AS end_date -- enter an end date in the format 'yyyymmdd'
),

holdnote AS 
(SELECT 
        to_char (current_date::date,'mm/dd/yyyy')AS todays_date,
        concat ((SELECT begin_date FROM parameters),' - ', (SELECT end_date FROM parameters))AS date_range,
        
        CASE WHEN 
                date_part ('month',substring (hn.note,'\d{1,}')::date) >'6' 
                THEN concat ('FY ', date_part ('year',substring (hn.note,'\d{1,}')::date) + 1) 
                ELSE concat ('FY ', date_part ('year',substring (hn.note,'\d{1,}')::date))
                END AS fiscal_year,
                
        ii.hrid AS instance_hrid,
        he.holdings_hrid AS holdings_hrid,       
        ii.title,
        ll.library_name,
        ll.location_name,
        TRIM (concat_ws (' ',he.call_number_prefix,he.call_number,he.call_number_suffix, CASE WHEN he.copy_number>'' 
                then concat ('c.',he.copy_number) else '' END))AS whole_call_number,
        he.type_name AS holdings_type_name,
        CASE WHEN ii.discovery_suppress = 'FALSE' OR  ii.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END AS instance_suppress,
        CASE WHEN he.discovery_suppress = 'FALSE' OR  he.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END AS holdings_suppress,
        hn.note AS note,
        substring (hn.note,'\d{1,}')::date AS withdrawal_date,
        
        CASE 
                WHEN substring (substring (hn.note,'pcs:\s{0,1}\d{1,}'), '\d{1,}') IS NULL 
                THEN '1' 
                ELSE substring (substring (hn.note,'pcs:\s{0,1}\d{1,}'), '\d{1,}') 
                END::INT AS number_of_pieces_withdrawn

FROM inventory_instances AS ii 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id 
        
        LEFT JOIN folio_reporting.holdings_notes AS hn 
        ON he.holdings_id = hn.holdings_id

WHERE 
        (hn.note ilike '%ttype:w%'
        AND substring (hn.note,'\d{1,}') >= (SELECT begin_date FROM parameters) 
        AND substring (hn.note,'\d{1,}') < (SELECT end_date FROM parameters))
),

admin1 AS 
(SELECT 
        to_char (current_date::date,'mm/dd/yyyy') AS todays_date,
        concat ((SELECT begin_date FROM parameters),' - ', (SELECT end_date FROM parameters))AS date_range,
        
        CASE WHEN 
                date_part ('month',substring (ian.administrative_note,'\d{1,}')::date) >'6' 
                THEN concat ('FY ', date_part ('year',substring (ian.administrative_note,'\d{1,}')::date) + 1) 
                ELSE concat ('FY ', date_part ('year',substring (ian.administrative_note,'\d{1,}')::date))
                END AS fiscal_year,
                
        ii.hrid AS instance_hrid,
        he.holdings_hrid,
        ii.title,
        ll.library_name,
        ll.location_name,       
        TRIM (concat_ws (' ',he.call_number_prefix,he.call_number,he.call_number_suffix, 
                CASE WHEN he.copy_number>'' then concat ('c.',he.copy_number) else '' END))AS whole_call_number,
        he.type_name AS holdings_type_name,
        CASE WHEN ii.discovery_suppress = 'FALSE' OR  ii.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END AS instance_suppress,
        CASE WHEN he.discovery_suppress = 'FALSE' OR  he.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END AS holdings_suppress,
        ian.administrative_note AS note,
        substring (ian.administrative_note,'\d{1,}')::date AS withdrawal_date,
        
        (CASE 
                WHEN ian.administrative_note is null THEN '0'
                WHEN substring (substring (ian.administrative_note,'lts\s{0,1}\d{1,}'), '\d{1,}') IS NULL THEN '1' 
                ELSE substring (substring (ian.administrative_note,'lts\s{0,1}\d{1,}'), '\d{1,}') 
                END)::INT AS number_of_pieces_withdrawn

FROM inventory_instances AS ii 
        INNER JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        INNER JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id 

        INNER JOIN local_core.instance_administrative_notes AS ian
        ON ii.id = ian.instance_id

WHERE 
        ian.administrative_note ilike '%ttype:w%'
        AND substring (ian.administrative_note,'\d{1,}') >=(SELECT begin_date FROM parameters)  
        AND substring (ian.administrative_note,'\d{1,}') < (SELECT end_date FROM parameters) 

),

admin2 AS 
(SELECT 
        admin1.todays_date,
        admin1.date_range,
        admin1.fiscal_year,
        admin1.instance_hrid,
        string_agg (admin1.holdings_hrid,' | ') AS holdings_hrid,
        admin1.title,
        string_agg (distinct admin1.library_name,' | ') AS library_name,
        string_agg (distinct admin1.location_name,' | ') AS location_name,        
        TRIM (string_agg (distinct admin1.whole_call_number,' | ')) AS whole_call_number,
        string_agg (distinct admin1.holdings_type_name,' | ') AS holdings_type_name,
        string_agg (distinct admin1.instance_suppress,' | ') AS instance_suppress,
        string_agg (distinct admin1.holdings_suppress,' | ') AS holdings_suppress,
        admin1.note,
        admin1.withdrawal_date,
        admin1.number_of_pieces_withdrawn

FROM admin1

GROUP BY 
        admin1.todays_date,
        admin1.date_range,
        admin1.fiscal_year,
        admin1.instance_hrid,
        admin1.title,
        admin1.withdrawal_date,
        admin1.note,    
        admin1.number_of_pieces_withdrawn
)

(SELECT 
        holdnote.*
        FROM holdnote 

        union
        
SELECT
        admin2.*
        FROM admin2
)

order by fiscal_year, title
;
