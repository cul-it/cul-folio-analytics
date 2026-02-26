-- MCR415C - Long missing report for Selectors (Missing status only)
-- written by Joanne Leary
-- 11-19-25: Long missings for selectors 
-- based on MCR210 (which looks at many items statuses) but is revised to look only at "Long Missing" and uses derived tables rather than source table extracts
-- shows other copies on campus with their item statuses and dates
-- 12-5-25: added catalog URLs

WITH orig_miss AS 
	(SELECT DISTINCT
		item__.id,
		item__.jsonb#>>'{hrid}' AS item_hrid,
		item__.jsonb#>>'{status,name}' AS item_status_name,
		(item__.jsonb#>>'{status,date}')::date AS item_status_date
	
	FROM folio_inventory.item__ 
	WHERE item__.jsonb#>>'{status,name}' = 'Missing'
),

voycircs AS 
	(SELECT 
	     cta.item_id::varchar,
	     COUNT (DISTINCT cta.circ_transaction_id) AS voyager_checkouts,
	     MAX (cta.charge_date::timestamp) AS most_recent_voyager_checkout
	FROM vger.circ_trans_archive cta 
	GROUP BY cta.item_id::varchar
),

folio_circs AS 
	(SELECT 
	      li.item_id,
	      COUNT (DISTINCT li.loan_id) AS folio_checkouts,
	      MAX (li.loan_date::timestamp) AS most_recent_folio_checkout
	FROM local_derived.loans_items as li --folio_derived.loans_items AS li 
	GROUP BY li.item_id 
),

isbns AS 
	(SELECT 
	      iid.instance_id,
	      iid.identifier_type_name,
	      STRING_AGG (DISTINCT SUBSTRING (iid.identifier,'\d{9,}X{0,1}'),CHR(10)) AS isbn_number 
	FROM folio_derived.instance_identifiers AS iid
	WHERE iid.identifier_type_name = 'ISBN' -- does not include "Invalid ISBN"
	
	GROUP BY iid.instance_id, iid.identifier_type_name
),


issns AS 
	(SELECT 
	      iid.instance_id,
	      iid.identifier_type_name,
	      STRING_AGG (DISTINCT SUBSTRING (iid.identifier,'\d{4,}\-\d{4}'),CHR(10)) AS issn_number 
	FROM folio_derived.instance_identifiers AS iid
	WHERE iid.identifier_type_name = 'ISSN'
	
	GROUP BY iid.instance_id, iid.identifier_type_name
),


recs AS 
(SELECT
	 CURRENT_DATE::DATE AS todays_date,
     ll.library_name,
     he.permanent_location_name as holdings_location_name,
     ii.title,
     STRING_AGG (DISTINCT ic.contributor_name, CHR(10)) AS contributors,
     TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, itemext.enumeration, itemext.chronology,
          CASE WHEN itemext.copy_number >'1' THEN concat ('c.', itemext.copy_number) ELSE '' END)) AS whole_call_number,
     CASE WHEN he.call_number_type_name = 'Library of Congress classification' then SUBSTRING (he.call_number,'[A-Z]{1,3}')
          ELSE '' END AS lc_class,
     (TRIM ('.' FROM REPLACE (SUBSTRING (he.call_number,'\d{1,}\s{0,}\.{0,}\d{0,}'),' ','')))::NUMERIC AS lc_class_number,     
     ii.hrid AS instance_hrid,
     he.holdings_hrid,
     itemext.item_hrid,
     itemext.barcode,
     orig_miss.item_status_date AS original_missing_date,
     ii.discovery_suppress AS instance_suppress,
     he.discovery_suppress::boolean AS holdings_suppress,     
     he.type_name AS holdings_type_name, 
     itemext.material_type_name,     
     TRIM (' | ' FROM STRING_AGG (DISTINCT ip.publisher,' | ')) AS publisher,
     TRIM (' | ' FROM STRING_AGG (DISTINCT ip.date_of_publication,' | ')) AS date_of_publication,
     TRIM (' | ' FROM STRING_AGG (DISTINCT il.instance_language,' | ')) AS language,
     isbns.isbn_number,
     issns.issn_number,
     STRING_AGG (DISTINCT hn.note, CHR(10)) AS holdings_notes,
     STRING_AGG (DISTINCT han.administrative_note,CHR(10)) AS holdings_admin_notes,
     STRING_AGG (DISTINCT itemnotes.note,CHR(10)) AS item_notes,
     itemext.status_name AS item_status_name,
     TO_CHAR (itemext.status_date::DATE,'mm/dd/yyyy') AS item_status_date,
     TO_CHAR ((CASE WHEN item.create_date::date < itemext.created_date::date THEN item.create_date::date 
                    ELSE itemext.created_date::date END)::date,'mm/dd/yyyy') AS item_create_date,
     TO_CHAR (voycircs.most_recent_voyager_checkout::date,'mm/dd/yyyy') AS most_recent_voyager_checkout,
     TO_CHAR (folio_circs.most_recent_folio_checkout::date,'mm/dd/yyyy') AS most_recent_folio_checkout,
     CASE WHEN item.historical_charges::INTEGER IS NULL THEN 0 ELSE item.historical_charges::INTEGER END AS total_voyager_checkouts,
     CASE WHEN folio_circs.folio_checkouts::INTEGER IS NULL THEN 0 ELSE folio_circs.folio_checkouts::INTEGER END AS total_folio_checkouts,
     CONCAT ('https://catalog.library.cornell.edu/catalog/',ii.hrid) AS catalog_url,
     invitems.effective_shelving_order
                
