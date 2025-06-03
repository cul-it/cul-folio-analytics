--MCR185
--Ceased_cancelled_serials_at_holdings_level
--This query finds ceased or cancelled titles at the holdings level for a specified owning library and LC class, and shows if there are holdings at the Annex. Results will include any title (of any holdings type) that has a holdings receipt status or holdings note that indicates the title is no longer received or is ceased or cancelled. Both library name and LC class are required parameters.
--Original LDP query writer: Joanne Leary (jl41)
--This query ported to Metadb by: Linda Miller (lm15)
--Query reviewers: Joanne Leary (jl41), Vandana Shah (vp25)
--Date posted: 6/10/24

WITH parameters AS 
(SELECT
        'Uris Library'::varchar AS library_filter, -- examples: 'Uris Library', 'Mathematics Library', 'Library Annex'
        'T%'::varchar AS lc_class_filter -- examples: 'T%', 'QA', 'NAC', 'NA%'
),


-- 1. Get candidates

data1 AS 
(SELECT 
        locations_libraries.library_name,
        holdings_ext.permanent_location_name,
        instance_ext.title,
        holdings_ext.type_name as holdings_type_name,
        instance_ext.instance_id,
        instance_ext.instance_hrid,
        instance_ext.discovery_suppress AS instance_suppress,
        count (distinct item__t.id) as number_of_volumes,
        holdings_ext.id,
        holdings_ext.holdings_hrid,
        holdings_ext.call_number,
        TRIM (CONCAT_WS (' ', holdings_ext.call_number_prefix, holdings_ext.call_number, holdings_ext.call_number_suffix, 
                CASE WHEN holdings_ext.copy_number >'1' THEN concat ('c.', holdings_ext.copy_number) ELSE '' END)) AS whole_call_number,
        SUBSTRING (holdings_ext.call_number,'^([a-zA-z]{1,3})') as lc_class,      
                REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (holdings_ext.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.') AS lc_class_number,
                TRIM (LEADING '.' FROM SUBSTRING (holdings_ext.call_number, '\.[A-Z][0-9]{1,}')) AS first_cutter, 
        holdings_ext.receipt_status,
        holdings_ext.discovery_suppress AS holdings_suppress,
        STRING_AGG (DISTINCT holdings_statements.holdings_statement,' | ') AS library_holdings_statements,
        STRING_AGG (DISTINCT holdings_notes.note,' | ') AS library_holdings_note
       
FROM folio_derived.instance_ext
        LEFT JOIN folio_derived.holdings_ext
        ON instance_ext.instance_id = holdings_ext.instance_id
        
        LEFT JOIN folio_derived.holdings_statements
        ON holdings_ext.holdings_hrid = holdings_statements.holdings_hrid
        
        LEFT JOIN folio_derived.holdings_notes
        ON holdings_ext.id = holdings_notes.holding_id
        
        LEFT JOIN folio_inventory.item__t
        ON item__t.holdings_record_id = holdings_ext.id
        
        LEFT JOIN folio_derived.locations_libraries
        ON holdings_ext.permanent_location_id = locations_libraries.location_id


        
WHERE 
                (locations_libraries.library_name = (SELECT library_filter FROM parameters)
                and (instance_ext.discovery_suppress = 'false' or instance_ext.discovery_suppress is null)
                and (holdings_ext.discovery_suppress = 'false' or holdings_ext.discovery_suppress is null)
                AND SUBSTRING (holdings_ext.call_number,'^([a-zA-z]{1,3})') LIKE (SELECT lc_class_filter FROM parameters)
                AND ((holdings_ext.receipt_status ilike '%not currently rec%' 
                 OR holdings_ext.receipt_status ILIKE '%cease%' 
                 OR holdings_ext.receipt_status ilike '%cancel%'
                OR holdings_ext.receipt_status ilike '%complete%'
                OR holdings_notes.note similar to '%(ceased|cancel)%')))

            
GROUP BY 
        locations_libraries.library_name,
        holdings_ext.permanent_location_name,
        instance_ext.title,
        instance_ext.instance_id,
        instance_ext.instance_hrid,
        instance_ext.discovery_suppress,
        holdings_ext.id,
        holdings_ext.holdings_hrid,
        holdings_ext.call_number_prefix,
        holdings_ext.call_number,
        holdings_ext.call_number_suffix,
        holdings_ext.copy_number,
        holdings_ext.receipt_status,
        holdings_ext.type_name,
        holdings_ext.discovery_suppress
),



-- 2. Find holdings at the Annex

annex AS 
        (SELECT 
                data1.instance_id,
                STRING_AGG (DISTINCT holdings_ext.permanent_location_name,' | ') AS annex_locations,
                STRING_AGG (DISTINCT holdings_statements.holdings_statement, ' | ') AS annex_holdings
                
        FROM data1
                LEFT JOIN folio_derived.holdings_ext 
                ON data1.instance_id = holdings_ext.instance_id 
                
                LEFT JOIN folio_derived.holdings_statements
                ON holdings_ext.id = holdings_statements.holdings_id
                
        WHERE holdings_ext.permanent_location_name LIKE '%Annex%'
        and (holdings_ext.discovery_suppress = 'false' or holdings_ext.discovery_suppress is null)

        
        GROUP BY data1.instance_id
)


-- 3. Match the library's results to the Annex results and put everything in call number order

SELECT 
                data1.library_name,
                data1.permanent_location_name,
                data1.title,
                data1.holdings_type_name,
                data1.instance_id,
                data1.instance_hrid,
                data1.holdings_hrid,
                data1.number_of_volumes,
                data1.call_number,
                data1.whole_call_number,
                data1.lc_class,
                data1.lc_class_number::numeric,
                data1.first_cutter,
                data1.receipt_status,
                data1.holdings_suppress,
                data1.library_holdings_statements,
                data1.library_holdings_note,
                annex.annex_locations,
                annex.annex_holdings
                
        FROM data1 
             LEFT JOIN annex 
             ON data1.instance_id = annex.instance_id
              
             WHERE  data1.whole_call_number NOT ILIKE '%thesis%'
                                
              ORDER BY lc_class, lc_class_number::numeric, first_cutter
;



