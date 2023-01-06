--AHR114 microforms_counts_details
-- This query gets all microform records in a given library. Microform records are identified by looking in three places: the 007 field, call number, and title. 
-- The extracted elements sometimes show contradictory information for microform type; the query does not attempt to reconcile the differences.
-- This is a holdings-level query that counts item records attached to each holdings record. Note that many microforms do not have item records, so the item counts may show zero.

WITH parameters AS 

(SELECT 
''::VARCHAR as owning_library -- enter a library name, such as "Olin Library", "Library Annex", "Mann Library" etc. May be left blank for all libraries.
),

-- 1. Get OCLCs and ISBNs ad normalize them

isbns AS 
(SELECT 
        iid.instance_id,
        STRING_AGG (DISTINCT SUBSTRING (iid.identifier, '^\d{8,13}[X]{0,1}'),' | ') AS normalized_isbn_number
                
        FROM folio_reporting.instance_identifiers AS iid 
        WHERE iid.identifier_type_name = 'ISBN'
        GROUP BY iid.instance_id 
),

oclcs AS 
(SELECT 
        iid.instance_id,
        STRING_AGG (DISTINCT SUBSTRING (iid.identifier, '\d{1,}'),' | ') AS normalized_oclc_number
                
        FROM folio_reporting.instance_identifiers as iid 
        WHERE iid.identifier LIKE '%(OCoLC)%'
        GROUP BY iid.instance_id
),

-- 2. Get records by the 007 field:

candidates AS 
(SELECT DISTINCT

        CASE 
                WHEN substring (sm."content",2,1) in ('b','c','d','h','j') THEN 'Microfilm'
                WHEN substring (sm."content",2,1) in ('e','f') THEN 'Microfiche'  
                WHEN substring (sm."content",2,1) = 'g' THEN 'Microopaque'
                WHEN substring (sm."content",2,1) = '|' THEN 'No attempt to code' 
                ELSE 'Other microformat' END AS microform_type,

        ii.hrid as instance_hrid,
        he.holdings_hrid,
        ie.item_hrid,
        ll.library_name,
        ll.location_name,
        ii.title,
        TRIM (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix)) AS whole_call_number,   
        STRING_AGG (DISTINCT he.type_name,' | ') AS holdings_type_name,
        STRING_AGG (DISTINCT ic.contributor_name,' | ') AS contributors,
        STRING_AGG (DISTINCT ip.publisher, ' | ') AS publisher,
        ii.publication_period__start::VARCHAR,
        ii.publication_period__end::VARCHAR,     
        STRING_AGG (DISTINCT iseries.series,' | ') AS series,
        STRING_AGG (DISTINCT hs.statement,' | ') AS holdings_statements,
        STRING_AGG (DISTINCT hss.statement,' | ') AS holdings_supplements,
        STRING_AGG (DISTINCT hsi.statement,' | ') AS "indexes",
        oclcs.normalized_oclc_number,
        isbns.normalized_isbn_number,
        he.receipt_status,
        CASE WHEN he.created_date::date >='2021-06-20' THEN he.created_date::date ELSE mm.create_date::date END AS holdings_create_date,
        instlang.language as primary_language
        
FROM inventory_instances AS ii 
        LEFT JOIN srs_marctab AS sm 
        ON ii.hrid = sm.instance_hrid
        
        LEFT JOIN folio_reporting.instance_series AS iseries
        ON ii.id = iseries.instance_id
        
        LEFT JOIN oclcs 
        on ii.id = oclcs.instance_id
        
        LEFT JOIN isbns 
        on ii.id = isbns.instance_id
        
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id
                
        LEFT JOIN folio_reporting.instance_languages AS instlang 
        ON ii.id = instlang.instance_id
                
        LEFT JOIN folio_reporting.instance_contributors AS ic 
        ON ii.id = ic.instance_id
                
        LEFT JOIN folio_reporting.instance_publication AS ip 
        ON ii.id = ip.instance_id

        LEFT JOIN folio_reporting.holdings_statements AS hs 
        ON he.holdings_id = hs.holdings_id
                
        LEFT JOIN folio_reporting.holdings_statements_supplements AS hss 
        ON he.holdings_id = hss.holdings_id
                
        LEFT JOIN folio_reporting.holdings_statements_indexes AS hsi 
        ON he.holdings_id = hsi.holdings_id
                
        LEFT JOIN vger.mfhd_master as mm 
        ON he.holdings_hrid::VARCHAR = mm.mfhd_id::VARCHAR
                
        LEFT JOIN folio_reporting.item_ext as ie 
        ON he.holdings_id = ie.holdings_record_id

