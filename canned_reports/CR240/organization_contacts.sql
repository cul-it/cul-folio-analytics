--CR240
--Organization contacts
--This query was requested by Adam Chandler to help acquisitions staff with finding the contact information for vendors.
--Note from Joanne Leary: 
--90%+ of the “organizations” do not have contact information in Folio, and the “po_organizations” derived table is totally wrong, because it matches on the wrong id’s. (I have noted this on the “known problems” spreadsheet.) This query finds whatever information is available, and shows blanks when there is no contact information available. Contact information includes the organization’s name, the “alias” (a mysterious code that we see in a lot of instance records), the contact’s name, phone #, email, physical mailing address and website. Very few entries have complete information. Most entries have none at all.
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah(vp25)
--Date posted: 4/16/24

--1. Extract the contact id from the organization_organizations data array

WITH recs AS 
(SELECT DISTINCT
   oo.id AS org_id,
   oo.code AS org_code,
   oo.name AS org_name,
   oo.is_vendor,
   JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oo.data, 'aliases')),'value') AS alias,
   JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oo.data, 'aliases')),'description') AS alias_description,
   JSONB_ARRAY_ELEMENTS ((oo.data #>'{contacts}')::JSONB)::VARCHAR AS contact

FROM organization_organizations AS oo

ORDER BY org_code
),

--2. Normalize the contact ID to get rid of quotes, and if null, enter a dash (this is for matching purposes)

recs2 AS 
(SELECT DISTINCT
	recs.org_id,
	recs.org_code,
	recs.org_name,
	recs.is_vendor,
	recs.alias,
	recs.alias_description,
	CASE WHEN recs.contact IS NULL THEN '-' ELSE SUBSTRING (recs.contact,2,36) END AS contacts

FROM recs 
ORDER BY org_code
),

--3. Extract all the necessary data elements from the organization_contacts table data array and join the results by contact ID found in the previous subqueries
-- Note: some entries in the organization_contacts table do not have matching organization ID entries in the organization_organizations table, and vice-versa

recs3 as 
(SELECT DISTINCT
	recs2.org_id,
	recs2.org_name,
	recs2.org_code,
	recs2.alias,
	recs2.alias_description,
	recs2.is_vendor,
	recs2.contacts AS oo_contact_id,
	oc.id AS oc_concact_id,
	oc.metadata__created_date::date as created_date,
	oc.metadata__updated_date::date as updated_date,
	concat (uu.personal__first_name,' ',uu.personal__last_name) as updated_by,
	oc.last_name as contact_last_name,
	oc.first_name as contact_first_name,
	oc.notes,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'addresses')),'addressLine1') AS address_line_1,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'addresses')),'addressLine2') AS address_line_2,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'addresses')),'city') AS city,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'addresses')),'stateRegion') AS state_region,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'addresses')),'country') AS country,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'addresses')),'zipCode') AS zip_code,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'addresses')),'isPrimary') AS is_primary,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'emails')),'value') AS email_address,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'phoneNumbers')),'phoneNumber') AS phone_number,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'urls')),'value') AS url,
	JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (oc.data, 'urls')),'description') AS url_description

FROM recs2
	FULL OUTER JOIN organization_contacts AS oc 
	ON recs2.contacts = oc.id
	
	LEFT JOIN user_users AS uu 
	ON oc.metadata__updated_by_user_id = uu.id

ORDER BY org_name, org_code, created_date, updated_date, contact_last_name, contact_first_name
)

--4. Join results of recs3 to the organization_organizations table again to get all entries in that table (90% of the organizations don't have contacts)

SELECT DISTINCT
	oo.id AS oo_id,
	oo.name AS oo_name,
	oo.code AS oo_code,
	oo.description AS oo_description,
	recs3.*

FROM organization_organizations AS oo 
	LEFT JOIN recs3 
	ON oo.id = recs3.org_id

ORDER BY oo.name, oo.code, created_date, updated_date
;
