/* This query finds all holdings in a specific location, 
and shows other locations that have holdings for the same titles.
First, the subquery finds the Instance IDs for all titles in the main location.
These instance ids are then used in the main query to find other locations' holdings.
The list is in order by call number, then by instance_id (so same titles group together).
The item record count for each holdings record is also included, which allows the user to order by number of volumes in descending order if they want.*/

WITH parameters AS (
SELECT 
'% %'::varchar AS location_filter --enter the location name BETWEEN the two % signs, for example: %Law%
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
    string_agg(DISTINCT nt."note", ' | ') AS notes_list
    FROM folio_reporting.holdings_notes as nt
    GROUP BY holdings_id, instance_id
),
    
statements AS 
 (SELECT
        holdings_id as holdings_id,
        string_agg(DISTINCT hs."statement", ' | ') AS holdings_list
  FROM folio_reporting.holdings_statements AS hs 
  GROUP BY holdings_id
),
        
numvols AS 
 (SELECT
       holdings_id as holdings_id,
       count(ihi.item_id) AS number_of_volumes
    FROM folio_reporting.items_holdings_instances AS ihi
    GROUP BY holdings_id
)

SELECT 
       inst.main_location_call_no,
       he.permanent_location_name,
       ie.title,
       he.call_number AS other_location_call_number,
       ied.edition,
       ip.date_of_publication,
       ie.instance_hrid,
       he.holdings_hrid,
       ie.discovery_suppress AS suppress_instance,
       he.discovery_suppress AS suppress_holdings,
       he.type_name AS holdings_type_name,
       nts.notes_list,
       statements.holdings_list,
       numvols.number_of_volumes
                   
FROM 
       inst           
       INNER JOIN folio_reporting.instance_ext AS ie ON inst.main_location_instance_id = ie.instance_id
       INNER JOIN folio_reporting.holdings_ext AS he ON ie.instance_id = he.instance_id
       LEFT JOIN folio_reporting.instance_editions AS ied ON he.instance_id = ied.instance_id
       LEFT JOIN folio_reporting.instance_publication AS ip ON he.instance_id = ip.instance_id
       LEFT JOIN nts ON he.holdings_id = nts.holdings_id
       LEFT JOIN statements ON he.holdings_id = statements.holdings_id
       LEFT JOIN numvols ON he.holdings_id = numvols.holdings_id 
       
order BY 
              inst.main_location_call_no, ie.instance_hrid, he.holdings_hrid, ie.title, he.permanent_location_name, he.call_number;
