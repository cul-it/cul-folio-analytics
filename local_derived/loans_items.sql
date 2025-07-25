--metadb:table loans_items

-- as of 4-1-25, this query does not use the locations_libraries derived table, but uses only partition source tables

-- Create a derived table that contains all items from loans and adds
-- item, location, and other loan-related information
--
-- Tables included:
--     circulation_loans
--     inventory_items
--     inventory_material_types
--     circulation_loan_policies
--     user_groups
--     inventory_locations
--     inventory_service_points
--     inventory_loan_types
--     feesfines_overdue_fines_policies
--     feesfines_lost_item_fees_policies
--		loccampus__t
--		locinstitution__t
-- 		loclibrary__t
--
-- Location names are from the items table.  They show location of the
-- item right now vs. when item was checked out.
-- 4-1-25: updated query to capture the correct service point name field from the service_point__t table;
	-- added the effective location library name (new field) because the permanent location field in the item record is often null; 
	-- cast "hrid" as "item_hrid" to clarify what it is
	-- eliminated the locations_libraries derived table by linking to the source tables (loclibrary__t, loccampus__t and locinstitution__t)
	-- added item effective call number because item level call number is usually null
	-- added call number prefix and suffix; resequenced all call number components, enumeration, chronology and copy number to group together after item effective call number
	-- rewrote jsonb_extract_path_text statements in format "table.jsonb#>> '{field components}'"

DROP TABLE IF EXISTS local_derived.loans_items;

