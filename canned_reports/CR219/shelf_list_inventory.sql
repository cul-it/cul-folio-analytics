--CR219
--shelf_list_inventory
--last updated: 9/12/24
--written by Sharon Markus and Joanne Leary
--This query finds shelf list inventory information by library location. 
--The most_recent_patron_group field determines what patron group an item 
--was assigned to most recently, which is important for assignments to the 
--Borrow Direct and Interlibrary Loan patron groups, which change frequently

WITH parameters AS (
    SELECT 
         -- Fill out library location filter ----
         '%%'::varchar AS owning_library_name_filter, -- Examples: Olin Library, Library Annex, etc.
         ''::varchar as location_name_filter --item_ext.effective_location_name
),
 		
recs AS 
(SELECT
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
--itemext.barcode like 'barcode' --use to test a specific barcode
    ((ll.library_name ILIKE (SELECT owning_library_name_filter FROM parameters)) OR ((SELECT owning_library_name_filter FROM parameters) = ''))
    --AND ((he.permanent_location_name = (SELECT location_name_filter FROM parameters)) OR ((SELECT location_name_filter FROM parameters) = ''))
    AND ((itemext.effective_location_name = (SELECT location_name_filter FROM parameters)) OR ((SELECT location_name_filter FROM parameters) = ''))
    AND (he.discovery_suppress = 'FALSE' OR he.discovery_suppress IS NULL)
    --AND (itemext.material_type_name = 'Book' OR itemext.item_hrid IS NULL)
    --AND instext.mode_of_issuance_name = 'single unit'
    AND itemext.material_type_name NOT IN ('Map','Microform','Microfiche','Newspaper','Object','Soundrec','Visual','Arhivman','Carrel Keys','Computfile')
    
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
 ),

recs2 as 
(SELECT DISTINCT
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
        contributors.ordinality,
        recs.item_status,
        recs.item_status_date,
        recs.item_notes,
        recs.format,
        rpg.patron_group_name as most_recent_patron_group,
        recs.effective_shelving_order COLLATE "C"

FROM
    recs
    LEFT JOIN inventory_instances AS instance
	    CROSS JOIN LATERAL jsonb_array_elements((instance.data #> '{contributors}')::jsonb) 
	    WITH ORDINALITY AS contributors(data)
    ON instance.hrid = recs.instance_hrid
    
    LEFT JOIN recent_patron_group as rpg 
    ON recs.item_id = rpg.item_id
    
--where (contributors.ordinality = 1 or contributors.ordinality is null)
--and recs.whole_call_number like 'Q1 .I81%'
)

SELECT
        recs2.library_name,           
        recs2.holdings_perm_loc_name,
        recs2.holdings_temp_loc_name,
        recs2.item_perm_loc_name,
        recs2.item_temp_loc_name,
        recs2.effective_location_name,
        recs2.instance_hrid,
        recs2.holdings_hrid,
        recs2.item_hrid,
        recs2."size",
        recs2.fixed_call_number,
        recs2.whole_call_number,
 		recs2.barcode,
        recs2.title,
        recs2.primary_contributor,
        recs2.ordinality,
        recs2.item_status,
        recs2.item_status_date,
        recs2.item_notes,
        recs2.format,
        recs2.most_recent_patron_group,
        recs2.effective_shelving_order COLLATE "C"
FROM recs2
WHERE recs2.ordinality = 1 or recs2.ordinality IS NULL

ORDER BY 
    recs2."size",
    recs2.effective_shelving_order COLLATE "C",
    recs2.holdings_perm_loc_name,
    recs2.holdings_temp_loc_name,
    recs2.item_perm_loc_name,
    recs2.item_temp_loc_name,
    recs2.effective_location_name
	 
	/*
	itemext.enumeration,
	itemext.chronology,
	itemext.copy_number,
	itemext.status_name,
	instext.title,
	itemext.effective_call_number_suffix
	*/
;