WHERE 
        ((SELECT owning_library FROM parameters) = '' OR ll.library_name = (SELECT owning_library FROM parameters))
        AND sm.field = '007'
        AND substring (sm."content",1,1) = 'h'
        AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
        AND (instlang.language_ordinality = 1 or instlang.language_ordinality is null)
                
GROUP BY 
        ii.hrid,
        he.holdings_id,
        he.holdings_hrid,
        ie.item_hrid,   
        ll.library_name,
        ii.title,
        ll.location_name,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        ii.publication_period__start::VARCHAR,
        ii.publication_period__end::VARCHAR,
        oclcs.normalized_oclc_number,
        isbns.normalized_isbn_number,
        he.receipt_status,
        he.created_date,
        mm.create_date,
        instlang.language,
        SUBSTRING (sm."content",2,1)     
),

-- 3. Count item records attached to the 007 records

items AS 
(SELECT 
        candidates.microform_type,
        candidates.instance_hrid,
        candidates.holdings_hrid,
        candidates.library_name,
        candidates.location_name,
        candidates.title,
        candidates.whole_call_number,    
        candidates.holdings_type_name,
        candidates.contributors,
        candidates.publisher,
        candidates.publication_period__start::VARCHAR,
        candidates.publication_period__end::VARCHAR,
        candidates.series,
        candidates.holdings_statements,
        candidates.holdings_supplements,
        candidates."indexes",
        candidates.normalized_oclc_number,
        candidates.normalized_isbn_number,
        candidates.receipt_status,
        candidates.holdings_create_date,
        candidates.primary_language,
        '007' AS "source",
        COUNT (candidates.item_hrid) AS total_items

FROM candidates

GROUP BY 
        candidates.microform_type,
        candidates.instance_hrid,
        candidates.holdings_hrid,
        candidates.library_name,
        candidates.location_name,
        candidates.title,
        candidates.whole_call_number,    
        candidates.holdings_type_name,
        candidates.contributors,
        candidates.publisher,
        candidates.publication_period__start::VARCHAR,
        candidates.publication_period__end::VARCHAR,
        candidates.series,
        candidates.holdings_statements,
        candidates.holdings_supplements,
        candidates."indexes",
        candidates.normalized_oclc_number,
        candidates.receipt_status,
        candidates.normalized_oclc_number,
        candidates.normalized_isbn_number,
        candidates.holdings_create_date,
        candidates.primary_language
),
        
-- 4. Get records by call number or title        
        
