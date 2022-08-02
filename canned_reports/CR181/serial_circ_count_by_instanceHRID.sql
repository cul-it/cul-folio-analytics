WITH parameters AS  
(SELECT 
'2793166'::varchar AS instance_id_filter -- Enter the instance hrid
),

folio_circs AS 
        (SELECT
                li.item_id,
                li.hrid,
                COUNT(li.loan_id)::INTEGER AS folio_circ_count
        
        FROM folio_reporting.loans_items AS li 
        
        GROUP BY li.item_id, li.hrid
),

voy_circs AS 
        (SELECT 
                item.item_id::varchar,
                item.historical_charges::INTEGER AS voyager_circ_count
        
        FROM vger.item 
),

item_detail AS 

(SELECT 
        ii.title,
        ii.id,
        ii.hrid as instance_hrid,
        he.holdings_hrid,
        he.instance_id,
        ie.item_id,
        ie.item_hrid,
        he.discovery_suppress,
        he.permanent_location_name AS holdings_perm_loc_name,
        he.type_name AS holdings_type_name,
        concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) AS holdings_call_number,
        ie.barcode,
        ie.effective_location_name,
        CONCAT (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
                CASE WHEN ie.copy_number >'1' THEN concat (' c.',ie.copy_number) ELSE '' END) AS item_call_number,
        ie.material_type_name,
        CASE WHEN folio_circs.folio_circ_count IS NULL THEN 0 else folio_circs.folio_circ_count::INTEGER END AS folio_circ_count1,
        voy_circs.voyager_circ_count::INTEGER,
        (CASE WHEN folio_circs.folio_circ_count IS NULL THEN 0 ELSE folio_circs.folio_circ_count::INTEGER END + voy_circs.voyager_circ_count::INTEGER) AS total_circ_counts
        
FROM inventory_instances as ii 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN folio_reporting.item_ext AS ie 
        ON he.holdings_id = ie.holdings_record_id 
        
        LEFT JOIN folio_circs 
        ON ie.item_hrid::VARCHAR = folio_circs.hrid::VARCHAR
        
        LEFT JOIN voy_circs 
        ON ie.item_hrid::VARCHAR = voy_circs.item_id::VARCHAR

WHERE ii.hrid::VARCHAR = (SELECT instance_id_filter FROM parameters)

)

SELECT 
        item_detail.title,
        item_detail.instance_hrid,
        item_detail.holdings_hrid,
        item_detail.holdings_perm_loc_name,
        item_detail.holdings_call_number,
        item_detail.discovery_suppress AS holdings_suppress,
        item_detail.holdings_type_name,
        COUNT (item_detail.item_id) AS number_of_items,
        SUM (item_detail.total_circ_counts) AS total_circs


FROM item_detail 

GROUP BY 
        item_detail.title,
        item_detail.instance_hrid,
        item_detail.holdings_hrid,
        item_detail.holdings_perm_loc_name,
        item_detail.holdings_call_number,
        item_detail.discovery_suppress,
        item_detail.holdings_type_name

ORDER BY holdings_perm_loc_name, holdings_hrid
;

