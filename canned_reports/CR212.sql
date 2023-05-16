--CR212
--Number of holdings records in permanent and temporary locations 
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 5/16/2023
--This query counts the total number of holdings records in all locations (perm and temp locations), even if there are zero holdings,
-- and includes suppressed and unsuppressed records.

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

FROM inventory_libraries AS invlibs 
                LEFT JOIN inventory_locations AS il
                ON invlibs.id = il.library_id
                
                LEFT JOIN inventory_holdings AS ih 
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

FROM inventory_libraries AS invlibs 
                LEFT JOIN inventory_locations AS il
                ON invlibs.id = il.library_id
                
                LEFT JOIN inventory_holdings AS ih 
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
                il.is_active,
                perm_locs.count_of_holdings_in_perm_location,
                temp_locs.count_of_holdings_in_temp_location

FROM inventory_libraries AS invlibs 
                LEFT JOIN inventory_locations AS il
                ON invlibs.id = il.library_id
                
                LEFT JOIN perm_locs
                ON il.id = perm_locs.location_id
                
                LEFT JOIN temp_locs 
                ON il.id = temp_locs.location_id

ORDER BY invlibs.name, il.code
;
