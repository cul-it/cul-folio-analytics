--MCR199 - serials_by_owning_library_with_title_holdings_at_annex

--This query gets serials by owning library and LC class, and shows Annex holdings for those titles. 
--To select only titles that have no holdings at the Annex, un-comment out the WHERE statement at the end (line 178), or export full results to Excel and filter the Annex holdings column to = NULL.
--Query writer: Joanne Leary (jl41)
--Date posted: 11/6/24                             


WITH parameters AS 
(SELECT 
'Mann Library'::VARCHAR AS library_name_filter,
'SB'::VARCHAR AS lc_class_filter -- enter an LC class (A, TK, PN, etc.) or leave blank 
),

marc_formats AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             substring(marc__t."content", 7, 2) AS leader0607
       FROM folio_source_record.marc__t 
       WHERE marc__t.field = '000'
),

owning_library_recs AS 
(SELECT 
        ii.id AS instance_id,
        ii.hrid AS instance_hrid,
        ii.title,
        ll.library_name,
        he.permanent_location_name,
        he.type_name AS holdings_type_name,
        mf.leader0607 AS bib_format,
        he.holdings_id,
        he.holdings_hrid,
        he.call_number,
        he.receipt_status,
        TRIM (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix)) AS whole_call_number,
        SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') AS lc_class,
        CASE WHEN substring (he.call_number,2,1) = ' ' THEN 0 ELSE substring (he.call_number,'\d{1,}\.{0,}\d{0,}')::numeric END AS lc_class_number,
        CONCAT (ll.location_name,': ',CASE WHEN hs.holdings_statement IS NULL THEN 'No holdings statement' ELSE STRING_AGG (DISTINCT hs.holdings_statement,' | ') END) AS owning_library_holdings,
        CONCAT ('https://newcatalog.library.cornell.edu/catalog/',ii.hrid) AS catalog_url

FROM folio_inventory.instance__t AS ii 
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN folio_derived.holdings_statements AS hs 
        ON he.holdings_id = hs.holdings_id
        
        LEFT JOIN folio_derived.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id 
        
        LEFT JOIN marc_formats AS mf 
        ON ii.id = mf.instance_id       

WHERE
        ((SELECT lc_class_filter FROM parameters) = '' OR SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') = (SELECT lc_class_filter FROM parameters))
        AND ll.library_name = (SELECT library_name_filter FROM parameters)
        AND (ii.discovery_suppress = 'false' OR ii.discovery_suppress IS NULL)
        AND (he.discovery_suppress = 'false' or he.discovery_suppress IS NULL)
        AND (he.type_name ='Serial' or mf.leader0607 like '%s')

GROUP BY 
        ii.id,
        ii.hrid,
        ii.index_title,
        ii.title,
        ll.library_name,
        he.permanent_location_name,
        he.type_name,
        mf.leader0607,
        he.holdings_id,
        he.holdings_hrid,
        he.call_number,
        he.receipt_status,
        TRIM (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix)),
        SUBSTRING (he.call_number,'^([a-zA-z]{1,3})'),
        CASE WHEN substring (he.call_number,2,1) = ' ' THEN 0 ELSE substring (he.call_number,'\d{1,}\.{0,}\d{0,}')::numeric END,
        ll.location_name,
        hs.holdings_statement,
        CONCAT ('https://newcatalog.library.cornell.edu/catalog/',ii.hrid)
),

vols AS 
(SELECT 
        owning_library_recs.instance_hrid,
        owning_library_recs.holdings_hrid,
        owning_library_recs.holdings_id,
        owning_library_recs.title,
        COUNT (DISTINCT invitems.id) AS number_of_items

FROM owning_library_recs 
        LEFT JOIN folio_inventory.item__t as invitems 
        on owning_library_recs.holdings_id = invitems.holdings_record_id 
 
GROUP BY 
        owning_library_recs.instance_hrid,
        owning_library_recs.holdings_hrid,
        owning_library_recs.holdings_id,
        owning_library_recs.title
),

