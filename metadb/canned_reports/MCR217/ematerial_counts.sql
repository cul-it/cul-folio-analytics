--MCR217
--Ematerial Title (Instance Counts)
--LDP Query writer: Vandana Shah (vp25)
--Query ported to Metadb by: Linda Miller (lm15)
--Ported query reviewed by: Joanne Leary (jl41), Vandana Shah (vp25)
--Date posted: 6/4/24

--This query provides counts of ematerials by format type. Formats are taken from 948 field, and if missing then taken from the stat code, and if both these fields are missing, formats are taken from the MARC format code. Titles with multiple codes are assigned based on the priority listed in the CASE clause.
--This query is primarily used to get counts for annual CUL reporting.

WITH
marc_formats AS
       (SELECT 
       marc__t.instance_hrid,
       substring(marc__t."content", 7, 2) AS leader0607
       FROM folio_source_record.marc__t  --FROM srs_marctab AS sm 
      
       WHERE marc__t.field = '000'
       
),

field_format AS
       (SELECT 
       marc__t.instance_hrid,
       string_agg(DISTINCT marc__t."content", ', ') AS ematerial_type_by_948 
       FROM folio_source_record.marc__t   
       
       WHERE marc__t.field = '948' 
       AND marc__t.sf = 'f' 
       AND marc__t.content ILIKE ANY (ARRAY['%fd%','%webfeatdb%','%imagedb%','%ebk%','%j%','%evideo%',
       '%eaudio%','%escore%','%ewb%','%emap%','%emisc%'])
       GROUP BY marc__t.instance_hrid 
),

statcode_format AS 
       (SELECT
       instance_statistical_codes.instance_hrid,
       string_agg(DISTINCT instance_statistical_codes.statistical_code, ', ') AS ematerial_type_by_stat_code
       
       FROM folio_derived.instance_statistical_codes 
       
      WHERE instance_statistical_codes.statistical_code ILIKE ANY (ARRAY['%fd%','%webfeatdb%','%imagedb%','%ebk%','%j%','%evideo%',
       '%eaudio%','%escore%','%ewb%','%emap%','%emisc%']) --added truncation
       AND instance_statistical_codes.statistical_code_type_name ilike 'Special format' 
              
       GROUP BY instance_statistical_codes.instance_hrid
),


unpurch AS
   	 (SELECT DISTINCT 
      marc__t.instance_hrid,
      string_agg(DISTINCT marc__t."content", ', ') AS "unpurchased"
                                      
            FROM folio_source_record.marc__t   
                              
              WHERE marc__t.field = '899'
              AND marc__t.sf LIKE 'a'
              
              GROUP BY marc__t.instance_hrid 
          ),
                                    
format_merge AS
                (SELECT 
                marc_formats.instance_hrid,
                marc_formats.leader0607,
                unpurch.unpurchased,
                vs_folio_physical_material_formats.leader0607description,
                field_format.ematerial_type_by_948,
                statcode_format.ematerial_type_by_stat_code,
                COALESCE (field_format.ematerial_type_by_948, statcode_format.ematerial_type_by_stat_code, vs_folio_physical_material_formats.leader0607description, 'No') AS ematerial

FROM marc_formats
                LEFT JOIN field_format ON marc_formats.instance_hrid = field_format.instance_hrid
                LEFT JOIN statcode_format ON marc_formats.instance_hrid = statcode_format.instance_hrid
                LEFT JOIN local_static.vs_folio_physical_material_formats ON marc_formats.leader0607 = vs_folio_physical_material_formats.leader0607  --LEFT JOIN local_core.vs_folio_physical_material_formats AS fmg ON mf.leader0607 = fmg.leader0607
                LEFT JOIN unpurch ON unpurch.instance_hrid = marc_formats.instance_hrid
                    
),
                
format_final AS  
(SELECT DISTINCT
                format_merge.instance_hrid,
                instance__t.title,
                format_merge.leader0607,
                format_merge.leader0607description,
                format_merge.ematerial_type_by_948,
                format_merge.ematerial_type_by_stat_code,
                format_merge.ematerial,
                CASE                             
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['imagedb','%fd%','%webfeat%','%imagedb%']) THEN 'e-database' 
                    WHEN (format_merge.ematerial ILIKE ANY (ARRAY['%j%','%serial%']) and format_merge.ematerial not ilike '%project%') THEN 'e-journal'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['%ebk%','comput%','%language%'])   THEN 'e-book' 
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['%evideo%','%project%', 'kit%','two%'])  THEN 'e-video'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['%eaudio%','%sound%']) THEN 'e-audio'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['%escore%',' %notated%']) THEN 'e-score'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['%emap%','%carto%']) THEN 'e-map'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['%ewb%']) THEN 'website' 
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['%emisc%','mixed%']) THEN 'e-misc' 
                    ELSE  'unknown' END AS ematerial_format
                
                FROM format_merge
                                LEFT JOIN folio_inventory.instance__t  
                                ON instance__t.hrid = format_merge.instance_hrid 
                                
                                LEFT JOIN folio_derived.holdings_ext 
                                ON instance__t.id = holdings_ext.instance_id  
                                LEFT JOIN folio_inventory.location__t ON holdings_ext.permanent_location_id = location__t.id 
                
                WHERE (instance__t.discovery_suppress = 'false' OR instance__t.discovery_suppress IS NULL)  
                AND (holdings_ext.discovery_suppress = 'false' OR holdings_ext.discovery_suppress IS NULL) 
                AND location__t.code = 'serv,remo'  
                AND (format_merge.unpurchased NOT ILIKE ALL (ARRAY['%DDA_pqecebks%', '%PDA_casaliniebkmu%']) 
                OR format_merge.unpurchased IS NULL OR format_merge.unpurchased = '' OR format_merge.unpurchased = ' ') 
                              
               
)

SELECT
current_date AS today_date,
format_final.leader0607description,
format_final.ematerial_type_by_948,
format_final.ematerial_type_by_stat_code,
format_final.ematerial,
format_final.ematerial_format,
count (DISTINCT format_final.instance_hrid)

FROM format_final
GROUP BY
                format_final.leader0607description,
                format_final.ematerial_type_by_948,
                format_final.ematerial_type_by_stat_code,
                format_final.ematerial,
                format_final.ematerial_format
;

