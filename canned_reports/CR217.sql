--CR217
--Ematerials Counts
--Query writer: Vandana Shah (vp25)
--Query reviewers: Joanne Leary (jl41), Linda Miller (lm15)
--Date posted: 6/26/23
/*This query provides counts of ematerials by format type. Formats are taken from 948 field, and if missing then taken from the stat code, and if both these fields are missing, formats are taken from the MARC format code. */

WITH
marc_formats AS
       (SELECT 
       sm.instance_hrid,
       substring(sm."content", 7, 2) AS leader0607
       FROM srs_marctab AS sm  
           
       WHERE  sm.field = '000'
),

field_format AS
       (SELECT 
       sm.instance_hrid,
       sm."content" AS ematerial_type_by_948
       FROM srs_marctab AS sm  
       
       WHERE sm.field = '948' 
       AND sm.sf = 'f' 
       AND sm.content IN ('fd','webfeatdb','imagedb','ebk','j','evideo','eaudio','escore','ewb','emap','emisc')
),
       
statcode_format AS 
       (SELECT
       isc.instance_hrid,
       string_agg(DISTINCT isc.statistical_code, ', ') AS ematerial_type_by_stat_code
       
       FROM folio_reporting.instance_statistical_codes AS isc 
       
       WHERE isc.statistical_code IN ('fd','webfeatdb','imagedb','ebk','j','evideo','eaudio','escore','ewb','emap','emisc')
       
       GROUP BY isc.instance_hrid   
),

unpurch AS
                                (SELECT DISTINCT 
                                sm.instance_hrid,
                                sm."content"  AS "unpurchased"
                                      
                                FROM srs_marctab AS sm  
                                
                                WHERE sm.field = '899'
                                    AND sm.sf LIKE 'a'
                                    AND sm.CONTENT ILIKE ANY (ARRAY['DDA_pqecebks', 'PDA_casaliniebkmu']) 
),

format_merge AS
                (SELECT 
                mf.instance_hrid,
                mf.leader0607,
                up.unpurchased,
                fmg.leader0607description,
                ff.ematerial_type_by_948,
                sf.ematerial_type_by_stat_code,
                COALESCE (ff.ematerial_type_by_948, sf.ematerial_type_by_stat_code, fmg.leader0607description, 'No') AS ematerial

FROM marc_formats AS mf
                LEFT JOIN field_format AS ff ON mf.instance_hrid = ff.instance_hrid
                LEFT JOIN statcode_format AS sf ON mf.instance_hrid = sf.instance_hrid
                LEFT JOIN local_core.vs_folio_physical_material_formats AS fmg ON mf.leader0607 = fmg.leader0607
                LEFT JOIN unpurch AS up ON up.instance_hrid = mf.instance_hrid
),
                
format_final AS  
(SELECT DISTINCT
                format_merge.instance_hrid,
                ii.title,
                format_merge.leader0607,
                format_merge.unpurchased,
                format_merge.leader0607description,
                format_merge.ematerial_type_by_948,
                format_merge.ematerial_type_by_stat_code,
                format_merge.ematerial,
                CASE          
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['ebk', 'comput%','%language%'])   THEN 'e-book'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['fd','webfeatdb', 'ewb']) THEN 'e-database'
                    WHEN format_merge.ematerial ='imagedb' THEN 'e-image'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['j', '%serial%']) THEN 'e-journal'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['evideo', '%project%', 'kit%', 'two%'])  THEN 'e-video'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['eaudio', '%sound%']) THEN 'e-audio'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['escore',' %notated%']) THEN 'e-score'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['emap', '%carto%']) THEN 'e-map'
                    WHEN format_merge.ematerial ILIKE ANY (ARRAY['emisc', 'mixed%']) THEN 'e-misc' 
                    
                    ELSE  'unknown' END AS ematerial_format
                
                FROM format_merge
                                LEFT JOIN inventory_instances AS ii 
                                ON ii.hrid = format_merge.instance_hrid 
                                
                                LEFT JOIN folio_reporting.holdings_ext AS he 
                                ON ii.id = he.instance_id 
                
                WHERE (ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL OR ii.discovery_suppress IS NOT TRUE) 
                AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL OR he.discovery_suppress IS NOT TRUE) 
                AND he.permanent_location_name = 'serv,remo'
)

SELECT
format_final.leader0607description,
format_final.ematerial_type_by_948,
format_final.ematerial_type_by_stat_code,
format_final.unpurchased,
format_final.ematerial,
format_final.ematerial_format,
count (DISTINCT format_final.instance_hrid)

FROM format_final
GROUP BY
                format_final.leader0607description,
                format_final.ematerial_type_by_948,
                format_final.ematerial_type_by_stat_code,
                format_final.unpurchased,
                format_final.ematerial,
                format_final.ematerial_format
;
