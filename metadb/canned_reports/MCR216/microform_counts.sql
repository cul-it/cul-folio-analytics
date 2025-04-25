--MCR216
--Unique Microform Title (Instance Counts)
--LDP Query writer: Vandana Shah (vp25)
--Query ported to Metadb by: Linda Miller (lm15)
--Ported query reviewed by: Joanne Leary (jl41), Vandana Shah (vp25)
--Date posted: 6/4/24

--This query provides counts of microform titles, by format type. Note that, because of how we filter for microforms, it also includes any motion picture films with '%film%' in their call numbers. 

--This query is primarily used to get counts for annual CUL reporting.

WITH marc_formats AS
       (SELECT DISTINCT 
       marc__t.instance_id,
       substring(marc__t."content", 7, 2) AS "leader0607"
       FROM folio_source_record.marc__t  
       WHERE  marc__t.field = '000'),
       
--Flagging microforms via 007 field 
micros AS
       (SELECT DISTINCT 
             marc__t.instance_id,
             substring (marc__t."content",1,1) AS micro_by_007
          FROM folio_source_record.marc__t
          WHERE  marc__t.field = '007'  
                ),
       
candidates AS 
(SELECT DISTINCT 
                instance_ext.instance_id 

                FROM folio_derived.instance_ext
                LEFT JOIN micros ON instance_ext.instance_id = micros.instance_id 
                          LEFT JOIN folio_derived.holdings_ext ON instance_ext.instance_id = holdings_ext.instance_id  
                LEFT JOIN folio_inventory.location__t ON holdings_ext.permanent_location_id = location__t.id 
               
                WHERE 
                ( (micros.micro_by_007 = 'h')  OR (holdings_ext.call_number similar to '%(Film|Fiche|Micro|Vault|film|fiche|micro|vault)%') --added Vault/vault
                          OR (instance_ext.title ilike '%[micro%]%')) 
                AND (holdings_ext.discovery_suppress = 'false' OR holdings_ext.discovery_suppress IS NULL)  
                AND (instance_ext.discovery_suppress = 'false' OR instance_ext.discovery_suppress IS NULL)  
                AND (location__t.code IS NOT NULL OR location__t.code != '' OR location__t.code != ' ') 
/*Excludes serv,remo and Mann Gateway which are all e-materials and are counted in a separate query. Also excludes materials 
* from the following locations as they no longer exist; are not yet received/cataloged; are not owned by the Library; etc.*/
AND (location__t.code NOT ILIKE ALL (ARRAY ['serv,remo', 'bd', 'cise', 'cons,opt', 'cts,rev', 'engr', 'Engr,wpe', 'law,ts', 'lts,ersm', 
             'mann,gate', 'mann,hort', 'mann,href', 'mann,ts', 'olin,ils', 'phys', 'agen', 'bind,circ', 'bioc', 'engr,ref', 'ent', 'fine,lock', 
             'food', 'hote,permres', 'hote,res', 'jgsm,permres', 'mann,permres', 'nus', 'rmc,ts', 'vet,permres', 'vet,ref', 'void', 'xtest', 'z-test location'])) 

--exclude the following materials as they are not available for discovery
AND trim(concat (holdings_ext.call_number_prefix,' ',holdings_ext.call_number,' ',holdings_ext.call_number_suffix)) NOT ILIKE ALL(ARRAY['%n order%', '%n process%', '%vailable for the library to purchase%', 
'%n selector%']) 

)

SELECT 
       COUNT (DISTINCT candidates.instance_id),
       current_date AS todays_date,
       vs_folio_physical_material_formats.leader0607description,
      vs_folio_physical_material_formats.folio_format_type,
       vs_folio_physical_material_formats.folio_format_type_adc_groups, 
       vs_folio_physical_material_formats.folio_format_type_acrl_nces_groups
  
  FROM candidates
  INNER JOIN marc_formats ON candidates.instance_id=marc_formats.instance_id
  INNER JOIN local_static.vs_folio_physical_material_formats ON marc_formats.leader0607=vs_folio_physical_material_formats.leader0607 
       
   GROUP BY  
       vs_folio_physical_material_formats.leader0607description,
       vs_folio_physical_material_formats.folio_format_type,
       vs_folio_physical_material_formats.folio_format_type_adc_groups, 
       vs_folio_physical_material_formats.folio_format_type_acrl_nces_groups
  ;
