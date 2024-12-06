-- MCR170 - item status in process 
-- This query finds In Process item status books that appear to be fully cataloged and should be checked in the stacks to see if they have arrived at the library without the status being updated (record cleanup). 
-- Excludes any items with "In process", "On order", "Cancelled" or "OC" in the call number and excludes those records without a barcode, and e-resource records
-- Changed the query to get the 300 field separately; extracted item status from 'folio_inventory.item' table to get the most current status

--Query writer: Joanne Leary (jl41)
--Date posted: 12/6/24

WITH parameters AS (
    SELECT 
         -- Fill out -owning library filter ----
         '%%'::varchar AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc.
        ),
        
field300 AS 
(SELECT 
	sm.instance_hrid,
	STRING_AGG (DISTINCT sm.content,' | ') AS pagination_size
	
	FROM folio_source_record.marc__t AS sm 
	
	WHERE sm.field = '300'
	AND sm.content NOT ILIKE '%online resource%'
	
	GROUP BY sm.instance_hrid
)

SELECT
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
        	itemext.chronology, CASE WHEN itemext.copy_number > '1' THEN CONCAT (' c.',itemext.copy_number) ELSE '' END)) AS whole_call_number,        
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        itemext.barcode,
        itemext.created_date::date AS item_create_date,
        itemext.material_type_name,
        itemnotes.note,
        jsonb_extract_path_text (ii.jsonb,'status','name') AS item_status_name,
        jsonb_extract_path_text (ii.jsonb,'status','date')::date AS item_status_date,
        field300.pagination_size,
        CONCAT ('https://newcatalog.library.cornell.edu/catalog/', instext.instance_hrid) AS catalog_link,
        item__t.effective_shelving_order COLLATE "C"
                
FROM folio_derived.instance_ext AS instext
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON instext.instance_id = he.instance_id
        
        LEFT JOIN folio_derived.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id
        
        LEFT JOIN folio_derived.item_ext AS itemext 
        ON he.holdings_id = itemext.holdings_record_id
        
        LEFT JOIN folio_inventory.item AS ii 
        ON itemext.item_id::UUID = ii.id
        
        LEFT JOIN folio_inventory.item__t 
        ON ii.id = item__t.id
        
        LEFT JOIN folio_derived.item_notes AS itemnotes
        ON itemext.item_id = itemnotes.item_id
        
        LEFT JOIN field300
        ON instext.instance_hrid = field300.instance_hrid
        
WHERE  (ll.library_name ILIKE (SELECT owning_library_name_filter FROM parameters)
        	OR (SELECT owning_library_name_filter FROM parameters) = '')
    	AND jsonb_extract_path_text (ii.jsonb,'status','name') = 'In process'
    	AND itemext.barcode is not null
        AND TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
        	itemext.chronology,CASE WHEN itemext.copy_number > '1' THEN CONCAT (' c.',itemext.copy_number) ELSE '' END)) not similar to '%(n%rocess|n%rder|ancelled|OC)%'        
        AND TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
        	itemext.chronology,CASE WHEN itemext.copy_number > '1' THEN CONCAT (' c.',itemext.copy_number) ELSE '' END)) !=''
         
ORDER BY library_name, permanent_location_name, item__t.effective_shelving_order COLLATE "C",  title
;
