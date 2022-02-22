WITH parameters AS (

SELECT 
        --select a start date and an end date for when the titles were acquired
        '2015-07-01'::DATE AS start_date,
        '2021-12-31'::DATE AS end_date,
        --enter the location code IN BETWEEN the two % signs, this will bring in all variations of 'ech'
         '%ech%'::varchar AS location_code_filter 
),
  
bibs AS (
SELECT 
        bt.bib_id::VARCHAR,
        bfd.bib_format_display,
        bibmASter.create_date,
        --mm.mfhd_id::VARCHAR,
        CASE 
                WHEN date_part('month', bibmaster.create_date) < '7'
                THEN date_part('year', bibmaster.create_date) 
                ELSE date_part('year', bibmaster.create_date)+1 
                END AS fiscal_year_acquired,
        loc.location_code,
        loc.location_name
       
FROM vger.bib_master AS bibmaster        
        LEFT JOIN vger.bib_text AS bt
        ON bibmASter.bib_id = bt.bib_id
        
        LEFT JOIN vger.bib_mfhd AS bm 
        ON bt.bib_id = bm.bib_id
        
        LEFT JOIN vger.bib_format_display AS bfd
        ON bt.bib_format = bfd.bib_format
        
        LEFT JOIN vger.mfhd_master AS mm 
        ON bm.mfhd_id = mm.mfhd_id 
        
        LEFT JOIN vger.location AS loc 
        ON mm.location_id = loc.location_id

WHERE  
    (bibmaster.create_date ::DATE >= (SELECT start_date FROM parameters)
    AND bibmaster.create_date ::DATE < (SELECT end_date FROM parameters))
    AND loc.location_code like (SELECT location_code_filter FROM parameters)
        
           
       

ORDER BY fiscal_year_acquired, location_code, location_name
)

SELECT
        bibs.fiscal_year_acquired::VARCHAR,
        bibs.location_name,
       bibs.bib_format_display,
        count(distinct bibs.bib_id)

FROM bibs

GROUP BY bibs.fiscal_year_acquired, bibs.location_name, bibs.bib_format_display
;
