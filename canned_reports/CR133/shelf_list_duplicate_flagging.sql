/* This query finds all holdings in a specific location, 
and shows other locations that have holdings for the same titles.

WITH parameters AS (
SELECT 
'%Music Reference%'::varchar AS location_filter --enter the location name IN BETWEEN the two % signs
),

inst AS
(SELECT 
       he.instance_id AS main_location_instance_id,
       he.call_number AS main_location_call_no
       
       FROM folio_reporting.holdings_ext AS he
       
       WHERE he.permanent_location_name LIKE (SELECT location_filter FROM parameters)
       ),
       
 nts AS
(SELECT
    holdings_id AS holdings_id,
    instance_id AS instance_id,
    string_agg(DISTINCT nt."note", ' | ') AS holdings_notes
    FROM folio_reporting.holdings_notes as nt
    GROUP BY holdings_id, instance_id),
    
 statements AS 
 (SELECT
        holdings_id as holdings_id,
        string_agg(DISTINCT hs."statement", ' | ') as holdings_summary
        
        from folio_reporting.holdings_statements as hs 
        
        group by holdings_id),
        
numvols AS 
 (SELECT
       holdings_id as holdings_id,
       count(ihi.item_id) as number_of_volumes
       
        from folio_reporting.items_holdings_instances as ihi
       
        group by holdings_id)

SELECT distinct
       inst.main_location_call_no,
       he.permanent_location_name,
       ie.title,
       he.call_number AS other_location_call_number,
       ie.instance_hrid,
       he.holdings_hrid,
       ie.discovery_suppress AS suppress_instance,
       he.discovery_suppress AS suppress_holdings,
       he.type_name AS holdings_type_name,
     --  hs.statement AS holdings_statement,
       nts.holdings_notes,
       statements.holdings_summary,
       numvols.number_of_volumes
      
              
FROM 
       inst           
       INNER JOIN folio_reporting.instance_ext AS ie ON inst.main_location_instance_id = ie.instance_id
       INNER JOIN folio_reporting.holdings_ext AS he ON ie.instance_id = he.instance_id
       INNER JOIN public.inventory_holdings AS ih ON he.holdings_id = ih.id
       LEFT JOIN folio_reporting.holdings_statements AS hs ON ih.id = hs.holdings_id
       LEFT JOIN nts ON he.holdings_id = nts.holdings_id
       LEFT JOIN statements ON he.holdings_id = statements.holdings_id
       LEFT JOIN numvols ON he.holdings_id = numvols.holdings_id 
       
where inst.main_location_call_no > ''

order BY 
              inst.main_location_call_no, ie.instance_hrid, he.permanent_location_name, he.holdings_hrid, ie.title, he.call_number;

