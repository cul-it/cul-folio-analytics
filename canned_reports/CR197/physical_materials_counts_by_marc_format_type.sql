--CR197
--physical_materials_counts_by_marc_format_type

WITH formats
     AS (SELECT sm.instance_id,
                Substring (sm.content, 7, 2) AS form_of_material,
                
                CASE
                  WHEN Substring (sm.content, 7, 1) = 'a' THEN 'Language material'
                  WHEN Substring (sm.content, 7, 1) = 'c' THEN 'Notated music'
                  WHEN Substring (sm.content, 7, 1) = 'd' THEN 'Manuscript notated music'
                  WHEN Substring (sm.content, 7, 1) = 'e' THEN 'Cartographic material'
                  WHEN Substring (sm.content, 7, 1) = 'f' THEN 'Manuscript cartographic material'
                  WHEN Substring (sm.content, 7, 1) = 'g' THEN 'Projected medium'
                  WHEN Substring (sm.content, 7, 1) = 'i' THEN 'Nonmusical sound recording'
                  WHEN Substring (sm.content, 7, 1) = 'j' THEN 'Musical sound recording'
                  WHEN Substring (sm.content, 7, 1) = 'k' THEN 'Two-dimensional nonprojectable graphic'
                  WHEN Substring (sm.content, 7, 1) = 'm' THEN 'Computer file'
                  WHEN Substring (sm.content, 7, 1) = 'o' THEN 'Kit'
                  WHEN Substring (sm.content, 7, 1) = 'p' THEN 'Mixed materials'
                  WHEN Substring (sm.content, 7, 1) = 'r' THEN 'Three-dimensional artifact or naturally occurring object'
                  WHEN Substring (sm.content, 7, 1) = 't' THEN 'Manuscript language material'
                  ELSE 'Not coded'
                END AS type_of_record,
                
                CASE
                  WHEN Substring (sm.content, 8, 1) = 'a' THEN 'Monographic component part'
                  WHEN Substring (sm.content, 8, 1) = 'b' THEN 'Serial component part'
                  WHEN Substring (sm.content, 8, 1) = 'c' THEN 'Collection'
                  WHEN Substring (sm.content, 8, 1) = 'd' THEN 'Subunit'
                  WHEN Substring (sm.content, 8, 1) = 'i' THEN 'Integrating resource'
                  WHEN Substring (sm.content, 8, 1) = 'm' THEN 'Monograph/Item'
                  WHEN Substring (sm.content, 8, 1) = 's' THEN 'Serial'
                  ELSE 'Not coded'
                END AS bibliographic_level,
                
                bfalttc.bib_format_display AS voyager_grouping
                
         FROM   srs_marctab AS sm
                left join local_statistics.bib_fmt_and_location_trans_tables_csv
                          bfalttc
                       ON Substring (sm.content, 7, 2) = bfalttc.bib_format
         WHERE  sm.field = '000'
                AND Substring (sm.content, 7, 1) > '%'
                AND Substring (sm.content, 8, 1) > '%'),
     holdings
     AS (SELECT instance_id,
                holdings_id
         FROM   folio_reporting.holdings_ext),
     items
     AS (SELECT item_id,
                holdings_record_id AS holdings_id
         FROM   folio_reporting.item_ext)
SELECT ft.form_of_material,
       ft.type_of_record,
       ft.bibliographic_level,
       ft.voyager_grouping,
       Count(DISTINCT ft.instance_id) AS instance_id_count,
       Count(DISTINCT hh.holdings_id) AS holdings_id_count,
       Count(DISTINCT ii.item_id)     AS item_id_count
FROM   formats AS ft

       LEFT JOIN holdings AS hh
              ON ft.instance_id = hh.instance_id :: uuid
       LEFT JOIN items AS ii
              ON hh.holdings_id = ii.holdings_id
GROUP  BY ft.form_of_material,
          ft.type_of_record,
          ft.bibliographic_level,
          ft.voyager_grouping; 
