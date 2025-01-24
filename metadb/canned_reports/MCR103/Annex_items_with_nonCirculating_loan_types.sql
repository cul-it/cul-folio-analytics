--MCR103
--Annex_items_with_nonCirculating_loan_types
--This query finds items at the Annex that have a "non-circulating" permanent loan type, excluding rare and special collections. 
--It also finds items with an hourly loan type. 
--Note: the library associated with the item_effective_location is the owning library.

--Query writer: Joanne Leary (jl41), revised to Metadb by Joanne Leary
--last updated: 1/24/25

-- 5-16-24: Annex items that are non-circulating because of location or loan type (excludes special collections).
-- For record cleanup. Sightly revised from CR-103.
-- 6-13-24: added start and end date; added "app_caiasoft" as updated-by user
-- 11-11-24: converted ID's to UUID where needed
-- 1-23-25: updated query to use primary tables only; added item_effective_location_name and linked library name to that location (changed from link to holdings perm loc) 

WITH parameters AS
-- Enter a start date and end date to select just the records that have been newly added

(SELECT
'2024-11-01'::date AS start_date,
'2024-12-31'::date AS end_date
)

SELECT
        to_char(current_date::DATE,'mm/dd/yyyy') AS todays_date,
        loclibrary__t.name as library_name,
        loc1.name as item_effective_location_name,  
--added this field for the metadb re-write and changed 
--the library join to link to this location rather than holdings perm location
        loc2.name as holdings_permanent_location_name,
        loc3.name as item_temporary_location_name,
        instance__t.hrid as instance_hrid,
        holdings_record__t.hrid as holdings_hrid,
        item__t.hrid as item_hrid,
        item__t.barcode as item_barcode,
        loan_type__t.name as permanent_loan_type_name,
        loan_type2.name as temporary_loan_type_name,
        material_type__t.name as material_type_name,
        holdings_type__t.name as holdings_type_name,
        instance__t.index_title,
        trim (concat (item.jsonb #>> '{effectiveCallNumberComponents,prefix}',' ',
                item.jsonb #>> '{effectiveCallNumberComponents,callNumber}',' ',
                item.jsonb #>> '{effectiveCallNumberComponents,suffix}',' ',
                item__t.enumeration,' ',
                item__t.chronology,
                case when item__t.copy_number >'1' then concat (' c.',item__t.copy_number) else '' end)) as whole_call_number,

        instance__t.discovery_suppress as instance_suppress,
        holdings_record__t.discovery_suppress :: boolean as holdings_suppress,
        item.jsonb #>> '{status,name}' as item_status_name,
        (item.jsonb #>> '{status,date}')::date as item_status_date,
        (item.jsonb #>> '{metadata,updatedDate}')::date as updated_date,
        users.jsonb #>> '{personal,lastName}' as updated_by_name

FROM folio_inventory.instance__t 
        left join folio_inventory.holdings_record__t 
        on instance__t.id = holdings_record__t.instance_id
        left join folio_inventory.holdings_type__t
        on holdings_record__t.holdings_type_id = holdings_type__t.id
        left join folio_inventory.item__t
        on holdings_record__t.id = item__t.holdings_record_id
        left join folio_inventory.item
        on item__t.id = item.id
        left join folio_inventory.location__t as loc1 --- this is for the item effective_location      
        on (item.jsonb #>> '{effectiveLocationId}')::UUID = loc1.id
        left join folio_inventory.location__t as loc2 --- this is for the holdings permanent location
        on holdings_record__t.permanent_location_id = loc2.id
        left join folio_inventory.location__t as loc3 --- this is for the item_temporary_location
        on (item.jsonb #>> '{temporaryLocationId}')::UUID = loc3.id              
        left join folio_inventory.loclibrary__t --- this gets the library name for the item effective location
        on loc1.library_id = loclibrary__t.id
        left join folio_inventory.loan_type__t --- this gets the item permanent_loan_type
        on (item.jsonb #>> '{permanentLoanTypeId}')::UUID = loan_type__t.id
        left join folio_inventory.loan_type__t as loan_type2 ---- this gets the item temporary loan type
        on (item.jsonb #>> '{temporarytLoanTypeId}')::UUID = loan_type2.id
       left join folio_inventory.material_type__t
       on (item.jsonb #>> '{materialTypeId}')::UUID = material_type__t.id  ---- this gets the item material type

LEFT JOIN folio_users.users 
        on (item.jsonb #>> '{metadata, updatedByUserId}')::UUID = users.id
WHERE
        loclibrary__t.name = 'Library Annex'
        AND (loan_type__t.name like 'Non%' or loan_type2.name notnull)
        AND loc2.name not like '%Rar%'
        AND loc2.name not like '%RMC%'
        AND loc2.name not like '%Kheel%'
        AND loc2.name not like 'Mann Special%'
        AND users.jsonb #>> '{personal,lastName}' = 'app_caiasoft'
        AND (item.jsonb #>> '{metadata,updatedDate}')::date >= (select start_date from parameters) 
        AND (item.jsonb #>> '{metadata,updatedDate}')::date < (select end_date from parameters)

ORDER BY holdings_permanent_location_name, instance_hrid, holdings_hrid, item_hrid
;

