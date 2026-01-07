--MCR217
--Ematerial Title (Instance Counts)
--LDP Query writer: Vandana Shah (vp25)
--Query ported to Metadb by: Linda Miller (lm15)
--Ported query reviewed by: Joanne Leary (jl41), Vandana Shah (vp25)
--Date posted: 6/4/24

--Revised 12/20/25 to include joins to the records.lb table to exclude duplicate instance_ids due to a metadb glitch that is keeping some old as well as new record rows. 
--Adding the records.lb join to the subqueries would not allow the query to run as a whole, but the various sub-queries run without a problem, so this version of the query create tables in the metadb personal space, and the table with the final results can be exported as an Excel file directly from the personal schema. 
--NOTE: To run this query, all the tables that are created need to be created in a personal space on Metadb. For example, in all the 'Create Table' statements, change 'z_vp25' to your personal space name. Each table has to created seperately; the query cannot be run as a whole. Run code for each 'Create Table' one at a time.

--This query provides counts of ematerials by format type. Formats are taken from 948 field, and if missing then taken from the stat code, and if both these fields are missing, formats are taken from the MARC format code. Titles with multiple codes are assigned based on the priority listed in the CASE clause.
--This query is primarily used to get counts for annual CUL reporting.

CREATE TABLE z_vp25.marc_formats AS (
     (SELECT DISTINCT sm.instance_hrid, 
        COALESCE(SUBSTRING(sm.content, 7, 2), '--') AS leader0607
    FROM folio_source_record.marc__t AS sm
    LEFT JOIN folio_source_record.records_lb AS rl ON sm.instance_id=rl.external_id 
    AND sm.srs_id  = rl.id
    
    WHERE rl.state = 'ACTUAL'
    AND sm.field = '000')
        )

CREATE TABLE z_vp25.field_format AS
       (SELECT 
       sm.instance_hrid,
       string_agg(DISTINCT sm."content", ', ') AS ematerial_type_by_948 
       FROM folio_source_record.marc__t AS sm  
       LEFT JOIN folio_source_record.records_lb AS rl ON sm.instance_id=rl.external_id 
    	AND sm.srs_id  = rl.id
       
       WHERE rl.state = 'ACTUAL'
       AND sm.field = '948' 
       AND sm.sf = 'f' 
       AND sm.content ILIKE ANY (ARRAY['%fd%','%webfeatdb%','%imagedb%','%ebk%','%j%','%evideo%',
       '%eaudio%','%escore%','%ewb%','%emap%','%emisc%'])
       GROUP BY sm.instance_hrid 
)

CREATE TABLE z_vp25.statcode_format AS 
       (SELECT
       instance_statistical_codes.instance_hrid,
       string_agg(DISTINCT instance_statistical_codes.statistical_code, ', ') AS ematerial_type_by_stat_code
       
       FROM folio_derived.instance_statistical_codes 
       
      WHERE instance_statistical_codes.statistical_code ILIKE ANY (ARRAY['%fd%','%webfeatdb%','%imagedb%','%ebk%','%j%','%evideo%',
       '%eaudio%','%escore%','%ewb%','%emap%','%emisc%']) --added truncation
       AND instance_statistical_codes.statistical_code_type_name ilike 'Special format' 
              
       GROUP BY instance_statistical_codes.instance_hrid
)


CREATE TABLE z_vp25.unpurch AS
   	 (SELECT DISTINCT 
      sm.instance_hrid,
      string_agg(DISTINCT sm."content", ', ') AS "unpurchased"
                                      
    FROM folio_source_record.marc__t AS sm
    LEFT JOIN folio_source_record.records_lb AS rl ON sm.instance_id=rl.external_id 
    AND sm.srs_id  = rl.id
    
    WHERE rl.state = 'ACTUAL'  
    AND sm.field = '899'
    AND sm.sf LIKE 'a'
              
              GROUP BY sm.instance_hrid 
          )
                                    
