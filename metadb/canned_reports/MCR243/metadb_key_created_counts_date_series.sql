--Count holdings, instances, items, and srs_records with state 'ACTUAL' in Metadb. 
--Display each set of counts by individual date for a given range of dates.
--Enter start and end dates for date range in YYYY-DD-MM format in date fields. 

WITH date_series AS (
    SELECT generate_series('2024-08-15'::date, '2024-08-27'::date - interval '1 day', '1 day') AS date
)
SELECT 
    ds.date::date, 
    
    COALESCE(ih.inventory_holdings_count, 0) AS inventory_holdings_count,
    COALESCE(ii.inventory_instances_count, 0) AS inventory_instances_count,
    COALESCE(it.inventory_items_count, 0) AS inventory_items_count,
    COALESCE(srsr.srs_records_instances_count, 0) AS srs_records_instances_count

FROM date_series ds

LEFT JOIN (
    SELECT 
        creation_date::date AS created_date, 
        count(*) AS inventory_holdings_count
    FROM folio_inventory.holdings_record__  
    WHERE creation_date::date >= '2024-08-15' 
      AND creation_date::date < '2024-08-27'
      AND __current = TRUE
    GROUP BY creation_date::date
) ih
ON ds.date = ih.created_date


LEFT JOIN (
    SELECT 
        creation_date::date AS created_date, 
        count(*) AS inventory_instances_count
    FROM folio_inventory.instance__  
        WHERE creation_date::date >= '2024-08-15' 
      AND creation_date::date < '2024-08-27'
      AND __current = TRUE  
    GROUP BY creation_date::date
) ii
ON ds.date = ii.created_date

LEFT JOIN (
    SELECT 
        creation_date::date AS created_date, 
        count(*) AS inventory_items_count
    FROM folio_inventory.item__  
       WHERE creation_date::date >= '2024-08-15' 
      AND creation_date::date < '2024-08-27'
      AND __current = TRUE
    GROUP BY creation_date::date
) it
ON ds.date = it.created_date

LEFT JOIN (
    SELECT 
        sr.created_date::date AS created_date, 
        COUNT(*) AS srs_records_instances_count
    FROM folio_source_record.records_lb as sr 
    WHERE sr.state = 'ACTUAL'
      AND created_date::date >= '2024-08-15' 
      AND created_date::date < '2024-08-27'
      AND __current = TRUE     
    GROUP BY sr.created_date::date
) srsr
ON ds.date = srsr.created_date

ORDER BY ds.date;