records AS 
(SELECT DISTINCT
        CASE 
                WHEN trim (concat_ws (' ',he.call_number_prefix,he.call_number,he.call_number_suffix)) ILIKE '%film%' THEN 'Microfilm' 
                WHEN trim (concat_ws (' ',he.call_number_prefix,he.call_number,he.call_number_suffix)) ILIKE '%fiche%' THEN 'Microfiche'
                ELSE 'Other microformat' END AS microform_type,
                
        ii.hrid AS instance_hrid,--
        he.holdings_hrid,
        ie.item_hrid,
        ll.library_name,
        ll.location_name,
        ii.title,
        TRIM (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix)) AS whole_call_number,
        STRING_AGG (DISTINCT he.type_name,' | ') AS holdings_type_name,
        STRING_AGG (DISTINCT ic.contributor_name,' | ') AS contributors,
        STRING_AGG (DISTINCT ip.publisher, ' | ') AS publisher,
        ii.publication_period__start::VARCHAR,
        ii.publication_period__end::VARCHAR,     
        STRING_AGG (DISTINCT iseries.series,' | ') AS series,
        STRING_AGG (DISTINCT hs.statement,' | ') AS holdings_statements,
        STRING_AGG (DISTINCT hss.statement,' | ') AS holdings_supplements,
        STRING_AGG (DISTINCT hsi.statement,' | ') AS "indexes",
        oclcs.normalized_oclc_number,
        isbns.normalized_isbn_number,
        he.receipt_status,
        CASE WHEN he.created_date::DATE >'2021-06-19' THEN he.created_date::DATE ELSE mm.create_date::DATE END AS holdings_create_date,
        ie.created_date::DATE AS item_create_date,
        instlang.language AS primary_language,
        CASE WHEN ie.created_date::DATE IS NULL THEN he.created_date::DATE ELSE ie.created_date::DATE END AS record_create_date
        
        FROM inventory_instances AS ii 
                LEFT JOIN folio_reporting.instance_series AS iseries 
                ON ii.id = iseries.instance_id
                
                LEFT JOIN folio_reporting.instance_languages AS instlang 
                ON ii.id = instlang.instance_id
                
                LEFT JOIN folio_reporting.instance_contributors AS ic 
                ON ii.id = ic.instance_id
                
                LEFT JOIN folio_reporting.instance_publication AS ip 
                ON ii.id = ip.instance_id
                
                LEFT JOIN oclcs 
                ON ii.id = oclcs.instance_id
        
                LEFT JOIN isbns 
                ON ii.id = isbns.instance_id
                
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id
                
                LEFT JOIN folio_reporting.holdings_statements AS hs 
                ON he.holdings_id = hs.holdings_id
                
                LEFT JOIN folio_reporting.holdings_statements_supplements AS hss 
                ON he.holdings_id = hss.holdings_id
                
                LEFT JOIN folio_reporting.holdings_statements_indexes AS hsi 
                ON he.holdings_id = hsi.holdings_id
                
                LEFT JOIN vger.mfhd_master AS mm 
                ON he.holdings_hrid::VARCHAR = mm.mfhd_id::VARCHAR
                
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON he.permanent_location_id = ll.location_id
                
                LEFT JOIN folio_reporting.item_ext AS ie 
                ON he.holdings_id = ie.holdings_record_id
        
WHERE ((SELECT owning_library FROM parameters) = '' OR ll.library_name = (SELECT owning_library FROM parameters))
        AND ((trim (concat_ws (' ',he.call_number_prefix,he.call_number,he.call_number_suffix)) SIMILAR TO '%(fiche|film|Fiche|Film|Micro|micro)%') OR (ii.title ILIKE '%[microform]%'))
        AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL) 
        AND (ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL)
        AND (instlang.language_ordinality = 1 OR instlang.language_ordinality IS NULL)

GROUP BY 
        
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,   
        ii.hrid,
        he.holdings_hrid,
        ie.item_hrid,
        ll.library_name,
        ll.location_name,
        ii.title,
        ii.publication_period__start::VARCHAR,
        ii.publication_period__end::VARCHAR,
        he.created_date::DATE,
        mm.create_date::DATE,
        ie.created_date::DATE,
        instlang.language,
        he.receipt_status,
        oclcs.normalized_oclc_number,
        isbns.normalized_isbn_number
),

-- 5. Get the count of item records attached to the call number/title records

callnum AS 
(SELECT
        records.microform_type,
        records.instance_hrid,
        records.holdings_hrid,
        records.library_name,
        records.location_name,
        records.title,
        records.whole_call_number,
        records.holdings_type_name,
        records.contributors,
        records.publisher,
        records.publication_period__start::VARCHAR,
        records.publication_period__end::VARCHAR,
        records.series,
        records.holdings_statements,
        records.holdings_supplements,
        records."indexes",
        records.normalized_oclc_number,
        records.normalized_isbn_number,
        records.receipt_status,
        records.holdings_create_date::DATE,
        records.primary_language,
        'call_number_or_title' AS "source",
        COUNT (records.item_hrid) AS total_items 

FROM records 

GROUP BY 
        records.holdings_create_date::DATE,
        records.microform_type,
        records.instance_hrid,
        records.holdings_hrid,
        records.library_name,
        records.location_name,
        records.title,
        records.whole_call_number,
        records.receipt_status,
        records.contributors,
        records.publisher,
        records.publication_period__start::VARCHAR,
        records.publication_period__end::VARCHAR,
        records.series,
        records.holdings_type_name,
        records.holdings_statements,
        records.holdings_supplements,
        records."indexes",
        records.normalized_oclc_number,
        records.normalized_isbn_number,
        records.primary_language,
        "source"

ORDER BY records.whole_call_number
),

