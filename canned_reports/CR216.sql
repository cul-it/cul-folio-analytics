--CR216
--Microform Counts
--Query writer: Vandana Shah (vp25)
--Query reviewers: Joanne Leary (jl41), Linda Miller (lm15)
--Date posted: 6/26/23
--This query provides counts of microforms, by format type. 

WITH marc_formats AS
	(SELECT 
 		DISTINCT sm.instance_id,
       	substring(sm."content", 7, 2) AS "leader0607"
     	FROM srs_marctab AS sm  
    	WHERE  sm.field = '000'),
    	
candidates AS 
(SELECT DISTINCT sm.instance_id

                FROM srs_marctab AS sm
                LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id::uuid
                LEFT JOIN folio_reporting.instance_ext AS ie ON ie.instance_id::uuid=sm.instance_id
                WHERE 
                	(sm.field = '007'  AND substring (sm."content",1,1) = 'h'
                OR (he.call_number similar to '%(Film|Fiche|Micro|film|fiche|micro)%')
       			OR (ie.title ilike '%[microform%]'))
                AND (he.discovery_suppress IS NOT TRUE OR he.discovery_suppress IS NULL OR he.discovery_suppress ='FALSE')
                AND (ie.discovery_suppress IS NOT TRUE OR ie.discovery_suppress IS NULL OR ie.discovery_suppress ='FALSE')
                
 /*Excludes serv,remo which are all e-materials and are counted in a separate query. Also excludes materials 
* from the following locations as they: no longer exist; are not yet received/cataloged; are not owned by the Library; etc.*/


AND (he.permanent_location_name NOT ILIKE ALL(ARRAY['serv,remo', '%LTS%','Agricultural Engineering','Bindery Circulation',
'Biochem Reading Room', 'Borrow Direct', 'CISER', 'cons,opt', 'Engineering', 'Engineering Reference', 'Engr,wpe',
'Entomology', 'Food Science', 'Law Technical Services', 'LTS Review Shelves', 'LTS E-Resources & Serials','Mann Gateway',
'Mann Hortorium', 'Mann Hortorium Reference', 'Mann Technical Services', 'Iron Mountain', 'Interlibrary Loan%', 'Phys Sci',
'RMC Technical Services', 'No Library','x-test', 'z-test location' ]) 
AND he.permanent_location_name IS NOT NULL)

--exclude the following materials as they are not available for discovery
AND trim(concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)) NOT ILIKE ALL(ARRAY['on order%', 'in process%', 'Available for the library to purchase', 
 'On selector%', 'vault'])
)

        
  SELECT COUNT (DISTINCT cc.instance_id),
  	mfg.leader0607description,
 	mfg.folio_format_type,
	mfg.folio_format_type_adc_groups, 
	mfg.folio_format_type_acrl_nces_groups
  
  FROM candidates AS cc
  INNER JOIN marc_formats AS mf ON cc.instance_id=mf.instance_id
  INNER JOIN local_core.vs_folio_physical_material_formats AS mfg ON mf.leader0607=mfg.leader0607
       
   GROUP BY  
  	mfg.leader0607description,
   	mfg.folio_format_type,
	mfg.folio_format_type_adc_groups, 
	mfg.folio_format_type_acrl_nces_groups
  ;