FROM folio_inventory.instance__t AS ii  
     LEFT JOIN folio_derived.holdings_ext AS he 
     ON ii.id = he.instance_id::UUID               
                
     LEFT JOIN folio_derived.item_ext AS itemext 
     ON he.id = itemext.holdings_record_id 
                
     LEFT JOIN folio_inventory.item__t AS invitems  
     ON itemext.item_id::UUID = invitems.id
                
     LEFT JOIN orig_miss 
     ON itemext.item_id = orig_miss.id
                
     LEFT JOIN folio_derived.item_notes AS itemnotes
     ON itemext.item_id = itemnotes.item_id
                
     LEFT JOIN vger.item 
     ON itemext.item_hrid = item.item_id::VARCHAR
                
     LEFT JOIN voycircs
     ON itemext.item_hrid = voycircs.item_id::VARCHAR
                
     LEFT JOIN folio_derived.locations_libraries AS ll 
     ON he.permanent_location_id = ll.location_id 
                
     LEFT JOIN folio_derived.instance_publication AS ip 
     ON ii.id = ip.instance_id 
                
     LEFT JOIN isbns 
     ON ii.id = isbns.instance_id::UUID
          
     LEFT JOIN issns 
     ON ii.id = issns.instance_id::UUID
                
     LEFT JOIN folio_derived.instance_contributors AS ic 
     ON ii.id = ic.instance_id
                
     LEFT JOIN folio_derived.instance_languages AS il 
     ON ii.id = il.instance_id
                
     LEFT JOIN folio_circs 
     ON itemext.item_id = folio_circs.item_id
    
     LEFT JOIN folio_derived.holdings_notes AS hn 
	   ON he.id = hn.holding_id
	 
	   LEFT JOIN folio_derived.holdings_administrative_notes AS han 
	   ON he.id = han.holdings_id

WHERE itemext.status_name = 'Long missing' 
	AND itemext.material_type_name NOT IN ('Supplies','Peripherals','Laptop','Keys','Locker Keys','Equipment','Room Keys','Umbrella','ILL MATERIAL','BD MATERIAL')

GROUP BY 
	 CURRENT_DATE::DATE, 
	 ll.library_name,
     he.permanent_location_name,
     ii.title,
     TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, itemext.enumeration, itemext.chronology,
          CASE WHEN itemext.copy_number >'1' THEN CONCAT ('c.', itemext.copy_number) ELSE '' END)),
     CASE WHEN he.call_number_type_name = 'Library of Congress classification' THEN SUBSTRING (he.call_number,'[A-Z]{1,3}')
          ELSE '' END,
     (TRIM ('.' FROM REPLACE (SUBSTRING (he.call_number,'\d{1,}\s{0,}\.{0,}\d{0,}'),' ','')))::NUMERIC,
     ii.hrid,
     he.holdings_hrid,
     itemext.item_hrid,
     itemext.barcode,
     orig_miss.item_status_date,
     ii.discovery_suppress,
     he.discovery_suppress::BOOLEAN,
     isbns.isbn_number,
     issns.issn_number,
     itemext.material_type_name,
     he.type_name,               
     itemext.status_name,
     TO_CHAR (itemext.status_date::DATE,'mm/dd/yyyy'),
     TO_CHAR ((CASE WHEN item.create_date::DATE < itemext.created_date::DATE THEN item.create_date::DATE 
                    ELSE itemext.created_date::DATE END)::DATE,'mm/dd/yyyy'),
     TO_CHAR (voycircs.most_recent_voyager_checkout::DATE,'mm/dd/yyyy'),
     TO_CHAR (folio_circs.most_recent_folio_checkout::DATE,'mm/dd/yyyy'),
     CASE WHEN item.historical_charges::INTEGER IS NULL THEN 0 ELSE item.historical_charges::INTEGER END,
     CASE WHEN folio_circs.folio_checkouts::INTEGER IS NULL THEN 0 ELSE folio_circs.folio_checkouts::INTEGER END,
     CONCAT ('https://catalog.library.cornell.edu/catalog/',ii.hrid),
     invitems.effective_shelving_order
),

