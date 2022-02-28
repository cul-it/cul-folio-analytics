WITH items AS 
(SELECT 
        bib_mfhd.bib_id::VARCHAR,
        mfhd_master.mfhd_id::VARCHAR,
        item.item_id::VARCHAR,

        to_char(bib_master.create_date::DATE,'mm/dd/yyyy') AS bib_create_date,
        to_char(mfhd_master.create_date::DATE,'mm/dd/yyyy') AS mfhd_create_date,
        to_char(item.create_date::DATE,'mm/dd/yyyy') AS item_create_date,
        
        bt.title,
        item_type.item_type_name,
        location.location_name,
        mfhd_master.suppress_in_opac,
        mfhd_master.display_call_no,
        substring (mfhd_master.normalized_call_no, '[A-Z]{1,3}') AS lc_class,
        substring (mfhd_master.display_call_no, '\d{1,}\.{0,}\d{0,}\s{0,1}') AS class_number,
        mfhd_item.item_enum,
        mfhd_item.chron,
        item.copy_number,
        item.historical_charges,
        item_barcode.item_barcode

FROM vger.bib_master 
        LEFT JOIN vger.bib_mfhd 
        ON bib_master.bib_id = bib_mfhd.bib_id 
        
        LEFT JOIN vger.bib_text AS bt 
        ON bib_master.bib_id = bt.bib_id
        
        LEFT JOIN vger.mfhd_master 
        ON bib_mfhd.mfhd_id = mfhd_master.mfhd_id 
        
        LEFT JOIN vger.mfhd_item 
        ON mfhd_master.mfhd_id = mfhd_item.mfhd_id 
        
        LEFT JOIN vger.location 
        ON mfhd_master.location_id = location.location_id
        
        LEFT JOIN vger.item 
        ON mfhd_item.item_id = item.item_id
        
        LEFT JOIN vger.item_type 
        ON item.item_type_id = item_type.item_type_id
        
        LEFT JOIN vger.item_barcode 
        ON item.item_id = item_barcode.item_id 
        
WHERE 
        --bt.bib_id::VARCHAR BETWEEN '115983' AND '116000'
        location.location_code LIKE 'jgsm%'
        AND location.location_code LIKE 'hote%'
        AND location.location_code != 'serv,remo'
        AND LOCATION.location_code not like '%anx%'
        --AND substring (mfhd_master.normalized_call_no, '[A-Z]{1,3}') = 'QA'
        --AND substring (mfhd_master.display_call_no, '\d{1,}\.{0,}\d{0,}\s{0,1}') like '276%'
        --AND mfhd_master.suppress_in_opac = 'N'
        --AND item.create_date >'2018-01-01'
        --AND item_type.item_type_name = 'book'
        --AND bib_text.bib_id = '367037'
        )
        
SELECT 
        items.bib_id,
        items.mfhd_id,
        items.suppress_in_opac,
        items.title,
        items.location_name,
        items.display_call_no,
        COUNT(items.item_id) as number_of_items,
        SUM(items.historical_charges) as total_charges

FROM items

GROUP BY 
        items.bib_id,
        items.mfhd_id,
        items.suppress_in_opac,
        items.title,
        items.location_name,
        items.display_call_no
;
