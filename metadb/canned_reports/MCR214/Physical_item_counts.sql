--MCR214
--Physical Item Counts
--LDP Query writer: Vandana Shah (vp25)
--Query ported to Metadb by: Linda Miller (lm15)
--Ported query reviewed by: Joanne Leary (jl41), Vandana Shah (vp25)
--Date posted: 6/4/24

--Revised 12-18-25 to connect to records_lb in order to remove marc__t duplicates
--Revised 9-11-25 to show owning library, endowed or contact college, and correct item counts; 
	-- replaced derived tables with source tables, added Where condition "item__t.hrid is not null" (line 107), corrected join to location__t.library_id = loclibrary__id
--Revised 12/20/25 to include joins to the records.lb table to exclude duplicate instance_ids due to a metadb glitch that is keeping some old as well as new record rows. 

--This query provides item counts of physical materials, by format type. It excludes microforms,and, because of how we filter for microforms, any motion pictures with '%film%' in their call numbers. 
--This query is primarily used to get counts for annual CUL reporting.




WITH marc_formats AS (
     (SELECT DISTINCT sm.instance_id, 
        COALESCE(SUBSTRING(sm.content, 7, 2), '--') AS leader0607
    FROM folio_source_record.marc__t AS sm
    LEFT JOIN folio_source_record.records_lb AS rl ON sm.instance_id=rl.external_id 
    AND sm.srs_id  = rl.id
    
    WHERE rl.state = 'ACTUAL'
    AND sm.field = '000')
        ),


micros AS
       (SELECT DISTINCT 
             sm.instance_id, 
             coalesce (substring (sm.content,1,1),'-') AS micro_by_007
             
       FROM folio_source_record.marc__t AS sm
       LEFT JOIN folio_source_record.records_lb AS rl ON sm.instance_id=rl.external_id 
    	AND sm.srs_id  = rl.id
    	
    	WHERE rl.state = 'ACTUAL'
       	AND sm.field = '007' 
),
                
