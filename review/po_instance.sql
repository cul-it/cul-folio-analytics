--NOTE: Need to verify whether or not to point to derived table po_lines_locations instead of extracting holdings id and locations id from JSON again

-- metadb:table po_instance

-- Create a derived table for inventory instances associated with purchase order lines. 
-- Every po line may have location ID or holding ID or both can be 'null'. 
-- If both are 'null', then 'no source' is present in pol_location_source.
-- Pol_location depends on how the po is created.

DROP TABLE IF EXISTS po_instance;

CREATE TABLE po_instance AS

SELECT DISTINCT
	purchase_order__t.manual_po::BOOLEAN,
	po_line__t.rush,
	po_line__t.requester,
	po_line__t.selector,
    	purchase_order__t.po_number,
    	purchase_order__t.id AS po_number_id,
    	po_line__t.po_line_number,
    	po_line.id AS po_line_id,
    	organizations__t.code AS vendor_code,
    	users__t.username AS created_by_username,
    	purchase_order__t.workflow_status AS po_workflow_status,
    	purchase_order__t.approved::BOOLEAN AS status_approved,
    	JSONB_EXTRACT_PATH_TEXT(purchase_order.JSONB, 'metadata', 'createdDate')::timestamptz AS created_date, -- (purchase order create date) 
    	JSONB_EXTRACT_PATH_TEXT(cdt.value::JSONB, 'name') AS bill_to,
    	JSONB_EXTRACT_PATH_TEXT(cdt2.value::JSONB, 'name') AS ship_to,
    	po_line__t.instance_id AS pol_instance_id,
    	instance__t.hrid AS pol_instance_hrid,
    	(locations.jsonb #>> '{holdingId}')::uuid AS pol_holding_id, 
    	(locations.jsonb #>> '{locationId}')::uuid AS pol_location_id,
    	--holdings_record__t.hrid AS pol_holdings_hrid,       
    	--location__t.name AS pol_location_name,
    	--location__t2.name AS pol_holdings_location_name,
    	COALESCE (location__t.name, location__t2.name,'-') AS pol_location_name,
    	CASE 
		WHEN location__t.name IS NULL AND location__t2.name IS NULL THEN 'no_source'
		WHEN location__t.name IS NULL AND location__t2.name IS NOT NULL THEN 'pol_holding'
		WHEN location__t.name IS NOT NULL AND location__t2.name IS NULL THEN 'pol_location'
		ELSE '-' END AS pol_location_source, 
	po_line__t.title_or_package AS title,		
	po_line__t.publication_date,
	po_line__t.publisher
		
FROM folio_orders.po_line
    CROSS JOIN LATERAL jsonb_array_elements((po_line.jsonb #> '{locations}')::jsonb) AS locations (data)
	
	LEFT JOIN folio_orders.po_line__t 
	ON po_line.id = po_line__t.id
			
	LEFT JOIN folio_inventory.instance__t 
	ON po_line__t.instance_id = instance__t.id	
		
	LEFT JOIN folio_inventory.location__t 
	ON (locations.jsonb #>> '{locationId}')::uuid = location__t.id
	
	LEFT JOIN folio_inventory.holdings_record__t 
	ON (locations.jsonb #>> '{holdingId}')::uuid = holdings_record__t.id
	
	LEFT JOIN folio_inventory.location__t AS location__t2
	ON holdings_record__t.permanent_location_id = location__t2.id
 
	LEFT JOIN folio_orders.purchase_order__t 
	ON po_line.purchaseorderid = purchase_order__t.id 
		
	LEFT JOIN folio_organizations.organizations__t 
	ON purchase_order__t.vendor = organizations__t.id
	
	LEFT JOIN folio_orders.purchase_order 
	ON purchase_order__t.id = purchase_order.id
	
	LEFT JOIN folio_configuration.config_data__t cdt 
	ON JSONB_EXTRACT_PATH_TEXT(purchase_order.JSONB, 'billTo')::UUID = cdt.id
	    
	LEFT JOIN folio_configuration.config_data__t cdt2 
	ON JSONB_EXTRACT_PATH_TEXT(purchase_order.JSONB, 'shipTo')::UUID = cdt2.id
	    
	LEFT JOIN folio_users.users__t 
	ON JSONB_EXTRACT_PATH_TEXT(purchase_order.JSONB, 'metadata', 'createdByUserId')::UUID = users__t.id
;    

COMMENT ON COLUMN po_instance.manual_po IS 'If true, order cannot be sent automatically, e.g. via EDI';

COMMENT ON COLUMN po_instance.rush IS 'Whether or not this is a rush order';

COMMENT ON COLUMN po_instance.requester IS 'Who requested this material and needs to be notified on arrival';

COMMENT ON COLUMN po_instance.selector IS 'Who selected this material';

COMMENT ON COLUMN po_instance.po_number IS 'A human readable number assigned to PO';

COMMENT ON COLUMN po_instance.po_number_id IS 'UUID identifying this PO';

COMMENT ON COLUMN po_instance.po_line_number IS 'A human readable number assigned to PO line';

COMMENT ON COLUMN po_instance.po_line_id IS 'UUID identifying this purchase order line';

COMMENT ON COLUMN po_instance.vendor_code IS 'The code of the vendor';

COMMENT ON COLUMN po_instance.created_by_username IS 'Username of the user who created the record (when available)';

COMMENT ON COLUMN po_instance.po_workflow_status IS 'Workflow status of purchase order';

COMMENT ON COLUMN po_instance.status_approved IS 'Wether purchase order is approved or not';

COMMENT ON COLUMN po_instance.created_date IS 'Date when the purchase order was created';

COMMENT ON COLUMN po_instance.bill_to IS 'Name of the bill_to location of the purchase order';

COMMENT ON COLUMN po_instance.ship_to IS 'Name of the ship_to location of the purchase order';

COMMENT ON COLUMN po_instance.pol_instance_id IS 'UUID of the instance record this purchase order line is related to';

COMMENT ON COLUMN po_instance.pol_instance_hrid IS 'A human readable number of the instance record this purchase order line is related to';

COMMENT ON COLUMN po_instance.pol_holding_id IS 'UUID of the holdings this purchase order line is related to';

COMMENT ON COLUMN po_instance.pol_location_id IS 'UUID of the location created for this purcase order line';

COMMENT ON COLUMN po_instance.pol_location_name IS 'Name of the purchase order line location';

COMMENT ON COLUMN po_instance.pol_location_source IS 'Wether location is a holdings location or permanent location of the purchase order line';

COMMENT ON COLUMN po_instance.title IS 'Title of the material';

COMMENT ON COLUMN po_instance.publication_date IS 'Date (year) of the material''s publication';

COMMENT ON COLUMN po_instance.publisher IS 'Publisher of the material';
