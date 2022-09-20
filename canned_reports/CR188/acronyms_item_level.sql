WITH acronyms AS 
(SELECT distinct
        ii.hrid as instance_hrid,
        ii.id as instance_id,
        he.holdings_hrid,
        invitems.hrid AS item_hrid,
        invitems.barcode,
        ii.title,
        he.permanent_location_name,
        he.call_number,
        TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, invitems.enumeration, invitems.chronology,
                CASE WHEN invitems.copy_number >'1' THEN concat ('c.', invitems.copy_number) ELSE '' END)) AS whole_call_number,
        invitems.effective_shelving_order

FROM inventory_instances AS ii 
        LEFT JOIN srs_marctab AS sm 
        ON ii.hrid = sm.instance_hrid
        
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id
        
        LEFT JOIN inventory_items AS invitems 
        ON he.holdings_id = invitems.holdings_record_id

WHERE 
        sm.field in ('245','246')
        AND sm.content SIMILAR TO '%(DETC|ICNMM|ESDA|DEC|CONE|PVP|WTC|DSCC|MNHMT|ICES|ICONE|IMECHE|ASME)%'
        AND he.permanent_location_name = 'Uris'
        AND SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') LIKE 'T%'
        ),

numvols AS 
        (SELECT 
                acronyms.holdings_hrid,
                COUNT (acronyms.item_hrid) AS number_of_volumes
        
        FROM acronyms
        GROUP BY acronyms.holdings_hrid
),

annex as 
        (SELECT
                acronyms.instance_hrid,
                string_agg (he.permanent_location_name,' | ') as annex_locations,
                string_agg (distinct hs.statement,' | ') as annex_holdings
        
        from acronyms 
                left join folio_reporting.holdings_ext as he 
                on acronyms.instance_id = he.instance_id
                
                left join folio_reporting.holdings_statements as hs 
                on he.holdings_id = hs.holdings_id
                
        where he.permanent_location_name like '%Annex%'
        
        group by acronyms.instance_hrid
)

SELECT 
        acronyms.permanent_location_name,
        acronyms.title,
        acronyms.instance_hrid,
        acronyms.holdings_hrid,
        acronyms.item_hrid,
        acronyms.barcode,
        acronyms.call_number,
        acronyms.whole_call_number,
        numvols.number_of_volumes,
        annex.annex_locations,
        annex.annex_holdings,
        acronyms.effective_shelving_order 
        
FROM acronyms 
        LEFT JOIN numvols 
        ON acronyms.holdings_hrid = numvols.holdings_hrid
        
        left join annex 
        on acronyms.instance_hrid = annex.instance_hrid

ORDER BY acronyms.effective_shelving_order COLLATE "C"
;

