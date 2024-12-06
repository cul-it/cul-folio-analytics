--MCR103
--Annex_items_with_nonCirculating_loan_types
--This query finds items at the Annex that have a "non-circulating" permanent loan type, excluding rare and special collections. It also finds items with an hourly loan type.

--Query writer: Joanne Leary (jl41)
--Date posted: 12/6/24

WITH parameters AS

-- Enter a start date and end date to select just the records that have been newly added

(SELECT 
'2024-07-01'::date AS start_date,
'2024-12-04'::date AS end_date 
) 

SELECT 
        to_char(current_date::DATE,'mm/dd/yyyy') AS todays_date,
        ll.library_name,
        he.permanent_location_name as holdings_permanent_location_name,
        iext.temporary_location_name as item_temporary_location_name,
        instext.instance_hrid,
        he.holdings_hrid,
        ihi.item_hrid,
        ihi.barcode AS item_barcode,
        iext.permanent_loan_type_name,
        iext.temporary_loan_type_name,
        iext.material_type_name AS material_type,
        he.type_name AS holdings_type,
        ihi.index_title,
        ihi.call_number as item_effective_call_number,
        ihi.enumeration,
        ihi.chronology,
        ihi.item_copy_number,
        instext.discovery_suppress as instance_suppress,
        he.discovery_suppress AS holdings_suppress,
        iext.status_name,
        to_char(iext.status_date::DATE,'mm/dd/yyyy') AS item_status_date,
        iext.updated_date::date,
        jsonb_extract_path_text (uu.jsonb,'personal','lastName') as personal__last_name

FROM folio_derived.instance_ext AS instext 
        LEFT JOIN folio_derived.holdings_ext AS he 
        ON instext.instance_id::UUID = he.instance_id::UUID

        LEFT JOIN folio_derived.items_holdings_instances AS ihi
        ON he.holdings_id::UUID = ihi.holdings_id::UUID

        LEFT JOIN folio_derived.item_ext AS iext
        ON ihi.item_hrid = iext.item_hrid
        
        LEFT JOIN folio_derived.locations_libraries AS ll 
        ON he.permanent_location_id::UUID = ll.location_id::UUID
        
        LEFT JOIN folio_users.users as uu --user_users AS uu 
        ON iext.updated_by_user_id::UUID = uu.id::UUID

WHERE 
        
        ll.library_name = 'Library Annex'
        AND (iext.permanent_loan_type_name like 'Non%' or iext.temporary_loan_type_name notnull)
        AND (he.permanent_location_name not like '%Rar%'
        AND he.permanent_location_name not like '%RMC%'
        AND he.permanent_location_name not like '%Kheel%'
        AND he.permanent_location_name not like 'Mann Special%')
        AND jsonb_extract_path_text (uu.jsonb,'personal','lastName') = 'app_caiasoft'
        AND iext.updated_date::date >= (SELECT start_date FROM parameters) 
        AND iext.updated_date::date < (SELECT end_date FROM parameters)
        
ORDER BY holdings_permanent_location_name, instance_hrid, holdings_hrid, item_hrid
;
