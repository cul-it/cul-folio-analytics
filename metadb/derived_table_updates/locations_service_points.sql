--metadb:table locations_service_points

--This derived table creates a derived table that extracts the service points 
--array from locations and creates a direct connection between the locations and
--all of their service points.
 
DROP TABLE IF EXISTS locations_service_points;

CREATE TABLE locations_service_points AS

with locations_libraries as

(SELECT

    cmp.id AS campus_id,

    cmp.name AS campus_name,

    cmp.code AS campus_code,

    loc.id AS location_id,

    loc.name AS location_name,

    loc.code AS location_code,

    loc.discovery_display_name AS discovery_display_name,

    lib.id AS library_id,

    lib.name AS library_name,

    lib.code AS library_code,

    inst.id AS institution_id,

    inst.name AS institution_name,

    inst.code AS institution_code

FROM

    folio_inventory.loccampus__t AS cmp

    LEFT JOIN folio_inventory.location__t AS loc ON cmp.id = loc.campus_id::uuid

    LEFT JOIN folio_inventory.locinstitution__t AS inst ON loc.institution_id::uuid = inst.id

    LEFT JOIN folio_inventory.loclibrary__t AS lib ON loc.library_id::uuid = lib.id

    )

 

SELECT

        (service_points.data #>> '{}')::uuid AS service_point_id, 

        isp.discovery_display_name AS service_point_discovery_display_name,

        isp.name AS service_point_name,

        ll.location_id,

        ll.discovery_display_name AS location_discovery_display_name,

        ll.location_name,

        ll.library_id,

        ll.library_name,

        ll.campus_id,

        ll.campus_name,

        ll.institution_id,

        ll.institution_name

    FROM folio_inventory.location AS il

        CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(il.jsonb, 'servicePointIds')) AS service_points (data)

        LEFT JOIN folio_inventory.service_point__t AS isp ON (service_points.data #>> '{}')::uuid = isp.id

        LEFT JOIN locations_libraries AS ll ON il.id=ll.location_id;
