-- MCR176
-- Annex items to be accessioned - check for duplicates 
-- This query is used by the Annex staff for checking lists of items to be accessioned against holdings already at the Annex, to prevent duplication
-- External list of barcodes has to be imported into local_shared schema, using a personal sign-in. 
-- In this query, the imported list is local_shared.cammie_barcodes. This file will need to be updated as new items arrive for accessioning.

--Query writer: Joanne Leary (jl41)
--Query posted on: 12/6/24

WITH instances AS 
(SELECT  
        ihi.title,
        he.permanent_location_name AS holdings_loc_name,
        CONCAT (ihi.call_number,' ', ihi.enumeration, ' ', ihi.chronology,
                CASE WHEN ihi.item_copy_number > '1' THEN concat (ihi.item_copy_number,'c.') ELSE '' END) AS whole_call_number,
        cammie_barcodes.item_barcode::varchar AS cammie_barcode,
        instext.instance_hrid,
        instext.instance_id,
        he.holdings_hrid,
        ihi.item_hrid,
        ihi.material_type_name,
        ihi.holdings_type_name,
        string_agg (distinct hs.holdings_statement,' | ') AS holdings_summary

FROM local_shared.cammie_barcodes 
        LEFT JOIN folio_derived.items_holdings_instances AS ihi 
        ON cammie_barcodes.item_barcode::varchar = ihi.barcode
        
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON ihi.holdings_id = he.holdings_id
        
        LEFT JOIN folio_derived.instance_ext AS instext 
        ON he.instance_id = instext.instance_id
        
        LEFT JOIN folio_derived.holdings_statements AS hs 
        ON he.holdings_id = hs.holdings_id
 group by 
 		ihi.title,
        he.permanent_location_name,
        CONCAT (ihi.call_number,' ', ihi.enumeration, ' ', ihi.chronology,
                CASE WHEN ihi.item_copy_number > '1' THEN concat (ihi.item_copy_number,'c.') ELSE '' END),
        cammie_barcodes.item_barcode::varchar,
        instext.instance_hrid,
        instext.instance_id,
        he.holdings_hrid,
        ihi.item_hrid,
        ihi.material_type_name,
        ihi.holdings_type_name
        
 ORDER BY whole_call_number--, ihi.enumeration, ihi.chronology, ihi.item_copy_number
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
        CASE WHEN he.permanent_location_name ILIKE '%annex%' THEN hs.holdings_statement ELSE ' - ' END as annex_holdings_summary

FROM instances 
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON instances.instance_id = he.instance_id
        
        LEFT JOIN folio_derived.holdings_statements AS hs 
        ON he.holdings_id = hs.holdings_id
        
WHERE he.permanent_location_name LIKE '%Annex%' OR he.permanent_location_name = instances.holdings_loc_name
;

