--MCR214B physical_item_counts_incl_items_rec_but_not_yet_cataloged
--created in FY25 for counts for CU DFS (Division of Financial Services)

/*With FY25, A&P uses this query each quarter to get volumes added counts for Cornell's Division of Financial 
Services (DFS). This query modifies MCR214, which provides item counts of physical materials by format type. MCR214
only includes counts of items cataloged and made ready for patrons' use. MCR214B additionally includes counts
for items received but not yet cataloged (whose call numbers include "%n process%"), which better meets DFS's
needs. Both queries exclude microforms.

DFS does not need volumes added retrospectively counted separately; it's counts only need to be divided by 
contract vs. endowed. Filter on "folio_format_type_adc_groups" to include only: Book, Serial, and Serial-Music.
12/2/24: added dfs_college_group field.*/



WITH 

marc_formats AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             substring(marc__t."content", 7, 2) AS leader0607
       FROM folio_source_record.marc__t 
       WHERE marc__t.field = '000'
),

micros AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             substring (marc__t."content",1,1) AS micro_by_007
       FROM folio_source_record.marc__t 
       WHERE marc__t.field = '007' 
),
                
unpurch AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             string_agg(DISTINCT marc__t."content", ', ') AS unpurchased 
       FROM folio_source_record.marc__t  
       WHERE marc__t.field = '899'
       AND marc__t.sf = 'a' 
       GROUP BY marc__t.instance_id 
),

                 
recs AS 
(SELECT 
       CASE WHEN 
       DATE_PART ('month',item_ext.created_date::DATE) > 6 
       THEN CONCAT ('FY ', DATE_PART ('year',item_ext.created_date::DATE) + 1) 
       ELSE CONCAT ('FY ', DATE_PART ('year',item_ext.created_date::DATE))
       END AS record_created_fiscal_year,
       marc_formats.leader0607,
       micros.micro_by_007,
       unpurch.unpurchased,
       instance__t.title,
       instance__t.hrid AS instance_hrid,
       holdings_ext.holdings_hrid,
       item_ext.item_hrid,
       loclibrary__t."name" AS holdings_library_name,    
       location__t.code AS holdings_location_code,
       lm_adc_location_translation_table.adc_loc_translation AS holdings_adc_loc_translation,
       lm_adc_location_translation_table.dfs_college_group,
       holdings_ext.permanent_location_name AS holdings_permanent_location_name, 
       TRIM (CONCAT (holdings_ext.call_number_prefix,' ',holdings_ext.call_number,' ',holdings_ext.call_number_suffix,' ',
             item_ext.enumeration, ' ',item_ext.chronology)) AS whole_call_number,
       vs_folio_physical_material_formats.leader0607description,
       vs_folio_physical_material_formats.folio_format_type,
       vs_folio_physical_material_formats.folio_format_type_adc_groups, 
       vs_folio_physical_material_formats.folio_format_type_acrl_nces_groups
       
       
FROM folio_inventory.instance__t 
       LEFT JOIN marc_formats
       ON instance__t.id = marc_formats.instance_id 
       
       LEFT JOIN micros
       ON instance__t.id = micros.instance_id 
       
       LEFT JOIN unpurch
       ON instance__t.id = unpurch.instance_id 
       
       LEFT JOIN folio_derived.holdings_ext 
       ON instance__t.id = holdings_ext.instance_id  
       LEFT JOIN folio_derived.item_ext 
       ON holdings_ext.id = item_ext.holdings_record_id  --5/20/25 changed FROM holdings_ext.holdings_id
       
       LEFT JOIN folio_inventory.location__t 
       ON holdings_ext.permanent_location_id = location__t.id  
       
       LEFT JOIN folio_inventory.loclibrary__t 
       ON holdings_ext.permanent_location_id = loclibrary__t.id 
       
       LEFT JOIN local_static.vs_folio_physical_material_formats --was local_shared 5/20/25
       ON marc_formats.leader0607 = vs_folio_physical_material_formats.leader0607 
       
       LEFT JOIN local_static.lm_adc_location_translation_table  -- was local_shared 5/20/25
       ON location__t.code = lm_adc_location_translation_table.adc_invloc_location_code
       
WHERE 
       (instance__t.discovery_suppress = 'false' OR instance__t.discovery_suppress IS NULL) 
       AND (holdings_ext.discovery_suppress = 'false' OR holdings_ext .discovery_suppress IS NULL) 
       AND (item_ext.discovery_suppress = 'false' OR item_ext.discovery_suppress IS NULL)
       AND (micros.micro_by_007 !='h' OR micros.micro_by_007 IS NULL OR micros.micro_by_007 = '' OR micros.micro_by_007 = ' ') 
       AND (location__t.code is not NULL OR location__t.code != '' OR location__t.code != ' ')
       AND (location__t.code NOT ILIKE ALL (ARRAY ['serv,remo', 'bd', 'cise', 'cons,opt', 'cts,rev', 'engr', 'Engr,wpe', 'law,ts', 'lts,ersm', 
             'mann,gate', 'mann,hort', 'mann,href', 'mann,ts', 'olin,ils', 'phys', 'agen', 'bind,circ', 'bioc', 'engr,ref', 'ent', 'fine,lock', 
             'food', 'hote,permres', 'hote,res', 'jgsm,permres', 'mann,permres', 'nus', 'rmc,ts', 'vet,permres', 'vet,ref', 'void', 'xtest', 'z-test location'])) 
      AND TRIM (CONCAT (holdings_ext.call_number_prefix,' ',holdings_ext.call_number,' ',holdings_ext.call_number_suffix,' ',
             item_ext.enumeration, ' ',item_ext.chronology)) NOT ILIKE '%bound%with%'

      AND TRIM (CONCAT (holdings_ext.call_number_prefix,' ',holdings_ext.call_number,' ',holdings_ext.call_number_suffix)) NOT ILIKE ALL
      (ARRAY ['%n order%', '%vailable for the library to purchase%', '%n selector%', '%film%','%fiche%', '%micro%', '%vault%'])
      AND instance__t.title NOT ILIKE '%[micro%]%'  
             )
       
SELECT DISTINCT 
       current_date::DATE,
       COUNT (DISTINCT recs.item_hrid) AS counDistinct_itemID,
       recs.record_created_fiscal_year,
       recs.holdings_permanent_location_name,
       recs.holdings_adc_loc_translation,
       recs.holdings_library_name,
       recs.dfs_college_group,
       recs.leader0607,
       recs.leader0607description,
       recs.folio_format_type,
       recs.folio_format_type_adc_groups, 
       recs.folio_format_type_acrl_nces_groups 
       
    FROM recs
    WHERE (recs.unpurchased NOT ILIKE '%couttspdbappr%' OR recs.unpurchased IS NULL  OR recs.unpurchased = '' OR recs.unpurchased = ' ') --moved down from above
       
    GROUP BY 
       current_date::DATE,
       recs.record_created_fiscal_year,
       recs.holdings_permanent_location_name,
       recs.holdings_adc_loc_translation,
       recs.dfs_college_group,
       recs.holdings_library_name,
       recs.leader0607,
       recs.leader0607description,
       recs.folio_format_type,
       recs.folio_format_type_adc_groups, 
       recs.folio_format_type_acrl_nces_groups 
       ;
