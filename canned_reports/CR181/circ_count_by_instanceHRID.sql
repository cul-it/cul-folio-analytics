WITH parameters AS 
(SELECT 
''::varchar as instance_hrid_filter
),

items AS 
(SELECT 
        ii.title,
        ii.hrid as instance_hrid,
        he.holdings_hrid,
        invitems.hrid as item_hrid,
        he.permanent_location_name,
        TRIM (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix, 
                CASE WHEN he.copy_number >'1' THEN concat ('c.',he.copy_number) ELSE '' END)) AS whole_call_number,
        COUNT (li.loan_id) AS folio_circs,
        item.historical_charges::integer AS voyager_circs

FROM inventory_instances ii 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN inventory_items AS invitems 
        ON he.holdings_id = invitems.holdings_record_id 
        
        LEFT JOIN vger.item 
        ON invitems.hrid::varchar = item.item_id::varchar
        
        LEFT JOIN folio_reporting.loans_items AS li 
        ON invitems.id = li.item_id

WHERE ii.hrid = (SELECT instance_hrid_filter FROM parameters)

GROUP BY 
        ii.title,
        ii.hrid,
        he.holdings_hrid,
        invitems.hrid,
        he.permanent_location_name,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix, 
        he.copy_number,
        item.historical_charges::integer
)

SELECT 
        items.title,
        items.instance_hrid,
        items.holdings_hrid,
        items.permanent_location_name,
        items.whole_call_number,
        COUNT (items.item_hrid) AS number_of_items,
        SUM (items.folio_circs) + SUM (items.voyager_circs) AS total_circs

FROM items 

GROUP BY 
        items.title,
        items.instance_hrid,
        items.holdings_hrid,
        items.permanent_location_name,
        items.whole_call_number
;



