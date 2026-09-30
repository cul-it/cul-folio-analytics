-- 6-4-26: requests_items derived table re-write (based on re-write of 1-12-26) with updates
-- used "item__t" table in place of many of the original item jsonb extracts
-- used full table names when possible; used aliases when using multiple copies of the location and loan type tables needed for linking to different values in the item record
-- cast date values as "timestamptz"
-- renamed "hrid" as "item_hrid"; moved to just after item_id
-- added "effective_call_number_prefix", "effective call number" and "effective_call_number_suffix" from item table (item level call number is usually blank, and call number prefixes and suffixes are often important)
-- moved "enumeration" to right before "chronology" field

SELECT
    request__t.id AS request_id,
    request__t.item_id,
    item__t.hrid as item_hrid,
    request__t.request_date::timestamptz as request_date, -- changed to timestamptz
    request__t.request_type,
    request__t.status AS request_status,
    request__t.pickup_service_point_id,
    psp.name AS pickup_service_point_name,
    psp.discovery_display_name AS pickup_service_point_disc_disp_name,
    item__t.in_transit_destination_service_point_id as in_transit_dest_serv_point_id,
    --jsonb_extract_path_text(item.jsonb, 'inTransitDestinationServicePointId')::uuid AS in_transit_dest_serv_point_id,
    service_point__t.name AS in_transit_dest_serv_point_name,
    service_point__t.discovery_display_name AS in_transit_dest_serv_point_disc_disp_name,
    request__t.requester_id,
    request__t.fulfillment_preference,
    --jsonb_extract_path_text(request.jsonb, 'fulfilmentPreference') AS fulfillment_preference,
    users__t.patron_group AS patron_group_id,
    groups__t.desc AS patron_group_name,
    ipl.name AS item_permanent_location_name,
    itl.name AS item_temporary_location_name,
    iel.name AS item_effective_location_name,
    item.jsonb#>>'{effectiveCallNumberComponents,prefix}' as item_effective_call_number_prefix,
    item.jsonb#>>'{effectiveCallNumberComponents,callNumber}' as item_effective_call_number,
    item.jsonb#>>'{effectiveCallNumberComponents,sufffix}' as item_effective_call_number_suffix,
    item__t.barcode,
    item__t.enumeration,
    item__t.chronology,
    --jsonb_extract_path_text(item.jsonb, 'chronology') AS chronology,
    item__t.copy_number AS item_copy_number,
    --jsonb_extract_path_text(item.jsonb, 'copyNumber') AS item_copy_number,
    item__t.permanent_location_id AS item_permanent_location_id,
    item__t.temporary_location_id AS item_temporary_location_id,
    item__t.effective_location_id AS item_effective_location_id,
    --jsonb_extract_path_text(item.jsonb, 'temporaryLocationId')::uuid AS item_temporary_location_id,
    item__t.item_level_call_number,    
    item__t.holdings_record_id,
    item__t.item_identifier,
    --jsonb_extract_path_text(item.jsonb, 'itemIdentifier') AS item_identifier,
    item__t.material_type_id,
    imt.name AS material_type_name,
    --item__t.number_of_pieces,
    item__t.number_of_pieces,
    --jsonb_extract_path_text(item.jsonb, 'numberOfPieces') AS number_of_pieces,
    item__t.permanent_loan_type_id as item_permanent_loan_type_id,
    iplt.name AS item_permanent_loan_type_name,
    --item__t.temporary_loan_type_id AS item_temporary_loan_type_id,
    item__t.temporary_loan_type_id as item_temporary_loan_type_id,
    --jsonb_extract_path_text(item.jsonb, 'temporaryLoanTypeId')::uuid AS item_temporary_loan_type_id,
    itlt.name AS item_temporary_loan_type_name
FROM
    folio_circulation.request__t
    LEFT JOIN folio_circulation.request ON request__t.id = request.id
    LEFT JOIN folio_inventory.item__t ON request__t.item_id = item__t.id
    LEFT JOIN folio_inventory.item ON item__t.id = item.id
    --LEFT JOIN folio_inventory.service_point__t AS isp ON item__t.in_transit_destination_service_point_id = service_point__t.id
    --LEFT JOIN folio_inventory.service_point__t ON jsonb_extract_path_text(item.jsonb, 'inTransitDestinationServicePointId')::uuid = service_point__t.id
    left join folio_inventory.service_point__t on item__t.in_transit_destination_service_point_id = service_point__t.id
    LEFT JOIN folio_inventory.service_point__t AS psp ON request__t.pickup_service_point_id = psp.id
    LEFT JOIN folio_users.users__t ON request__t.requester_id = users__t.id
    LEFT JOIN folio_users.groups__t ON users__t.patron_group = groups__t.id
    LEFT JOIN folio_inventory.location__t AS iel ON item__t.effective_location_id = iel.id
    LEFT JOIN folio_inventory.location__t AS ipl ON item__t.permanent_location_id = ipl.id
    LEFT JOIN folio_inventory.location__t AS itl ON item__t.temporary_location_id = itl.id--jsonb_extract_path_text(item.jsonb, 'temporaryLocationId')::uuid = itl.id
    LEFT JOIN folio_inventory.loan_type__t AS iplt ON item__t.permanent_loan_type_id = iplt.id
    LEFT JOIN folio_inventory.loan_type__t AS itlt ON item__t.temporary_loan_type_id = itlt.id --jsonb_extract_path_text(item.jsonb, 'temporaryLoanTypeId')::uuid = itlt.id
    LEFT JOIN folio_inventory.material_type__t AS imt ON item__t.material_type_id = imt.id
;