-- 6. Combine the 007 set and the call Number/title set

final AS 
(SELECT distinct
        items.*
        FROM items
        
        UNION 
        
        SELECT
        callnum.*
        FROM callnum
),

-- 7. From the combined set, get distinct values

final2 AS 
(SELECT
        TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
        final.holdings_create_date::DATE,
        STRING_AGG (DISTINCT final.microform_type,' | ') AS microform_type,
        final.instance_hrid,
        final.holdings_hrid,
        final.library_name,
        final.location_name,
        final.title,
        final.whole_call_number,
        final.receipt_status,
        final.contributors,
        final.publisher,
        final.publication_period__start::VARCHAR,
        final.publication_period__end::VARCHAR,
        final.series,
        final.holdings_type_name,
        final.holdings_statements,
        final.holdings_supplements,
        final."indexes",
        final.normalized_oclc_number,
        final.normalized_isbn_number,
        final.primary_language,
        STRING_AGG (DISTINCT final.source,' | ') AS sources,
        STRING_AGG (DISTINCT final.total_items::VARCHAR,' | ')::INTEGER AS total_items
        
FROM final 

GROUP BY 
        TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy'),
        final.holdings_create_date::DATE,
        final.instance_hrid,
        final.holdings_hrid,
        final.library_name,
        final.location_name,
        final.title,
        final.whole_call_number,
        final.receipt_status,
        final.contributors,
        final.publisher,
        final.publication_period__start::VARCHAR,
        final.publication_period__end::VARCHAR,
        final.series,
        final.holdings_type_name,
        final.holdings_statements,
        final.holdings_supplements,
        final."indexes",
        final.normalized_oclc_number,
        final.normalized_isbn_number,
        final.primary_language
),

-- 8. Get the 007 field (to show the coding), the 086 field for the SuDoc number, the 300 and 533$e fields to show the number of pieces (reels or fiche count)

"007f" AS 
(SELECT 
        final2.instance_hrid,
        STRING_AGG (DISTINCT sm.content,' -- ' ) AS "007"
        
        FROM final2 
        LEFT JOIN srs_marctab as sm 
        ON final2.instance_hrid = sm.instance_hrid
                
        WHERE sm.field = '007'
        
        GROUP BY final2.instance_hrid
),

"086f" AS 
(SELECT 
        final2.instance_hrid,
        STRING_AGG (DISTINCT sm.content,' | ' ) AS "086"
        
        FROM final2 
        LEFT JOIN srs_marctab AS sm 
        ON final2.instance_hrid = sm.instance_hrid
                
        WHERE sm.field = '086'
        
        GROUP BY final2.instance_hrid
),

"300f" AS 
(SELECT 
        final2.instance_hrid,
        STRING_AGG (DISTINCT sm.content,' | ' ) AS "300"
        
        FROM final2 
        LEFT JOIN srs_marctab as sm 
        ON final2.instance_hrid = sm.instance_hrid
                
        WHERE sm.field = '300'
        
        GROUP BY final2.instance_hrid
),

"533f" AS 
(SELECT 
        final2.instance_hrid,
        STRING_AGG (DISTINCT sm.content,' | ') AS "533e"
        
        FROM final2
        LEFT JOIN srs_marctab AS sm 
        ON final2.instance_hrid = sm.instance_hrid 
        
        WHERE sm.field = '533'
        AND sm.sf = 'e'
        
        GROUP BY final2.instance_hrid
)

-- 9. Combine previous results and get bound-with indicators and parent barcode, the emulsion type, and other holdings locations

