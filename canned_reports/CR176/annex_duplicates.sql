/* External list of barcodes has to be inmported into local schema. In this query, the list is local.cammie_barcodes, which will need to be replaced.*/ 

WITH instances AS 
(SELECT  
        ihi.title,
        he.permanent_location_name AS holdings_loc_name,
        CONCAT (ihi.call_number,' ', ihi.enumeration, ' ', ihi.chronology,
                CASE WHEN ihi.item_copy_number > '1' THEN concat (ihi.item_copy_number,' c.') ELSE '' END) AS whole_call_number,
        cammie_barcodes.item_barcode AS cammie_barcode,
        instext.instance_hrid,
        instext.instance_id,
        he.holdings_hrid,
        ihi.hrid AS item_hrid,
        ihi.material_type_name,
        ihi.holdings_type_name,
        hs."statement" AS holdings_summary

FROM local.cammie_barcodes 
        LEFT JOIN folio_reporting.items_holdings_instances AS ihi 
        ON cammie_barcodes.item_barcode = ihi.barcode
        
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ihi.holdings_id = he.holdings_id
        
        LEFT JOIN folio_reporting.instance_ext AS instext 
        ON he.instance_id = instext.instance_id
        
        LEFT JOIN folio_reporting.holdings_statements AS hs 
        ON he.holdings_id = hs.holdings_id
        
        ORDER BY whole_call_number, ihi.enumeration, ihi.chronology, ihi.item_copy_number
        )
        
SELECT 
        instances.title,
        instances.holdings_loc_name,
        instances.whole_call_number,
        instances.cammie_barcode,
        instances.instance_hrid,
        instances.holdings_hrid,
        instances.item_hrid,
        instances.material_type_name,
        instances.holdings_type_name,
        instances.holdings_summary,
        CASE WHEN he.permanent_location_name = instances.holdings_loc_name THEN ' -' ELSE he.permanent_location_name END AS annex_loc_name,
        CASE WHEN he.permanent_location_name ILIKE '%annex%' THEN he.call_number ELSE ' - ' END AS annex_call_number,
        CASE WHEN he.permanent_location_name ILIKE '%annex%' THEN he.holdings_hrid ELSE ' - ' END AS annex_holdings_hrid,
        CASE WHEN he.permanent_location_name ILIKE '%annex%' THEN hs."statement" ELSE ' - ' END as annex_holdings_summary

FROM instances 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON instances.instance_id = he.instance_id
        
        LEFT JOIN folio_reporting.holdings_statements AS hs 
        ON he.holdings_id = hs.holdings_id
        
WHERE he.permanent_location_name LIKE '%Annex%' OR he.permanent_location_name = instances.holdings_loc_name
;


