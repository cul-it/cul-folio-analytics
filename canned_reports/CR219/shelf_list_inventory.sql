--CR219
--shelf list inventory
--last updated: 8/9/24
--written by Sharon Markus and Joanne Leary
--This query finds shelf list inventory information by library location. 
--The most_recent_patron_group field determines what patron group an item 
--was assigned to most recently, which is important for assignments to the 
--Borrow Direct and Interlibrary Loan patron groups, which change frequently
--8-3-24: updated query to put the contributors and most recent patron group subqueries at the end (so they use the previously found records in "recs" to get the data, which greatly speeds up the query)
	-- fixed the Where statements that refers to parameters (parentheses got screwed up); added wildcards to the Library name filter
	-- added item_status_date
	-- shortened the "size" sort and "in process" exclusions to use just the holdings call number components
	-- added the item notes (aggregated) to the "recs" query
	-- added the permanent, temporary and effective locations for the holdings and item call numbers to help explain the strange results appearing on the list
	-- added a statement at the end to fix the carriage returns in call numbers (separate field, "fixed call number")
--8-9-24: updated query to remove some filters
    --commented out material type name in WHERE filter 
    --commented out mode_of_issuance_name in WHERE filter
    --replaced he.permanent_location_name with itemext.permanent_location_name in the 
       --WHERE statement for the owning library name parameter filter

WITH parameters AS (
    SELECT 
         -- Fill out -owning library filter ----
         '%%'::varchar AS owning_library_name_filter, -- Examples: Olin Library, Library Annex, etc.
         'Uris'::varchar as location_name_filter--add permanent location name
),
 		
recs as 
(select
		ll.library_name,           
        he.permanent_location_name as holdings_perm_loc_name,
        he.temporary_location_name as holdings_temp_loc_name,
        itemext.permanent_location_name as item_perm_loc_name,
        itemext.temporary_location_name as item_temp_loc_name,
        itemext.effective_location_name,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_id,
        itemext.item_hrid,
        
--show size as +++, ++, or + with call number, copy number, enumeration, and chronology

        CASE WHEN concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) LIKE '%+++%' THEN '+++'
             WHEN concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) LIKE '%++%' THEN '++'
 			 WHEN concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) LIKE '%+%' THEN '+'       
             ELSE ' 'END AS "size",
      
        trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',itemext.enumeration,' ',itemext.chronology,
        	CASE WHEN itemext.copy_number > '1' THEN CONCAT ('c.',itemext.copy_number) ELSE '' END)) AS whole_call_number,
        itemext.barcode,
        instext.title,
        itemext.status_name AS item_status,
        itemext.status_date::date as item_status_date,
        string_agg (distinct itemnotes.note,' | ') as item_notes,
        itemext.material_type_name AS format,
        ii.effective_shelving_order COLLATE "C"
		            
FROM folio_reporting.instance_ext AS instext
     LEFT JOIN folio_reporting.holdings_ext AS he ON instext.instance_id = he.instance_id        
     LEFT JOIN folio_reporting.locations_libraries AS ll ON he.permanent_location_id = ll.location_id       
     LEFT JOIN folio_reporting.item_ext AS itemext ON he.holdings_id = itemext.holdings_record_id
     LEFT JOIN inventory_items AS ii ON itemext.item_id = ii.id
     LEFT JOIN folio_reporting.item_notes AS itemnotes ON itemext.item_id = itemnotes.item_id

WHERE  
	--itemext.barcode = '31924057505723' --use to test single item using the barcode to filter results
    ((ll.library_name ILIKE (SELECT owning_library_name_filter FROM parameters)) OR ((SELECT owning_library_name_filter FROM parameters) = ''))
    --AND ((he.permanent_location_name = (SELECT location_name_filter FROM parameters)) OR ((SELECT location_name_filter FROM parameters) = ''))
    AND ((itemext.permanent_location_name = (SELECT location_name_filter FROM parameters)) OR ((SELECT location_name_filter FROM parameters) = ''))
    AND (he.discovery_suppress = 'FALSE' OR he.discovery_suppress IS NULL)
    --AND (itemext.material_type_name = 'Book' OR itemext.item_hrid IS NULL)
    --AND instext.mode_of_issuance_name = 'single unit'
    AND itemext.material_type_name NOT IN ('Map','Microform','Microfiche','Newspaper','Object','Soundrec','Visual')
    
 --removes items that are being processed in some way
    
    AND CONCAT (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix) NOT ILIKE '%In%roc%'
    AND CONCAT (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix) NOT ILIKE '%Order%'
    AND CONCAT (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix) NOT ILIKE '%Cancelled%'