unpurch AS
       (SELECT DISTINCT 
             sm.instance_id, 
             string_agg(DISTINCT sm.content, ', ') AS unpurchased 
             
       FROM folio_source_record.marc__t  AS sm
       LEFT JOIN folio_source_record.records_lb AS rl ON sm.instance_id=rl.external_id 
    	AND sm.srs_id  = rl.id
    	
    	WHERE rl.state = 'ACTUAL'
        AND sm.field = '899'
       	AND sm.sf = 'a' 
       	
       GROUP BY sm.instance_id 
),

                 
recs AS 
(
SELECT 
       CASE       
       	when DATE_PART ('month',(item.jsonb#>>'{metadata,createdDate}')::date) > 6 
       	THEN CONCAT ('FY ', DATE_PART ('year',(item.jsonb#>>'{metadata,createdDate}')::date) + 1) 
       	ELSE CONCAT ('FY ', DATE_PART ('year',(item.jsonb#>>'{metadata,createdDate}')::date))
       	END AS record_created_fiscal_year,
       marc_formats.leader0607,
       micros.micro_by_007,
       unpurch.unpurchased,
       instance__t.title,
       instance__t.hrid AS instance_hrid,
       hrt.hrid as holdings_hrid,
       item__t.hrid as item_hrid,
       loclibrary__t.name AS holdings_library_name,    
       location__t.code AS holdings_location_code,
       lm_adc_location_translation_table.adc_loc_translation AS holdings_adc_loc_translation,
       lm_adc_location_translation_table.dfs_college_group,
       location__t.name as holdings_permanent_location_name, --hrt.permanent_location_name AS holdings_permanent_location_name, 
       TRIM (CONCAT (hrt.call_number_prefix,' ',hrt.call_number,' ',hrt.call_number_suffix,' ',
             item__t.enumeration, ' ',item__t.chronology)) AS whole_call_number,
       vs_folio_physical_material_formats.leader0607description,
       vs_folio_physical_material_formats.folio_format_type,
       vs_folio_physical_material_formats.folio_format_type_adc_groups, 
       vs_folio_physical_material_formats.folio_format_type_acrl_nces_groups
       
       
FROM folio_inventory.instance__t        
       
       LEFT JOIN folio_inventory.holdings_record__t as hrt --folio_derived.holdings_ext 
       ON instance__t.id = hrt.instance_id 
       
       LEFT JOIN folio_inventory.item__t --folio_derived.item_ext 
       ON hrt.id = item__t.holdings_record_id
       
       left join folio_inventory.item 
       on item__t.id = item.id
       
       LEFT JOIN folio_inventory.location__t 
       ON hrt.permanent_location_id = location__t.id  
       
       LEFT JOIN folio_inventory.loclibrary__t 
       ON location__t.library_id = loclibrary__t.id --holdings_ext.permanent_location_id = loclibrary__t.id 
       
       LEFT JOIN marc_formats
       ON instance__t.id = marc_formats.instance_id 
       
       LEFT JOIN local_static.vs_folio_physical_material_formats 
       ON marc_formats.leader0607 = vs_folio_physical_material_formats.leader0607 
       
       LEFT JOIN local_static.lm_adc_location_translation_table 
       ON location__t.code = lm_adc_location_translation_table.adc_invloc_location_code
      
       LEFT JOIN micros
       ON instance__t.id = micros.instance_id 
       
       LEFT JOIN unpurch
       ON instance__t.id = unpurch.instance_id
       
WHERE 
       (instance__t.discovery_suppress = false OR instance__t.discovery_suppress IS NULL)
       and item__t.hrid is not null
       AND (hrt.discovery_suppress = false OR hrt.discovery_suppress IS NULL) 
       AND (item__t.discovery_suppress = false OR item__t.discovery_suppress IS NULL)
       AND (micros.micro_by_007 !='h' OR micros.micro_by_007 IS NULL OR micros.micro_by_007 = '' OR micros.micro_by_007 = ' ') 
       AND (location__t.code is not NULL OR location__t.code != '' OR location__t.code != ' ')
       AND (location__t.code NOT ILIKE ALL (ARRAY ['serv,remo', 'bd', 'cise', 'cons,opt', 'cts,rev', 'engr', 'Engr,wpe', 'law,ts', 'lts,ersm', 
             'mann,gate', 'mann,hort', 'mann,href', 'mann,ts', 'olin,ils', 'phys', 'agen', 'bind,circ', 'bioc', 'engr,ref', 'ent', 'fine,lock', 
             'food', 'hote,permres', 'hote,res', 'jgsm,permres', 'mann,permres', 'nus', 'rmc,ts', 'vet,permres', 'vet,ref', 'void', 'xtest', 'z-test location'])) 
      AND TRIM (CONCAT (hrt.call_number_prefix,' ',hrt.call_number,' ',hrt.call_number_suffix,' ',
             item__t.enumeration, ' ',item__t.chronology)) NOT ILIKE '%bound%with%'
      AND TRIM (CONCAT (hrt.call_number_prefix,' ',hrt.call_number,' ',hrt.call_number_suffix)) NOT ILIKE ALL
                (ARRAY ['%n order%', '%n process%', '%vailable for the library to purchase%', '%n selector%', '%film%','%fiche%', '%micro%', '%vault%'])
      AND instance__t.title NOT ILIKE '%[micro%]%'  
)             
       
SELECT
       current_date::DATE,
       COUNT (DISTINCT recs.item_hrid) AS counDistinct_itemID,
       recs.record_created_fiscal_year,
       recs.holdings_library_name,
       recs.holdings_permanent_location_name,
       recs.dfs_college_group,
       recs.holdings_adc_loc_translation,       
       recs.leader0607,
       recs.leader0607description,
       recs.folio_format_type,
       recs.folio_format_type_adc_groups, 
       recs.folio_format_type_acrl_nces_groups
       --COUNT (recs.item_hrid) AS counDistinct_itemID
       
    FROM recs
    WHERE (recs.unpurchased NOT ILIKE '%couttspdbappr%' OR recs.unpurchased IS null OR recs.unpurchased = '' OR recs.unpurchased = ' ') --moved down from above
       
    GROUP BY 
    	recs.record_created_fiscal_year,
    	recs.holdings_library_name,
       current_date::DATE,
       recs.record_created_fiscal_year,
       recs.holdings_permanent_location_name,
		recs.dfs_college_group,
       recs.holdings_adc_loc_translation,       
       recs.leader0607,
       recs.leader0607description,
       recs.folio_format_type,
       recs.folio_format_type_adc_groups, 
       recs.folio_format_type_acrl_nces_groups        
       ;
