--metadb:table feesfines_accounts_actions
-- Feesfines_accounts_actions derived table correction - 5-15-26
-- 5-15-26: update needed because source table (folio_feesfines.accounts) has changed
-- 10-29-26: updated the following fields due to structural changes in the folio_feesfines tables:
	-- fine_date, fine_updated_date, material_type, payment_status, transaction_location
	-- Optional changes:
		-- added item_barcode for utility
		-- there are redundant fields for patron_group_id and user_id; get rid of uu.id and 
		-- added suggestion for changing label "operator_id" to "operator_name"
		-- added comments to clarify what ambiguously-named id fields actually are 	

-- Create a derived table that takes feesfines_accounts as the main table
-- join all transaction data from the feesfines_actions table
-- add patron group information from user_group table

DROP TABLE IF EXISTS feesfines_accounts_actions;

CREATE TABLE feesfines_accounts_actions AS
SELECT
    fa.id AS fine_account_id, -- id of the actual fine (same as the "account_id" from the feesfines_actions table)
    jsonb_extract_path_text(fa.jsonb, 'amount')::numeric(12,2) AS fine_account_amount,
    jsonb_extract_path_text (fa.jsonb,'metadata','createdDate')::timestamptz as fine_date, 
    jsonb_extract_path_text (fa.jsonb,'metadata','updatedDate')::timestamptz as fine_updated_date,
    jsonb_extract_path_text(fa.jsonb, 'feeFineId')::uuid AS fee_fine_id, -- this is an id for the combination of fine type and owning library; this is not the id of the fine itself
    jsonb_extract_path_text(fa.jsonb, 'ownerId')::uuid AS owner_id,
    jsonb_extract_path_text(fa.jsonb, 'feeFineOwner') AS fee_fine_owner, 
    jsonb_extract_path_text(fa.jsonb, 'feeFineType') AS fee_fine_type,
    jsonb_extract_path_text(fa.jsonb, 'materialTypeId')::uuid AS material_type_id,
    COALESCE (jsonb_extract_path_text(fa.jsonb, 'materialType'),material_type__t.name) AS material_type, -- added to eliminate null values
    jsonb_extract_path_text (fa.jsonb, 'paymentStatus','name') as payment_status,
    jsonb_extract_path_text(fa.jsonb, 'status', 'name') AS fine_status,
    jsonb_extract_path_text(fa.jsonb, 'userId')::uuid AS account_user_id,
    jsonb_extract_path_text (fa.jsonb,'barcode') as item_barcode, -- new field added for usability
    ff.id AS transaction_id,
    jsonb_extract_path_text(ff.jsonb, 'accountId')::uuid AS account_id, -- id of the actual fine; same as the "fa.id" from the accounts table
    jsonb_extract_path_text(ff.jsonb, 'amountAction')::numeric(12,2) AS transaction_amount,
    jsonb_extract_path_text(ff.jsonb, 'balance')::numeric(12,2) AS account_balance,
    jsonb_extract_path_text(ff.jsonb, 'typeAction') AS type_action,
    jsonb_extract_path_text(ff.jsonb, 'dateAction')::timestamptz AS transaction_date,
    jsonb_extract_path_text(ff.jsonb, 'createdAt')::UUID AS transaction_location,
    jsonb_extract_path_text(ff.jsonb, 'transactionInformation') AS transaction_information,
    jsonb_extract_path_text(ff.jsonb, 'source') AS operator_id, -- misleading; should be called "operator name"
    jsonb_extract_path_text(ff.jsonb, 'paymentMethod') AS payment_method,
    uu.id AS user_id, -- suggest eliminating (same as account_user_id)
    uu.patron_group AS user_patron_group_id, -- suggest eliminating (same as ug.id)
    ug.id AS patron_group_id,
    ug.group AS patron_group_name
FROM
    folio_feesfines.accounts AS fa
    LEFT JOIN folio_feesfines.feefineactions AS ff ON fa.id = jsonb_extract_path_text(ff.jsonb, 'accountId')::uuid
    LEFT JOIN folio_users.users__t AS uu ON jsonb_extract_path_text(fa.jsonb, 'userId')::uuid = uu.id
    LEFT JOIN folio_users.groups__t AS ug ON uu.patron_group::uuid = ug.id 
    LEFT JOIN folio_inventory.material_type__t on jsonb_extract_path_text(fa.jsonb, 'materialTypeId')::uuid = material_type__t.id -- added
    
ORDER BY fine_account_id, transaction_date;