notes AS 
(SELECT 
        owning_library_recs.instance_hrid,
        owning_library_recs.holdings_id,
        owning_library_recs.title,
        STRING_AGG (DISTINCT hn.note,' | ') AS holdings_notes

FROM owning_library_recs 
        LEFT JOIN folio_derived.holdings_notes AS hn 
        ON owning_library_recs.holdings_id = hn.holding_id 
 
GROUP BY
        owning_library_recs.instance_hrid,
        owning_library_recs.holdings_id,
        owning_library_recs.title
),

annex_locs AS 
(SELECT 
        owning_library_recs.instance_hrid,
        ll.library_name,
        STRING_AGG (DISTINCT he.permanent_location_name, ' | ') AS annex_locations,
        CONCAT (ll.location_name,': ',CASE WHEN hs.holdings_statement IS NULL THEN 'No holdings statement' ELSE STRING_AGG (DISTINCT hs.holdings_statement,' | ') END) AS annex_holdings
        
FROM owning_library_recs 
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON owning_library_recs.instance_id = he.instance_id 
        
        LEFT JOIN folio_derived.holdings_statements AS hs 
        ON he.holdings_id = hs.holdings_id 
        
        LEFT JOIN folio_derived.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id
        
        LEFT JOIN folio_inventory.instance__t AS ii 
        ON he.instance_id = ii.id 

   WHERE ll.library_name ='Library Annex'
        AND (he.discovery_suppress = 'false' OR he.discovery_suppress IS NULL)
        AND (ii.discovery_suppress = 'false' OR ii.discovery_suppress IS NULL)

GROUP BY 
        owning_library_recs.instance_hrid,
        ll.library_name,
        ll.location_name,
        hs.holdings_statement
)

SELECT 
        owning_library_recs.instance_hrid,
        owning_library_recs.holdings_hrid,
        owning_library_recs.title,
        vols.number_of_items,
        owning_library_recs.permanent_location_name as owning_library_location,
        REPLACE (owning_library_recs.call_number,'    ','   ') AS sortable_call_number,
        STRING_AGG (DISTINCT owning_library_recs.owning_library_holdings,' | ') AS owning_library_holdings,
        STRING_AGG (DISTINCT annex_locs.annex_holdings,' | ') AS annex_holdings,
        owning_library_recs.whole_call_number,
        owning_library_recs.holdings_type_name,
        owning_library_recs.bib_format,
        owning_library_recs.receipt_status,
        STRING_AGG (DISTINCT notes.holdings_notes,' | ') AS holdings_notes,
        owning_library_recs.catalog_url
        
FROM owning_library_recs
        LEFT JOIN vols 
        ON owning_library_recs.holdings_id = vols.holdings_id
        
        LEFT JOIN notes 
        ON owning_library_recs.holdings_id = notes.holdings_id

        LEFT JOIN annex_locs 
        ON owning_library_recs.instance_hrid = annex_locs.instance_hrid 
        
--WHERE annex_locs.annex_holdings IS NULL

GROUP BY 
 
        owning_library_recs.instance_hrid,
        owning_library_recs.holdings_hrid,
        owning_library_recs.title,
        vols.number_of_items,
        owning_library_recs.permanent_location_name,
        REPLACE (owning_library_recs.call_number,'    ','   '),
        owning_library_recs.whole_call_number,
        owning_library_recs.receipt_status,
        owning_library_recs.lc_class,
        owning_library_recs.lc_class_number,
        owning_library_recs.holdings_type_name,
        owning_library_recs.bib_format,
        owning_library_recs.catalog_url,
        owning_library_recs.call_number collate "C"

ORDER BY lc_class, lc_class_number, REPLACE (owning_library_recs.call_number,'    ','   ') COLLATE "C", holdings_hrid
;