otherlibs AS 
	(SELECT 
		instance__t.hrid AS instance_hrid,
		instance__t.title,
		loclibrary__t.name AS library_name,
		STRING_AGG (DISTINCT
						CASE WHEN item__t.hrid IS NULL 
						THEN '' 
						ELSE (
							CONCAT (instance__t.hrid,' - ',hrt.hrid,' - ',item__t.hrid,' - ', location__t.name,' ',item.jsonb#>>'{effectiveCallNumberComponents,callNumber}',' ',
							item__t.enumeration,' ',item__t.chronology, ' ',CASE WHEN item__t.copy_number >'1' THEN CONCAT ('c.',item__t.copy_number) ELSE '' END,
							' --  ',item.jsonb#>>'{status,name}',' - ',((item.jsonb#>>'{status,date}')::DATE))::VARCHAR
							)							 
						END,
							CHR(10)
					)
			 AS all_copies
		
	FROM recs
		LEFT JOIN folio_inventory.instance__t 
		ON recs.instance_hrid = instance__t.hrid 
		
		LEFT JOIN folio_inventory.holdings_record__t  AS hrt 
		ON instance__t.id = hrt.instance_id 
		
		LEFT JOIN folio_inventory.item__t 
		ON hrt.id = item__t.holdings_record_id 
		
		LEFT JOIN folio_inventory.item 
		ON item__t.id = item.id 
		
		LEFT JOIN folio_inventory.location__t 
		ON item__t.effective_location_id = location__t.id 
		
		LEFT JOIN folio_inventory.loclibrary__t 
		ON location__t.library_id = loclibrary__t.id
	
	WHERE  
		(instance__t.discovery_suppress = FALSE OR instance__t.discovery_suppress IS NULL)
	
	GROUP BY instance__t.hrid, instance__t.title, loclibrary__t.name
)

SELECT 
	 recs.todays_date,
	 recs.library_name,
     recs.holdings_location_name,
     recs.title,
     recs.instance_hrid,
     recs.holdings_hrid,
     recs.item_hrid,
     recs.barcode,
     recs.whole_call_number,
     recs.lc_class,
     recs.lc_class_number,    
     recs.item_status_name,
     recs.item_status_date,
     recs.original_missing_date, 
     recs.contributors, 
     recs.instance_suppress,
     recs.holdings_suppress,     
     recs.holdings_type_name, 
     recs.material_type_name,
     recs.holdings_notes,
     recs.holdings_admin_notes,
     recs.publisher,
     recs.date_of_publication,
     recs.language,
     recs.isbn_number,
     recs.issn_number,
     recs.item_notes,
     recs.item_create_date,
	 recs.total_voyager_checkouts + recs.total_folio_checkouts AS total_voyager_and_folio_checkouts,
	 CASE WHEN recs.total_voyager_checkouts > 0 AND COALESCE (recs.most_recent_folio_checkout, recs.most_recent_voyager_checkout, ' - ') = ' - ' 
		THEN 'pre-Voyager' 
		ELSE COALESCE (recs.most_recent_folio_checkout, recs.most_recent_voyager_checkout, ' - ') 
		END AS most_recent_checkout,
	 TRIM (LEADING CHR(10) FROM STRING_AGG (DISTINCT otherlibs.all_copies,CHR(10))) AS all_copies,
	 recs.catalog_url,
     recs.effective_shelving_order

FROM recs 
	LEFT JOIN otherlibs 
	ON recs.instance_hrid = otherlibs.instance_hrid 
	
GROUP BY 
	 recs.todays_date,
	 recs.library_name,
     recs.holdings_location_name,
     recs.title,
     recs.instance_hrid,
     recs.holdings_hrid,
     recs.item_hrid,
     recs.barcode,
     recs.whole_call_number,
     recs.lc_class,
     recs.lc_class_number,    
     recs.item_status_name,
     recs.item_status_date,
     recs.original_missing_date, 
     recs.contributors, 
     recs.instance_suppress,
     recs.holdings_suppress,     
     recs.holdings_type_name, 
     recs.material_type_name,
     recs.holdings_notes,
     recs.holdings_admin_notes,
     recs.publisher,
     recs.date_of_publication,
     recs.language,
     recs.isbn_number,
     recs.issn_number,
     recs.item_notes,
     recs.item_create_date,
	   recs.total_voyager_checkouts + recs.total_folio_checkouts,
	   CASE WHEN recs.total_voyager_checkouts > 0 AND COALESCE (recs.most_recent_folio_checkout, recs.most_recent_voyager_checkout, ' - ') = ' - ' 
		  THEN 'pre-Voyager' 
		  ELSE COALESCE (recs.most_recent_folio_checkout, recs.most_recent_voyager_checkout, ' - ') 
		 END,
	   recs.catalog_url,
	   recs.effective_shelving_order
     
ORDER BY recs.library_name, recs.holdings_location_name, recs.effective_shelving_order COLLATE "C"
;
