--MCR212
-- Number_of_holdings_records_in_permanent_and_temporary_locations 
--This query counts the total number of holdings records in all locations (perm and temp locations), even if there are zero holdings, and includes suppressed and unsuppressed records.

--Query writer: Joanne Leary (jl41)
--Date posted: 12-20-24


--1. Get items in perm locations

WITH perm_locs AS 
(SELECT 
                invlibs.code AS library_code,
                invlibs.name AS library_name,
                il.id AS location_id,
                il.code AS location_code,
                il.discovery_display_name,
                il.name AS location_name,
                il.is_active,
                count (ih.id) AS count_of_holdings_in_perm_location

FROM folio_inventory.loclibrary__t as invlibs -- inventory_libraries AS invlibs 
                LEFT JOIN folio_inventory.location__t as il --inventory_locations AS il
                ON invlibs.id = il.library_id
                
                LEFT JOIN folio_inventory.holdings_record__t as ih -- inventory_holdings AS ih 
                ON il.id = ih.permanent_location_id

GROUP BY 
                invlibs.code,
                invlibs.name,
                il.id,
                il.code,
                il.discovery_display_name,
                il.name,
                il.is_active

ORDER BY invlibs.name, il.code
),

--2. Get items in temp locations

temp_locs AS
(SELECT 
                invlibs.code AS library_code,
                invlibs.name AS library_name,
                il.id AS location_id,
                il.code AS location_code,
                il.discovery_display_name,
                il.name AS location_name,
                il.is_active,
                count (ih.id) AS count_of_holdings_in_temp_location

FROM folio_inventory.loclibrary__t as invlibs --inventory_libraries AS invlibs 
                LEFT JOIN folio_inventory.location__t as il --inventory_locations AS il
                ON invlibs.id = il.library_id
                
                LEFT JOIN folio_inventory.holdings_record__t as ih --inventory_holdings AS ih 
                ON il.id = ih.temporary_location_id

GROUP BY 
                invlibs.code,
                invlibs.name,
                il.id,
                il.code,
                il.discovery_display_name,
                il.name,
                il.is_active

ORDER BY invlibs.name, il.code
)

--3. Join perm location count to temp location count

SELECT 
                to_char (current_date::date,'mm/dd/yyyy') AS todays_date,
                invlibs.code AS library_code,
                invlibs.name AS library_name,
                il.id AS location_id,
                il.code AS location_code,
                il.discovery_display_name,
                il.name AS location_name,
                il.is_active as location_status,
                perm_locs.count_of_holdings_in_perm_location,
                temp_locs.count_of_holdings_in_temp_location

FROM folio_inventory.loclibrary__t as invlibs --inventory_libraries AS invlibs 
                LEFT JOIN folio_inventory.location__t as il --inventory_locations AS il
                ON invlibs.id = il.library_id
                
                LEFT JOIN perm_locs
                ON il.id = perm_locs.location_id
                
                LEFT JOIN temp_locs 
                ON il.id = temp_locs.location_id

ORDER BY library_code, location_name 
;
