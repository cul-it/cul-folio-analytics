WITH parameters AS 
(SELECT
        'Mann Library'::varchar AS library_filter, -- examples: 'Uris Library', 'Mathematics Library', 'Library Annex'
        'TX%'::varchar AS lc_class_filter -- examples: 'T%', 'QA', 'NAC', 'NA%'
),

-- 1. Get candidates

data1 AS 
(SELECT 
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        he.type_name as holdings_type_name,
        instext.instance_id,
        instext.instance_hrid,
        invitems.hrid as item_hrid,
        invitems.id as item_id,
        he.holdings_id,
        he.holdings_hrid,
        he.call_number,
        TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, 
                CASE WHEN he.copy_number >'1' THEN concat ('c.', he.copy_number) ELSE '' END)) AS whole_call_number,
        SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') as lc_class,
        he.receipt_status,
        he.discovery_suppress AS holdings_suppress,
        STRING_AGG (DISTINCT hs.statement,' | ') AS library_holdings_statements,
        STRING_AGG (DISTINCT hn.note,' | ') AS library_holdings_note,
        invitems.effective_shelving_order
        

FROM folio_reporting.instance_ext AS instext 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON instext.instance_id = he.instance_id 
        
        LEFT JOIN folio_reporting.holdings_statements AS hs 
        ON he.holdings_hrid = hs.holdings_hrid
        
        LEFT JOIN folio_reporting.holdings_notes AS hn 
        ON he.holdings_id = hn.holdings_id
        
        LEFT JOIN inventory_items AS invitems 
        ON invitems.holdings_record_id = he.holdings_id
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id

WHERE 
                (ll.library_name = (SELECT library_filter FROM parameters)
                AND SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') LIKE (SELECT lc_class_filter FROM parameters)
                AND he.type_name IN ('Serial','Multi-part monograph')
                AND (he.receipt_status ='Not currently received' OR he.receipt_status ILIKE '%Ceased%' OR hn.note similar to '%(cease|cancel)%'))
                

GROUP BY 
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        instext.instance_id,
        instext.instance_hrid,
        invitems.hrid,
        invitems.id,
        he.holdings_id,
        he.holdings_hrid,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        he.copy_number,
        he.receipt_status,
        he.type_name,
        he.discovery_suppress
),

-- 2. Count the number of volumes for library holdings

numvols AS 
        (SELECT 
                data1.holdings_hrid,
                COUNT (data1.item_id) AS number_of_volumes
        
        FROM data1
        GROUP BY data1.holdings_hrid
),

-- 3. Find holdings at the Annex

annex AS 
        (SELECT 
                data1.instance_id,
                STRING_AGG (DISTINCT he.permanent_location_name,' | ') AS annex_locations,
                STRING_AGG (DISTINCT hs.statement, ' | ') AS annex_holdings
                
        FROM data1
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON data1.instance_id = he.instance_id 
                
                LEFT JOIN folio_reporting.holdings_statements AS hs 
                ON he.holdings_id = hs.holdings_id
                
        WHERE he.permanent_location_name LIKE '%Annex%'
        
        GROUP BY data1.instance_id
)

-- 4. Match the library's results to the Annex results and put everything in call number order

SELECT 
                data1.library_name,
                data1.permanent_location_name,
                data1.title,
                data1.holdings_type_name,
                data1.instance_id,
                data1.instance_hrid,
                data1.holdings_hrid,
                numvols.number_of_volumes,
                data1.call_number,
                data1.whole_call_number,
                data1.lc_class,
                data1.receipt_status,
                data1.holdings_suppress,
                data1.library_holdings_statements,
                data1.library_holdings_note,
                annex.annex_locations,
                annex.annex_holdings,
                data1.effective_shelving_order
        
        FROM data1 
                LEFT JOIN annex 
                ON data1.instance_id = annex.instance_id
                
                LEFT JOIN numvols 
                ON data1.holdings_hrid = numvols.holdings_hrid
                        
        WHERE (data1.holdings_suppress = 'FALSE' OR data1.holdings_suppress IS NULL)
                AND data1.whole_call_number NOT ILIKE '%thesis%'
                
        ORDER BY data1.effective_shelving_order COLLATE "C"
;


     
