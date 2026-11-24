--metadb:table requests_items
--metadb:require folio_inventory.item__t.enumeration text

-- Create a derived table that contains all items from requests and adds
-- item and patron-related information
-- 6-4-26: requests_items derived table re-write (based on re-write of 1-12-26) with updates
-- used "item__t" table in place of many of the original item jsonb extracts
-- used full table names when possible; used aliases when using multiple copies of the location and loan type tables needed for linking to different values in the item record
-- cast date values as "timestamptz"
-- renamed "hrid" as "item_hrid"; moved to just after item_id
-- added "effective_call_number_prefix", "effective call number" and "effective_call_number_suffix" from item table (item level call number is usually blank, and call number prefixes and suffixes are often important)
-- moved "enumeration" to right before "chronology" field
-- 11-15-26: fixed typo in effective call number suffix JSON path ("sufffix" -> "suffix";
--     the typo made the column silently NULL for all rows);
--     removed unused join to folio_circulation.request (no longer referenced);
--     removed duplicate number_of_pieces line and stale commented-out code;
--     removed redundant ::timestamptz cast on request_date (column is already
--     timestamp with time zone in request__t)
-- 11-20-26: added owning library

DROP TABLE IF EXISTS requests_items;

CREATE TABLE requests_items AS
(SELECT
    request__t.id AS request_id,
    request__t.item_id,
    item__t.hrid AS item_hrid,
    request__t.request_date,
    request__t.request_type,
    request__t.status AS request_status,
    request__t.pickup_service_point_id,
    psp.name AS pickup_service_point_name,
    psp.discovery_display_name AS pickup_service_point_disc_disp_name,
    item__t.in_transit_destination_service_point_id AS in_transit_dest_serv_point_id,
    service_point__t.name AS in_transit_dest_serv_point_name,
    service_point__t.discovery_display_name AS in_transit_dest_serv_point_disc_disp_name,
    request__t.requester_id,
    request__t.fulfillment_preference,
    users__t.patron_group AS patron_group_id,
    groups__t.group AS patron_group_name,
    ipl.name AS item_permanent_location_name,
    itl.name AS item_temporary_location_name,
    iel.name AS item_effective_location_name,
    item.jsonb#>>'{effectiveCallNumberComponents,prefix}' AS item_effective_call_number_prefix,
    item.jsonb#>>'{effectiveCallNumberComponents,callNumber}' AS item_effective_call_number,
    item.jsonb#>>'{effectiveCallNumberComponents,suffix}' AS item_effective_call_number_suffix,
    item__t.barcode,
    item__t.enumeration,
    item__t.chronology,
    item__t.copy_number AS item_copy_number,
    item__t.permanent_location_id AS item_permanent_location_id,
    item__t.temporary_location_id AS item_temporary_location_id,
    item__t.effective_location_id AS item_effective_location_id,
    loclibrary__t.name as owning_library,
    item__t.item_level_call_number,
    item__t.holdings_record_id,
    item__t.item_identifier,
    item__t.material_type_id,
    imt.name AS material_type_name,
    item__t.number_of_pieces,
    item__t.permanent_loan_type_id AS item_permanent_loan_type_id,
    iplt.name AS item_permanent_loan_type_name,
    item__t.temporary_loan_type_id AS item_temporary_loan_type_id,
    itlt.name AS item_temporary_loan_type_name

FROM
    folio_circulation.request__t

    LEFT JOIN folio_inventory.item__t ON request__t.item_id = item__t.id
    LEFT JOIN folio_inventory.item ON item__t.id = item.id
    LEFT JOIN folio_inventory.service_point__t ON item__t.in_transit_destination_service_point_id = service_point__t.id
    LEFT JOIN folio_inventory.service_point__t AS psp ON request__t.pickup_service_point_id = psp.id
    LEFT JOIN folio_users.users__t ON request__t.requester_id = users__t.id
    LEFT JOIN folio_users.groups__t ON users__t.patron_group = groups__t.id
    LEFT JOIN folio_inventory.location__t AS iel ON item__t.effective_location_id = iel.id
    LEFT JOIN folio_inventory.loclibrary__t on iel.library_id = loclibrary__t.id
    LEFT JOIN folio_inventory.location__t AS ipl ON item__t.permanent_location_id = ipl.id
    LEFT JOIN folio_inventory.location__t AS itl ON item__t.temporary_location_id = itl.id
    LEFT JOIN folio_inventory.loan_type__t AS iplt ON item__t.permanent_loan_type_id = iplt.id
    LEFT JOIN folio_inventory.loan_type__t AS itlt ON item__t.temporary_loan_type_id = itlt.id
    LEFT JOIN folio_inventory.material_type__t AS imt ON item__t.material_type_id = imt.id
)
;