--Call Number Filter
    --AND itemext.effective_call_number LIKE 'K%'
    --AND itemext.effective_call_number BETWEEN 'L%' AND 'PN%'
--using regular expression for LC call number range
   -- AND SUBSTRING (he.call_number,'([A-Z]{1,3})') LIKE 'Z%'
    --AND SUBSTRING (he.call_number,'([A-Z]{1,3})') ilike any (array ['QB%','PC%','Z%'])
    --AND SUBSTRING (he.call_number,'([A-Za-z]{1,3})') similar to '(QB%|PC%|Z%)'
    --AND SUBSTRING (he.call_number,'([A-Z]{1,3})') <= 'PD%' 
  
GROUP BY 
	ll.library_name,           
        he.permanent_location_name,
        he.temporary_location_name,
        itemext.permanent_location_name,
        itemext.temporary_location_name,
        itemext.effective_location_name,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_id,
        itemext.item_hrid,
        
--show size as +++, ++, or + with call number, copy number, enumeration, and chronology

        CASE WHEN concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) LIKE '%+++%' THEN '+++'
             WHEN concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) LIKE '%++%' THEN '++'
 			 WHEN concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) LIKE '%+%' THEN '+'       
             ELSE ' 'END,
      
        TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',itemext.enumeration,' ',itemext.chronology,
        	CASE WHEN itemext.copy_number > '1' THEN CONCAT ('c.',itemext.copy_number) ELSE '' END)),
 
        itemext.barcode,
        instext.title,
        itemext.status_name,
        itemext.status_date::date,
        itemext.material_type_name,
        ii.effective_shelving_order COLLATE "C"
),

max_loan_status AS
		(SELECT 
		recs.item_id,
		--li.item_id,
		MAX (li.loan_date::TIMESTAMP) AS max_loan_date

		FROM recs 
		left join folio_reporting.loans_items AS li
		on recs.item_id = li.item_id
		
		GROUP BY
		recs.item_id--li.item_id
),

recent_patron_group AS 
 		(SELECT 
 		li.item_id,
 		max_loan_status.max_loan_date,
 		li.patron_group_name
 		
 		FROM max_loan_status
 		INNER JOIN folio_reporting.loans_items AS li ON max_loan_status.item_id = li.item_id 
 		AND max_loan_status.max_loan_date = li.loan_date
 )

SELECT distinct
		recs.library_name,           
        recs.holdings_perm_loc_name,
        recs.holdings_temp_loc_name,
        recs.item_perm_loc_name,
        recs.item_temp_loc_name,
        recs.effective_location_name,
        recs.instance_hrid,
        recs.holdings_hrid,
        recs.item_hrid,
        recs."size",
        replace (replace (recs.whole_call_number, chr(13), ''),chr(10),'') as fixed_call_number,
        recs.whole_call_number,
 		recs.barcode,
        recs.title,
        contributors.data #>> '{name}' AS primary_contributor,
        recs.item_status,
        recs.item_status_date,
        recs.item_notes,
        recs.format,
        rpg.patron_group_name as most_recent_patron_group,
        recs.effective_shelving_order COLLATE "C"

FROM
    recs
    left join inventory_instances AS instance
	    CROSS JOIN LATERAL jsonb_array_elements((instance.data #> '{contributors}')::jsonb) 
	    with ordinality AS contributors(data)
    on instance.hrid = recs.instance_hrid
    
    left join recent_patron_group as rpg 
    on recs.item_id = rpg.item_id
    
where contributors.ordinality = 1
		
ORDER BY 
	recs."size",
	recs.effective_shelving_order COLLATE "C",
	recs.holdings_perm_loc_name,
    recs.holdings_temp_loc_name,
    recs.item_perm_loc_name,
    recs.item_temp_loc_name,
    recs.effective_location_name
	 
	/*itemext.enumeration,
	itemext.chronology,
	itemext.copy_number,
	itemext.status_name,
	instext.title,
	itemext.effective_call_number_suffix*/
;