CREATE TABLE local_derived.loans_items AS
SELECT
    loan__t.id AS loan_id,
    loan__t.item_id::uuid,
    loan__t.item_status,
    loan.jsonb#>> '{status,name}' AS loan_status,
    loan__t.loan_date::timestamptz,
    loan__t.due_date::timestamptz AS loan_due_date,
    (loan.jsonb#>> '{returnDate}')::timestamptz AS loan_return_date,
    (loan.jsonb#>> '{systemReturnDate}')::timestamptz AS system_return_date,
    (loan.jsonb#>> '{checkinServicePointId}')::uuid AS checkin_service_point_id,
    ispi.name as checkin_service_point_name,
    (loan.jsonb#>> '{checkoutServicePointId}')::uuid AS checkout_service_point_id,
    ispo.name as checkout_service_point_name,
    (loan.jsonb#>> '{itemEffectiveLocationIdAtCheckOut}')::uuid AS item_effective_location_id_at_check_out,
    loc1.name AS item_effective_location_name_at_check_out, 
    (item.jsonb#>> '{inTransitDestinationServicePointId}')::uuid AS in_transit_destination_service_point_id,
    ispt.name as in_transit_destination_service_point_name,
    item__t.effective_location_id::uuid AS current_item_effective_location_id,
    loc2.name AS current_item_effective_location_name,  
    loclibrary__t2.name as current_item_effective_library_name, -- added this because there are a lot of records with null item permanent locations
    (item.jsonb#>> '{temporaryLocationId}')::uuid AS current_item_temporary_location_id,
    loc3.name AS current_item_temporary_location_name, 
    (item.jsonb#>> '{permanentLocationId}')::uuid AS current_item_permanent_location_id,
    loc4.name AS current_item_permanent_location_name, 
    location__t.library_id as current_item_permanent_location_library_id,,
    loclibrary__t.name as current_item_permanent_location_library_name,
    location__t.campus_id AS current_item_permanent_location_campus_id,
    loccampus__t.name as current_item_permanent_location_campus_name,
    locinstitution__t.id as current_item_permanent_location_institution_id,
    locinstitution__t.name as current_item_permenent_location_institution_name,
    (loan.jsonb#>> '{loanPolicyId}')::uuid AS loan_policy_id,
    loan_policy__t.name AS loan_policy_name,
    (loan.jsonb#>> '{lostItemPolicyId}')::uuid AS lost_item_policy_id,
    lost_item_fee_policy__t.name AS lost_item_policy_name,
    (loan.jsonb#>> '{overdueFinePolicyId}')::uuid AS overdue_fine_policy_id,
    overdue_fine_policy__t.name AS overdue_fine_policy_name,
    (loan.jsonb#>> '{patronGroupIdAtCheckout}')::uuid AS patron_group_id_at_checkout,
    groups__t.group AS patron_group_name,
    (loan.jsonb#>> '{userId}')::uuid AS user_id,
    (loan.jsonb#>> '{proxyUserId}')::uuid AS proxy_user_id,
    item__t.barcode,
    item__t.holdings_record_id::uuid,
    item__t.hrid as item_hrid, -- added "as item_hrid" to clarify what this is
    item.jsonb#>> '{itemLevelCallNumber}' AS item_level_call_number,
    item.jsonb#>> '{effectiveCallNumberComponents,prefix}' as item_effective_call_number_prefix, -- added for complete information
    item.jsonb#>> '{effectiveCallNumberComponents,callNumber}' as item_effective_call_number, -- added because item call number is usually null
    item.jsonb#>> '{effectiveCallNumberComponents,suffix}' as item_effective_call_number_suffix, -- added for complete information
    item.jsonb#>> '{enumeration}' AS enumeration, -- resequenced this field to come after the call number
    item.jsonb#>> '{chronology}' AS chronology, -- resequenced this field to come after the call number
    item.jsonb#>> '{copyNumber}' AS copy_number, -- resequenced this field to come after the call number
    item__t.material_type_id::uuid,
    material_type__t.name AS material_type_name,
    item.jsonb#>> '{numberOfPieces}' AS number_of_pieces,
    item__t.permanent_loan_type_id::uuid,
    loan_type__t1.name AS permanent_loan_type_name,
    (item.jsonb#>> '{temporaryLoanTypeId}')::uuid AS temporary_loan_type_id,
    loan_type__t2.name AS temporary_loan_type_name,
    (loan.jsonb#>> '{renewalCount}')::bigint AS renewal_count
FROM
    folio_circulation.loan__t 
    LEFT JOIN folio_circulation.loan 
    ON loan__t.id = loan.id 
    
    LEFT JOIN folio_inventory.service_point__t AS ispi 
    ON (loan.jsonb#>> '{checkinServicePointId}')::uuid = ispi.id
    
    LEFT JOIN folio_inventory.service_point__t AS ispo 
    ON (loan.jsonb#>> '{checkoutServicePointId}')::uuid = ispo.id
    
    LEFT JOIN folio_inventory.item 
    ON loan__t.item_id::uuid = item.id
    
    LEFT JOIN folio_inventory.item__t 
    ON loan__t.item_id::uuid = item__t.id
    
    LEFT JOIN folio_inventory.location__t 
    ON (item.jsonb#>> '{permanentLocationId}')::uuid = location__t.id
    
    LEFT JOIN folio_inventory.loclibrary__t 
    ON location__t.library_id = loclibrary__t.id
  
    LEFT JOIN folio_inventory.loccampus__t
    ON location__t.campus_id = loccampus__t.id 
  
    LEFT JOIN folio_inventory.locinstitution__t 
    ON location__t.institution_id = locinstitution__t.id
  
    LEFT JOIN folio_inventory.location__t as loc1 
    ON (loan.jsonb#>> '{itemEffectiveLocationIdAtCheckOut}')::uuid = loc1.id
       
    LEFT JOIN folio_inventory.location__t as loc2
    ON item__t.effective_location_id::uuid = loc2.id
    
    LEFT JOIN folio_inventory.loclibrary__t as loclibrary__t2 -- added this to capture the effective location library name
    ON loc2.library_id = loclibrary__t2.id
 
    LEFT JOIN folio_inventory.location__t as loc3
    ON (item.jsonb#>> '{temporaryLocationId}')::uuid = loc3.id
      
    LEFT JOIN folio_inventory.location__t as loc4
    ON item__t.permanent_location_id::uuid = loc4.id
    
    LEFT JOIN folio_inventory.service_point__t AS ispt 
    ON (item.jsonb#>> '{inTransitDestinationServicePointId}')::uuid = ispt.id

    LEFT JOIN folio_circulation.loan_policy__t 
    ON (loan.jsonb#>> '{loanPolicyId}')::uuid = loan_policy__t.id
    
    LEFT JOIN folio_feesfines.lost_item_fee_policy__t 
    ON (loan.jsonb#>> '{lostItemPolicyId}')::uuid = lost_item_fee_policy__t.id
    
    LEFT JOIN folio_feesfines.overdue_fine_policy__t 
    ON (loan.jsonb#>> '{overdueFinePolicyId}')::uuid = overdue_fine_policy__t.id
    
    LEFT JOIN folio_users.groups__t 
    ON (loan.jsonb#>> '{patronGroupIdAtCheckout}')::uuid = groups__t.id
    
    LEFT JOIN folio_inventory.material_type__t 
    ON item__t.material_type_id::uuid = material_type__t.id
    
    LEFT JOIN folio_inventory.loan_type__t as loan_type__t1 
    ON item__t.permanent_loan_type_id::uuid = loan_type__t1.id
    
    LEFT JOIN folio_inventory.loan_type__t as loan_type__t2
    ON (item.jsonb#>> '{temporaryLoanTypeId}')::uuid = loan_type__t2.id
  ;

