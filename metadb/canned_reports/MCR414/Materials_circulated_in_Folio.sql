--MCR214
--Materials circulated in Folio
-- This query finds all item records created after a given start date at a given library, and shows circ counts by year circulated (Folio loans only)
--Please read details in ReadMe file

WITH parameters as 
(select 
	'%Music%' as library_name_filter, -- required
	'' as start_date_filter, -- enter beginning item create date ('yyyy-mm-dd') or leave blank for everything created on or after 2021-07-01
	'' as lc_class_filter -- enter an LC class or leave blank for all items
),

recs AS 
(SELECT 
		locations_libraries.library_name,
		item_ext.effective_location_name AS item_effective_location_name, 
		instance_ext.title,
		instance_contributors.contributor_name AS author,
		TRIM (CONCAT (holdings_ext.call_number_prefix,' ',holdings_ext.call_number,' ',holdings_ext.call_number_suffix,' ',item_ext.enumeration,' ',item_ext.chronology,
			CASE WHEN item_ext.copy_number >'1' THEN CONCAT ('c.',item_ext.copy_number) ELSE '' END)) AS whole_call_number,
		SUBSTRING (holdings_ext.call_number,'[A-Z]{1,3}') AS lc_class,
		REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (holdings_ext.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::NUMERIC AS lc_class_number,
		instance_ext.instance_hrid, 
		holdings_ext.holdings_hrid,
		item_ext.item_hrid,		
		COALESCE (item_ext.temporary_loan_type_name,item_ext.permanent_loan_type_name,'-') AS effective_loan_type_name,
		holdings_ext.type_name AS holdings_type_name,
		item_ext.material_type_name,
		STRING_AGG (DISTINCT instance_publication.publisher,' | ') AS publisher,
		SUBSTRING (instance_publication.date_of_publication,'\d{4}') AS publication_date,
		instance_languages.instance_language AS primary_language,
		instance_subjects.subjects AS primary_subject,
		STRING_AGG (DISTINCT instance_subjects2.subjects,' | ') AS other_subjects,
		STRING_AGG (DISTINCT organizations__t.name,' | ') AS vendor_name,
		DATE_PART ('year', item_ext.created_date::date) AS year_item_added_to_collection,
		CASE WHEN loans_items.loan_date::date IS NULL THEN 'Not circulated' ELSE  (DATE_PART ('year',loans_items.loan_date::date))::VARCHAR END AS year_of_loan,
		COALESCE (COUNT (DISTINCT loans_items.loan_id),0) AS number_of_loans,
		item__t.effective_shelving_order COLLATE "C"
	
	FROM folio_derived.instance_ext 
		LEFT JOIN folio_derived.instance_publication
		ON instance_ext.instance_id = instance_publication.instance_id
		
		LEFT JOIN folio_derived.holdings_ext  
		ON instance_ext.instance_id = holdings_ext.instance_id 

		LEFT JOIN folio_derived.item_ext  
		ON holdings_ext.id = item_ext.holdings_record_id 
		
		LEFT JOIN folio_derived.locations_libraries 
		ON item_ext.effective_location_name = locations_libraries.location_name
		
		LEFT JOIN folio_inventory.item__t
		ON item_ext.item_id = item__t.id 
		
		LEFT JOIN folio_derived.loans_items 
		ON item_ext.item_id = loans_items.item_id 
		AND item__t.id = loans_items.item_id
		
		LEFT JOIN folio_derived.instance_languages 
		ON instance_ext.instance_id = instance_languages.instance_id
		
		LEFT JOIN folio_derived.instance_subjects 
		ON instance_ext.instance_id = instance_subjects.instance_id
		
		LEFT JOIN folio_derived.instance_subjects as instance_subjects2 
		ON instance_ext.instance_id = instance_subjects2.instance_id
		
		LEFT JOIN folio_derived.po_instance 
		ON instance_ext.instance_id = po_instance.pol_instance_id
		
		LEFT JOIN folio_organizations.organizations__t 
		ON po_instance.vendor_code = organizations__t.code
		
		LEFT JOIN folio_derived.instance_contributors 
		ON instance_ext.instance_id = instance_contributors.instance_id
		
WHERE 

	locations_libraries.library_name like (select library_name_filter from parameters) --'%Music%'
	AND (holdings_ext.discovery_suppress = false OR holdings_ext.discovery_suppress IS NULL) 
	AND (instance_ext.discovery_suppress = false OR instance_ext.discovery_suppress IS NULL)
	AND (item_ext.discovery_suppress = false OR item_ext.discovery_suppress IS NULL)	
	AND (instance_publication.publication_ordinality = 1 OR instance_publication.instance_id IS NULL)
	AND COALESCE (item_ext.temporary_loan_type_name, item_ext.permanent_loan_type_name,'-') !='Non-circulating'
	AND holdings_ext.type_name !='Serial'
	AND item_ext.material_type_name NOT IN 
		('Laptop','Peripherals','Equipment','Room Keys','Supplies','Umbrella','Locker Keys','ILL MATERIAL',
		'BD MATERIAL','Serial','Periodical','Unbound','Newspaper','Microform','Music (score)','Object')
	AND (instance_subjects.subjects_ordinality = 1 OR instance_subjects.instance_id IS NULL)
	AND (instance_subjects2.subjects_ordinality > 1 OR instance_subjects2.instance_id IS NULL)
	AND (instance_contributors.contributor_ordinality = 1 OR instance_contributors.instance_id IS NULL)
	AND (instance_languages.language_ordinality = 1 OR instance_languages.instance_id IS NULL)
	AND item_ext.created_date::date >= case when (select start_date_filter from parameters) ='' then '2021-07-01' else (select start_date_filter from parameters)::date end
	and case when (select lc_class_filter from parameters) = '' 
		then SUBSTRING (holdings_ext.call_number,'[A-Z]{1,3}') like '%%' 
		else SUBSTRING (holdings_ext.call_number,'[A-Z]{1,3}') = (select lc_class_filter from parameters)
		end

GROUP BY
	locations_libraries.library_name,
		item_ext.effective_location_name, 
		instance_ext.title,
		instance_contributors.contributor_name,
		TRIM (CONCAT (holdings_ext.call_number_prefix,' ',holdings_ext.call_number,' ',holdings_ext.call_number_suffix,' ',item_ext.enumeration,' ',item_ext.chronology,
			CASE WHEN item_ext.copy_number >'1' THEN CONCAT ('c.',item_ext.copy_number) ELSE '' END)),
		SUBSTRING (holdings_ext.call_number,'[A-Z]{1,3}'),
		REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (holdings_ext.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::NUMERIC,
		instance_ext.instance_hrid, 
		holdings_ext.holdings_hrid,
		item_ext.item_hrid,		
		COALESCE (item_ext.temporary_loan_type_name,item_ext.permanent_loan_type_name,'-'),
		holdings_ext.type_name,
		item_ext.material_type_name,
		SUBSTRING (instance_publication.date_of_publication,'\d{4}'),
		instance_languages.instance_language,
		instance_subjects.subjects,
		DATE_PART ('year', item_ext.created_date::date),
		DATE_PART ('year',loans_items.loan_date::date),
		CASE WHEN loans_items.loan_date::date IS NULL THEN 'Not circulated' ELSE  (DATE_PART ('year',loans_items.loan_date::date))::VARCHAR END,
		loans_items.loan_id,
		item__t.effective_shelving_order COLLATE "C"
)
		
SELECT
	recs.library_name,
		recs.item_effective_location_name, 
		recs.title,
		recs.author,
		recs.whole_call_number,
		recs.lc_class,
		recs.lc_class_number,
		recs.instance_hrid, 
		recs.holdings_hrid,
		recs.item_hrid,		
		recs.effective_loan_type_name,
		recs.holdings_type_name,
		recs.material_type_name,
		recs.publisher,
		recs.publication_date,
		recs.primary_language,
		recs.primary_subject,
		recs.other_subjects,
		recs.vendor_name,
		recs.year_item_added_to_collection,
		recs.year_of_loan,
		SUM (recs.number_of_loans) AS number_of_loans,
		recs.effective_shelving_order COLLATE "C"
FROM recs 
GROUP BY 
	recs.library_name,
		recs.item_effective_location_name, 
		recs.title,
		recs.author,
		recs.whole_call_number,
		recs.lc_class,
		recs.lc_class_number,
		recs.instance_hrid, 
		recs.holdings_hrid,
		recs.item_hrid,		
		recs.effective_loan_type_name,
		recs.holdings_type_name,
		recs.material_type_name,
		recs.publisher,
		recs.publication_date,
		recs.primary_language,
		recs.primary_subject,
		recs.other_subjects,
		recs.vendor_name,
		recs.year_item_added_to_collection,
		recs.year_of_loan,
		recs.effective_shelving_order COLLATE "C"
		
ORDER BY item_effective_location_name, lc_class, lc_class_number, effective_shelving_order COLLATE "C" 
;
