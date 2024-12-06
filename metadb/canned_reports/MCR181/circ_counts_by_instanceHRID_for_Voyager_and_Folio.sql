-- MCR181
-- circ counts by instance HRID for Voyager and Folio
--This report returns circ counts from both Voyager and Folio for an individual instance HRID, as selected in the parameters. Title, location, and number of items are also included.  

-- Query writer: Joanne Leary (jl41)
-- Date posted: 12/6/24

WITH parameters AS 
(SELECT 
'371102'::varchar as instance_hrid_filter
),

items AS 
(
SELECT 
        ii.title,
        ii.hrid as instance_hrid,
        he.holdings_hrid,
        invitems.hrid as item_hrid,
        he.permanent_location_name,
        TRIM (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix, 
                CASE WHEN he.copy_number >'1' THEN concat ('c.',he.copy_number) ELSE '' END)) AS whole_call_number,
        COUNT (li.loan_id) AS folio_circs,
        item.historical_charges::integer AS voyager_circs

FROM folio_inventory.instance__t as ii --inventory_instances ii 
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON ii.id = he.instance_id::UUID 
        
        LEFT JOIN folio_inventory.item__t as invitems -- inventory_items AS invitems 
        ON he.holdings_id::UUID = invitems.holdings_record_id 
        
        LEFT JOIN vger.item 
        ON invitems.hrid::varchar = item.item_id::varchar
        
        LEFT JOIN folio_derived.loans_items AS li 
        ON invitems.id = li.item_id::UUID

WHERE ii.hrid = (SELECT instance_hrid_filter FROM parameters)

GROUP BY 
        ii.title,
        ii.hrid,
        he.holdings_hrid,
        invitems.hrid,
        he.permanent_location_name,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix, 
        he.copy_number,
        item.historical_charges::integer
)

SELECT 
        items.title,
        items.instance_hrid,
        items.holdings_hrid,
        items.permanent_location_name,
        items.whole_call_number,
        COUNT (items.item_hrid) AS number_of_items,
        SUM (items.folio_circs) + SUM (items.voyager_circs) AS total_circs

FROM items 

GROUP BY 
        items.title,
        items.instance_hrid,
        items.holdings_hrid,
        items.permanent_location_name,
        items.whole_call_number
;