SELECT DISTINCT
        final2.todays_date,
        final2.holdings_create_date::DATE,
        STRING_AGG (DISTINCT final2.microform_type,' | ') AS microform_type,
        final2.instance_hrid,
        final2.holdings_hrid,
        final2.library_name,
        final2.location_name,
        final2.title,
        final2.whole_call_number,
        final2.receipt_status,
        final2.contributors,
        final2.publisher,
        final2.publication_period__start::VARCHAR,
        final2.publication_period__end::VARCHAR,
        final2.series,
        final2.holdings_type_name,
        final2.holdings_statements,
        final2.holdings_supplements,
        STRING_AGG (DISTINCT inotes.note,' | ') AS instance_note,
        STRING_AGG (distinct hn.note,' | ') AS holdings_note,
        SUBSTRING (STRING_AGG (DISTINCT hn.note,' | '),'31924\d{9}') AS parent_barcode,
        CASE WHEN STRING_AGG (DISTINCT hn.note_type_name,' | ') LIKE '%Bound with%' THEN 'Bound with' ELSE '-' END AS bound_with,
        final2."indexes",
        final2.normalized_oclc_number,
        final2.normalized_isbn_number,
        final2.primary_language,
        final2.sources,
        final2.total_items,
        "007f"."007",
        "086f"."086",
        "300f"."300",
        "533f"."533e",
        
        CASE 
                WHEN SUBSTRING ("007f"."007",11,1) = 'a' THEN 'Silver halide'
                WHEN SUBSTRING ("007f"."007",11,1) = 'b' THEN 'Diazo'
                WHEN SUBSTRING ("007f"."007",11,1) = 'c' THEN 'Vesicular'
                WHEN SUBSTRING ("007f"."007",11,1) = 'n' THEN 'Not applicable'
                WHEN SUBSTRING ("007f"."007",11,1) = 'u' THEN 'Unknown'
                WHEN SUBSTRING ("007f"."007",11,1) = 'm' THEN 'Mixed emulsion'
                WHEN SUBSTRING ("007f"."007",11,1) = 'z' THEN 'Other'
                WHEN SUBSTRING ("007f"."007",11,1) = '|' THEN 'No attempt to code'
                ELSE ' - ' END AS emulsion_type,
                
        STRING_AGG (DISTINCT ll.location_name, ' | ') AS all_holdings_locations

FROM final2     
        LEFT JOIN "007f"
        ON "007f".instance_hrid = final2.instance_hrid
        
        LEFT JOIN "086f" 
        ON "086f".instance_hrid = final2.instance_hrid 
        
        LEFT JOIN "300f" 
        ON "300f".instance_hrid = final2.instance_hrid
        
        LEFT JOIN "533f" 
        ON "533f".instance_hrid = final2.instance_hrid
        
        LEFT JOIN folio_reporting.instance_notes AS inotes 
        ON final2.instance_hrid = inotes.instance_hrid
        
        LEFT JOIN folio_reporting.holdings_notes AS hn 
        ON final2.holdings_hrid = hn.holdings_hrid
        
        LEFT JOIN inventory_instances AS ii 
        ON final2.instance_hrid = ii.hrid
        
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id

GROUP BY 
        final2.instance_hrid,
        final2.holdings_hrid,
        final2.whole_call_number,
        final2.library_name,
        final2.location_name,
        final2.title,
        final2.todays_date,
        final2.holdings_create_date::DATE,
        final2.receipt_status,
        final2.contributors,
        final2.publisher,
        final2.publication_period__start::VARCHAR,
        final2.publication_period__end::VARCHAR,
        final2.series,
        final2.holdings_type_name,
        final2.holdings_statements,
        final2.holdings_supplements,
        final2."indexes",
        final2.normalized_oclc_number,
        final2.normalized_isbn_number,
        final2.primary_language,
        final2.sources,
        final2.total_items,
        "007f"."007",
        "086f"."086",
        "300f"."300",
        "533f"."533e"
        
ORDER BY final2.library_name, final2.location_name, final2.whole_call_number, final2.instance_hrid, final2.holdings_hrid  
;
