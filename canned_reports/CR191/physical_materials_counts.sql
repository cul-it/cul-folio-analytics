--Bring in format code from marctab. 
WITH
vs_marc_formats AS 
    (SELECT 
    sm.instance_id,
    sm.field,
    	 substring(sm."content", 7, 2) AS "format_code"
 FROM srs_marctab AS sm   
 WHERE    sm.field = '000'
 ),
 
 --Bring in this marker for visual material type from marctab; 008/33 v=videorecording
 vs_visualmat_type AS
 (SELECT 
	sv.instance_id,
	substring(sv.content, 34, 1)  AS visualmat_type
    FROM srs_marctab AS sv 
   WHERE sv.field='008'
   ),
    
--bring in item details

vs_items AS
(SELECT 
ie.item_id, 
ie.holdings_record_id,
ie.permanent_location_name AS item_permanent_location_name,
ie.created_date::DATE AS item_record_created_date,
date_part ('month',ie.created_date::DATE) as month_record_created,
date_part ('year',ie.created_date::DATE)::VARCHAR as record_created,
        
CASE WHEN 
                date_part ('month',ie.created_date::DATE) >'6' 
                THEN concat ('FY ', date_part ('year',ie.created_date::DATE) + 1) 
                ELSE concat ('FY ', date_part ('year',ie.created_date::DATE))
                END as record_created_fiscal_year

FROM folio_reporting.item_ext as ie 

--exclude materials labeled as 'bound with' as they are a subset of an item
WHERE concat_ws (' ',ie.effective_call_number_prefix,ie.effective_call_number,ie.effective_call_number_suffix,ie.enumeration,ie.chronology) NOT ILIKE '%bound%with%'
),


--bring in holdings details
vs_holdings AS
    (SELECT 
   	he.holdings_id,
   	he.instance_id,
   	--identify microforms
   	CASE WHEN trim(concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)) ILIKE ANY(ARRAY['%film%' ,'%fiche%', '%micro%', '%vault%']) THEN 'Yes' Else 'No'  END microform,
   	he.type_name AS holdings_type,
   	he.permanent_location_name AS holdings_permanent_location_name
 FROM folio_reporting.holdings_ext AS he
 WHERE 
 --exclude materials from the following locations, as these locations are sub-sets of main locations, and including them would result in double counts
(he.permanent_location_name NOT ILIKE ALL(ARRAY['serv,remo','%LTS%','Agricultural Engineering','Bindery Circulation',
'Biochem Reading Room', 'Borrow Direct', 'CISER', 'cons,opt', 'Engineering', 'Engineering Reference', 'Engr,wpe',
'Entomology', 'Food Science', 'Law Technical Services', 'LTS Review Shelves', 'LTS E-Resources & Serials','Mann Gateway',
'Mann Hortorium', 'Mann Hortorium Reference', 'Mann Technical Services', 'Iron Mountain', 'Interlibrary Loan%', 'Phys Sci',
'RMC Technical Services', 'No Library','x-test', 'z-test location' ]) OR he.permanent_location_name IS NULL)

--exclude the following materials as they are not available for discovery
AND trim(concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)) NOT ILIKE ALL(ARRAY['on order%', 'in process%', 'Available for the library to purchase', 
 'On selector%'])
AND (he.discovery_suppress IS NOT TRUE OR he.discovery_suppress IS NULL)
),

--combine formats, items, holdings
vs_all_counts AS 
    (SELECT DISTINCT
   	vi.item_id,
   	vi.record_created_fiscal_year,
   	vh.holdings_id,
   	vh.instance_id,
   	vh.holdings_type,
   	vh.microform,
   	vh.holdings_permanent_location_name,
   	mf.format_code,
   	vt.visualmat_type,
   	fnm.format_name,
   	lce.main_location
  -- 	lce.locations,
  -- 	lce.locations_details
   	
  	FROM vs_items AS vi
   	LEFT JOIN vs_holdings AS vh ON vi.holdings_record_id = vh.holdings_id 
    LEFT JOIN vs_marc_formats AS mf ON vh.instance_id ::uuid = mf.instance_id
    LEFT JOIN vs_visualmat_type AS vt on vh.instance_id ::uuid = vt.instance_id
    LEFT JOIN local_core.vs_format_name AS fnm ON mf.format_code  = fnm.format_code 
    LEFT JOIN local_core.vs_location_codes AS lce ON vh.holdings_permanent_location_name = lce.permanent_location_name       
    )

 
  --Main query
    SELECT 
    NOW(),
  	count (distinct item_id) AS count_item_id, 
  	count (distinct instance_id) AS count_instance_id, 
  	holdings_type,
  	microform,
  	main_location,
 	holdings_permanent_location_name,
   	format_code,
   	visualmat_type,
   	format_name,
   	record_created_fiscal_year
   	
   	FROM vs_all_counts
   	
   	
  -- 	add required WHERE statement(s) to select a specific fiscal year or material type, see below
   	
   	GROUP BY 
    holdings_type,
  	microform,
  	main_location,
 	holdings_permanent_location_name,
   	format_code,
   	visualmat_type,
   	format_name,
   	record_created_fiscal_year
   	;
    
    --a, c, d, and t are physical volumes, i and j are sound recordings, g is video. Microform identification is via the holdings call number. 
   
--To select a fiscal year: WHERE record_created_fiscal_year = 'FY2022'
--To select volumes: WHERE format_code ILIKE ANY(['a%',  'c%', 'd%', 't%']) AND microform='No'
--To select sound recordings: WHERE  format_code ILIKE ANY(['i%',  'j%']) AND microform='No'
--To select video recordings: WHERE format_code ILIKE 'g%' AND microform='No'
--To select microforms: WHERE microform='Yes'
      