CREATE TABLE z_vp25.format_merge AS
                (SELECT 
                z_vp25.marc_formats.instance_hrid,
                z_vp25.marc_formats.leader0607,
                z_vp25.unpurch.unpurchased,
                vs_folio_physical_material_formats.leader0607description,
                z_vp25.field_format.ematerial_type_by_948,
                z_vp25.statcode_format.ematerial_type_by_stat_code,
                COALESCE (z_vp25.field_format.ematerial_type_by_948, z_vp25.statcode_format.ematerial_type_by_stat_code, vs_folio_physical_material_formats.leader0607description, 'No') AS ematerial

FROM z_vp25.marc_formats
                LEFT JOIN z_vp25.field_format ON z_vp25.marc_formats.instance_hrid = z_vp25.field_format.instance_hrid
                LEFT JOIN z_vp25.statcode_format ON z_vp25.marc_formats.instance_hrid = z_vp25.statcode_format.instance_hrid
                LEFT JOIN local_static.vs_folio_physical_material_formats ON z_vp25.marc_formats.leader0607 = vs_folio_physical_material_formats.leader0607  --LEFT JOIN local_core.vs_folio_physical_material_formats AS fmg ON mf.leader0607 = fmg.leader0607
                LEFT JOIN z_vp25.unpurch ON z_vp25.unpurch.instance_hrid = z_vp25.marc_formats.instance_hrid
                    
)
                
CREATE TABLE z_vp25.format_final AS  
(SELECT DISTINCT
                z_vp25.format_merge.instance_hrid,
                instance__t.title,
                z_vp25.format_merge.leader0607,
                z_vp25.format_merge.leader0607description,
                z_vp25.format_merge.ematerial_type_by_948,
                z_vp25.format_merge.ematerial_type_by_stat_code,
                z_vp25.format_merge.ematerial,
                CASE                             
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['imagedb','%fd%','%webfeat%','%imagedb%']) THEN 'e-database' 
                    WHEN (z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%j%','%serial%']) and format_merge.ematerial not ilike '%project%') THEN 'e-journal'
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%ebk%','comput%','%language%'])   THEN 'e-book' 
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%evideo%','%project%', 'kit%','two%'])  THEN 'e-video'
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%eaudio%','%sound%']) THEN 'e-audio'
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%escore%',' %notated%']) THEN 'e-score'
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%emap%','%carto%']) THEN 'e-map'
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%ewb%']) THEN 'website' 
                    WHEN z_vp25.format_merge.ematerial ILIKE ANY (ARRAY['%emisc%','mixed%']) THEN 'e-misc' 
                    ELSE  'unknown' END AS ematerial_format
                
                FROM z_vp25.format_merge
                                LEFT JOIN folio_inventory.instance__t  
                                ON instance__t.hrid = z_vp25.format_merge.instance_hrid 
                                
                                LEFT JOIN folio_derived.holdings_ext 
                                ON instance__t.id = holdings_ext.instance_id  
                                LEFT JOIN folio_inventory.location__t ON holdings_ext.permanent_location_id = location__t.id 
                
                WHERE (instance__t.discovery_suppress = 'false' OR instance__t.discovery_suppress IS NULL)  
                AND (holdings_ext.discovery_suppress = 'false' OR holdings_ext.discovery_suppress IS NULL) 
                AND location__t.code = 'serv,remo'  
                AND (z_vp25.format_merge.unpurchased NOT ILIKE ALL (ARRAY['%DDA_pqecebks%', '%PDA_casaliniebkmu%']) 
                OR z_vp25.format_merge.unpurchased IS NULL OR z_vp25.format_merge.unpurchased = '' OR z_vp25.format_merge.unpurchased = ' ') 
                              
               
)

CREATE TABLE z_vp25.MCR217 AS
(SELECT
current_date AS today_date,
z_vp25.format_final.leader0607description,
z_vp25.format_final.ematerial_type_by_948,
z_vp25.format_final.ematerial_type_by_stat_code,
z_vp25.format_final.ematerial,
z_vp25.format_final.ematerial_format,
count (DISTINCT z_vp25.format_final.instance_hrid)

FROM z_vp25.format_final
GROUP BY
                z_vp25.format_final.leader0607description,
                z_vp25.format_final.ematerial_type_by_948,
                z_vp25.format_final.ematerial_type_by_stat_code,
                z_vp25.format_final.ematerial,
                z_vp25.format_final.ematerial_format)
