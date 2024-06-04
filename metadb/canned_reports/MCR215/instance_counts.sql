--MCR215
--Unique Instance Counts (physical materials)
--LDP Query writer: Vandana Shah (vp25)
--Query ported to Metadb by: Linda Miller (lm15)
--Ported query reviewed by: Joanne Leary (jl41), Vandana Shah (vp25)
--Date posted: 6/4/24

--This query provides counts of unique titles (instances) of physical items, by format type. It excludes microforms, and, because of how we filter for microforms, any motion pictures with '%film%' in their call numbers. 
--This query is primarily used to get counts for annual CUL reporting.


WITH
                   
marc_formats AS
       (SELECT DISTINCT 
             marc__t.instance_id,
             substring(marc__t."content", 7, 2) AS "leader0607"
       FROM folio_source_record.marc__t 
       WHERE  marc__t.field = '000'),

micros AS
       (SELECT DISTINCT 
             marc__t.instance_id,
             substring (marc__t."content",1,1) AS micro_by_007
          FROM folio_source_record.marc__t 
          WHERE  marc__t.field = '007' 
                ),


unpurch AS
(SELECT DISTINCT 
     marc__t.instance_id,
     string_agg(DISTINCT marc__t."content", ',') AS "unpurchased"
     FROM folio_source_record.marc__t 
WHERE marc__t.field LIKE '899'
    AND marc__t.sf LIKE 'a'
    GROUP BY marc__t.instance_id
   ),     
    
     
 merge1 AS
(SELECT DISTINCT
       holdings_ext.instance_id,
       marc_formats.leader0607, 
       unpurch.unpurchased,
       vs_folio_physical_material_formats.leader0607description,
       vs_folio_physical_material_formats.folio_format_type,
       vs_folio_physical_material_formats.folio_format_type_adc_groups, 
       vs_folio_physical_material_formats.folio_format_type_acrl_nces_groups,
       micros.micro_by_007
                     
       FROM folio_derived.instance_ext 
       LEFT JOIN marc_formats ON instance_ext.instance_id = marc_formats.instance_id  
       LEFT JOIN micros ON instance_ext.instance_id = micros.instance_id  
       LEFT JOIN unpurch ON instance_ext.instance_id = unpurch.instance_id 
       LEFT JOIN folio_derived.holdings_ext ON instance_ext.instance_id = holdings_ext.instance_id   
       LEFT JOIN folio_inventory.location__t ON holdings_ext.permanent_location_id = location__t.id  
       LEFT JOIN local_shared.vs_folio_physical_material_formats ON marc_formats.leader0607=vs_folio_physical_material_formats.leader0607  
        
 /*Excludes serv,remo and Mann Gateway which are all e-materials and are counted in a separate query. Also excludes materials 
* from the following locations as they: no longer exist; are not yet received/cataloged; are not owned by the Library; etc.
* Also excludes microforms and items not yet cataloged via call number and/or title.*/

WHERE (location__t.code IS NOT NULL OR location__t.code !='' OR location__t.code != ' ')
AND (location__t.code NOT ILIKE ALL (ARRAY ['serv,remo', 'bd', 'cise', 'cons,opt', 'cts,rev', 'engr', 'Engr,wpe', 'law,ts', 'lts,ersm', 
 'mann,gate', 'mann,hort', 'mann,href', 'mann,ts', 'olin,ils', 'phys', 'agen', 'bind,circ', 'bioc', 'engr,ref', 'ent', 'fine,lock', 'food', 'hote,permres', 'hote,res', 'jgsm,permres', 'mann,permres', 'nus', 'rmc,ts', 'vet,permres', 'vet,ref', 'void', 'xtest', 'z-test location'])) 
--exclude the following materials as they are not available for discovery or are micro-materials
AND holdings_ext.call_number NOT ILIKE ALL(ARRAY['%n order%', '%n process%', '%vailable for the library to purchase%', 
'%n selector%', '%film%','%fiche%', '%micro%', '%vault%'])
AND (holdings_ext.discovery_suppress = 'false' OR holdings_ext.discovery_suppress IS NULL)  
AND instance_ext.title NOT ILIKE '%[micro%]%'
AND (instance_ext.discovery_suppress = 'false' OR instance_ext.discovery_suppress IS NULL)  
AND (micros.micro_by_007 !='h' OR micros.micro_by_007 IS NULL OR micros.micro_by_007 = '' OR micros.micro_by_007 = ' ') 
AND (unpurch.unpurchased NOT ILIKE '%couttspdbappr%' OR unpurch.unpurchased IS NULL OR unpurch.unpurchased = '' OR unpurch.unpurchased = ' ') 
)

SELECT 
current_date,
COUNT (DISTINCT merge1.instance_id) AS distinct_title_count,
merge1.leader0607,
merge1.leader0607description,
merge1.folio_format_type,
merge1.folio_format_type_adc_groups, 
merge1.folio_format_type_acrl_nces_groups--removed comma


FROM merge1

GROUP BY 

merge1.leader0607,
merge1.leader0607description,
merge1.folio_format_type,
merge1.folio_format_type_adc_groups, 
merge1.folio_format_type_acrl_nces_groups
;
