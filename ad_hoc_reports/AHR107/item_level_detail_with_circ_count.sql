WITH parameters AS 
(SELECT
        'Olin'::VARCHAR AS location_name_filter, -- enter the location name. Ex: ‘Math’, ‘ILR Reference’, ‘Fine Arts – Annex”, etc.
        'HM'::VARCHAR AS lc_class_filter, -- enter the LC class. Ex: ‘QA’, ‘T’, ‘HE’, ‘NAC’, etc. (Upper case)
        '%' AS class_number_filter, -- enter an LC class number before the % sign. Ex: ‘273.5%’, ‘76.73%’, etc.
        '%%'::VARCHAR AS title_filter -- enter a title between the % signs (not case-sensitive). Ex: ‘%journal of rheology%’, ‘%sarawak club%’, ‘%european union%’  
        ),
recs AS 
(SELECT 
        ii.title,
        ii.id AS instance_id,
        ii.hrid AS instance_hrid,
        he.holdings_id,
        he.holdings_hrid,
        invitems.id AS item_id,
        invitems.hrid AS item_hrid,
        ll.location_name,
        CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
                CASE WHEN invitems.copy_number >'1' THEN CONCAT (' c.',invitems.copy_number) ELSE '' END) AS whole_call_number,
        is2.subject AS primary_subject,
        STRING_AGG (DISTINCT is3.subject,' | ') AS all_subjects,
        STRING_AGG (DISTINCT ip.date_of_publication,' | ')::VARCHAR AS pub_date,
        (CASE WHEN ii.status_updated_date::DATE >'2021-07-01' THEN DATE_PART ('year',ii.status_updated_date::DATE) 
                ELSE DATE_PART('year',bib_master.create_date::DATE) END)::VARCHAR AS year_acquired,
        SUBSTRING (he.call_number, '[A-Z]{1,3}') AS lc_class,
        SUBSTRING (he.call_number, '\d{1,}\.{0,}\d{0,}') AS class_number,
        he.type_name AS holdings_type_name,
        STRING_AGG (distinct hn.note,' | ') AS holdings_note,
        item.historical_charges AS voyager_historical_charges
FROM inventory_instances AS ii 
        LEFT JOIN folio_reporting.holdings_ext AS he ON ii.id = he.instance_id 
        LEFT JOIN inventory_items AS invitems ON he.holdings_id = invitems.holdings_record_id
        LEFT JOIN folio_reporting.holdings_notes AS hn ON he.holdings_id = hn.holdings_id
        LEFT JOIN folio_reporting.instance_subjects AS is2 ON ii.id = is2.instance_id 
        LEFT JOIN folio_reporting.instance_subjects AS is3 ON ii.id = is3.instance_id 
        LEFT JOIN folio_reporting.instance_publication AS ip ON ii.id = ip.instance_id
        LEFT JOIN folio_reporting.locations_libraries AS ll ON he.permanent_location_id = ll.location_id 
        LEFT JOIN vger.item ON invitems.hrid = item.item_id::VARCHAR
        LEFT JOIN vger.bib_master ON ii.hrid = bib_master.bib_id::VARCHAR
        WHERE (ll.location_name = (SELECT location_name_filter FROM parameters) OR (SELECT location_name_filter FROM parameters)='')
        AND (he.discovery_suppress = 'False' OR he.discovery_suppress = NULL)
        AND (SUBSTRING (he.call_number, '[A-Z]{1,3}') like (SELECT lc_class_filter FROM parameters) OR (SELECT lc_class_filter FROM parameters) = '')
        AND ((SELECT class_number_filter FROM parameters) ='' OR (SUBSTRING (he.call_number, '\d{1,}\.{0,}\d{0,}') LIKE (SELECT class_number_filter FROM parameters)))
        AND (ii.title ILIKE (SELECT title_filter FROM parameters) OR (SELECT title_filter FROM parameters) = '')
        AND (is2.subject_ordinality = 1 OR is2.subject_ordinality IS NULL)
GROUP BY 
        ii.title,
        ii.id,
        ii.hrid,
        he.holdings_id,
        he.holdings_hrid,
        invitems.id,
        invitems.hrid,
        ll.location_name,
        CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',invitems.enumeration,' ',invitems.chronology,
                CASE WHEN invitems.copy_number >'1' THEN CONCAT (' c.',invitems.copy_number) ELSE '' END),
        is2.subject,
        (CASE WHEN ii.status_updated_date::DATE >'2021-07-01' THEN DATE_PART ('year',ii.status_updated_date::DATE) 
                ELSE DATE_PART('year',bib_master.create_date::DATE) END)::VARCHAR,
        SUBSTRING (he.call_number, '[A-Z]{1,3}'),
        SUBSTRING (he.call_number, '\d{1,}\.{0,}\d{0,}'),
        he.type_name,
        item.historical_charges
),
circs AS 
(SELECT 
        recs.title,
        recs.instance_id,
        recs.instance_hrid,
        recs.holdings_id,
        recs.holdings_hrid,
        recs.item_id,
        recs.item_hrid,
        recs.location_name,
        recs.whole_call_number,
        recs.primary_subject,
        recs.all_subjects,
        recs.pub_date,
        recs.year_acquired,
        recs.lc_class,
        recs.class_number,
        recs.holdings_type_name,
        recs.holdings_note,
        recs.voyager_historical_charges,
        COUNT(li.loan_id) AS folio_loans
FROM recs 
        LEFT JOIN folio_reporting.loans_items AS li ON (CASE WHEN recs.item_id IS NULL THEN 'xxx' ELSE recs.item_id END) = li.item_id
GROUP BY 
        recs.title,
        recs.instance_id,
        recs.instance_hrid,
        recs.holdings_id,
        recs.holdings_hrid,
        recs.item_id,
        recs.item_hrid,
        recs.location_name,
        recs.whole_call_number,
        recs.primary_subject,
        recs.all_subjects,
        recs.pub_date,
        recs.year_acquired,
        recs.lc_class,
        recs.class_number,
        recs.holdings_type_name,
        recs.holdings_note,
        recs.voyager_historical_charges
)
SELECT DISTINCT
        circs.title,
        circs.instance_hrid,
        circs.holdings_hrid,
        circs.item_hrid,
        circs.location_name,
        circs.whole_call_number,
        circs.primary_subject,
        circs.all_subjects,
        SUBSTRING (circs.pub_date,'\d{1,4}') AS norm_pub_date,
        circs.year_acquired,
        circs.lc_class,
        circs.class_number::NUMERIC,
        jlbfd.bib_format_display AS bib_format_name,
        circs.holdings_type_name,
        circs.holdings_note,
        circs.voyager_historical_charges,
        circs.folio_loans,
        invitems.effective_shelving_order COLLATE "C"
 FROM circs 
        LEFT JOIN srs_marctab AS sm ON circs.instance_id::VARCHAR = sm.instance_id::VARCHAR
        LEFT JOIN local.jl_bib_format_display_csv AS jlbfd ON SUBSTRING (sm.content,7,2) = jlbfd.bib_format
        LEFT JOIN inventory_items AS invitems ON circs.item_id = invitems.id
WHERE sm.field = '000'
ORDER BY invitems.effective_shelving_order COLLATE "C", whole_call_number
;
