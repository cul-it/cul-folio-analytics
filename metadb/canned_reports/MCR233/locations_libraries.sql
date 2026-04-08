--MCR233
--locations_libraries
--This query creates the a location table in the schema local_static that is used for Annual Data Collection (ADC) queries.
--Query writers: Joanne Leary, Vandana Shah
--Posted on: 4/8/26

DROP TABLE IF EXISTS local_static.vs_locations_libraries;

CREATE TABLE local_static.vs_locations_libraries AS

(WITH MAIN AS 
(
SELECT
    to_char(current_date, 'mm/dd/yyyy') AS table_create_date, 

    
    to_char(jsonb_extract_path_text(invlocjb.jsonb, 'metadata', 'createdDate')::date, 'mm/dd/yyyy') AS location_created_date,
    to_char(jsonb_extract_path_text(invlocjb.jsonb, 'metadata', 'updatedDate')::date, 'mm/dd/yyyy') AS location_updated_date,

    invlocjb.id AS location_id, 
    invloc.code AS location_code,
    invloc.name AS location_name,
    invloc.discovery_display_name AS discovery_display_name,
    invloclib.name AS shelving_library_name,

    CASE 
        WHEN jsonb_extract_path_text(invlocjb.jsonb, 'isActive') = 'true' THEN 'Active' 
        ELSE 'Inactive' 
    END AS location_status,

    --jsonb_extract_path_text(invlocjb.jsonb, 'description') AS location_description,

    CASE 
        WHEN invloc.code IN (
            'Ent,anx','gnva','gnva,anx','ilr','ilr,anx','ilr,kanx','ilr,laborref','ilr,lmdc','ilr,lmdr','ilr,mcs',
            'ilr,permres','ilr,rare','ilr,ref','ilr,res','mann','mann,anx','mann,anxt','mann,cd',
            'mann,ellis','mann,new','mann,ref','mann,res','mnsc','mnsc,anx','orni','orni,anx',
            'orni,cumv','orni,mac','orni,ref','vet','vet,ahdc','vet,anes','vet,anx','vet,cahem',
            'vet,clpath','vet,comp','vet,core','vet,crar','vet,den','vet,der','vet,equ',
            'vet,exo','vet,feli','vet,gross','vet,mrc','vet,neu','vet,onc','vet,oph','vet,path',
            'vet,pharm','vet,rad','vet,res','vet,shelter','vet,smcomm','vet,smsurg','vet,sport',
            'vet,tutor','vet,wild'
        ) THEN 'Contract'

        WHEN invloc.code IN (
            'afr', 'afr,anx','afr,av','afr,new','afr,permres','afr,ref','afr,res','asia','asia,anx','asia,av','asia,ranx',
            'asia,rare','asia,ref','cons','cts','dcap','ech','ech,anx','ech,av','ech,ranx',
            'ech,rare','ech,ref','engr,anx','fine','fine,anx','fine,art','fine,flats','fine,new',
            'fine,permres','fine,ref','fine,res','hote','hote,anx','hote,desk','hote,rare',
            'hote,ref','hote,ref2','jgsm','jgsm,anx','jgsm,new','jgsm,ref','jgsm,ref2','jgsm,res',
            'law','law,anx','law,lega','law,permres','law,ref','law,res','law,spres','lawr',
            'lawr,anx','maps','maps,anx','math','math,anx','math,desk','math,permres','math,ref',
            'math,res','mus','mus,anx','mus,av','mus,lock','mus,permres','mus,ref','mus,res',
            'mus,spcol','oclc,olim','oclc,olir','olin','olin,303','olin,403','olin,501','olin,603',
            'olin,604','olin,605','olin,701','olin,anx','olin,av','olin,new','olin,permres',
            'olin,ref','olin,res','olin,resdesk','phys,anx','rmc','rmc,anx','rmc,hsci','rmc,ice',
            'rmc,icer','rmc,ref','sasa','sasa,anx','sasa,av','sasa,ranx','sasa,rare','sasa,ref',
            'uris','uris,adwhite','uris,anx','uris,permres','uris,ref','uris,res',
            'was','was,anx','was,av','was,ranx','was,rare','was,ref'
        ) THEN 'Endowed'
        
        WHEN invloclib.name ILIKE '%Wood%'
        OR invloclib.name ILIKE '%Medical%'
        THEN 'WCM'
    
        ELSE 'Unassigned'--'Null'
    END AS College_Financial_Group   
    
FROM folio_inventory."location" AS invlocjb
LEFT JOIN folio_inventory.location__t AS invloc ON invlocjb.id = invloc.id
LEFT JOIN folio_inventory.loclibrary__t AS invloclib ON invloc.library_id = invloclib.id)

SELECT 
table_create_date, 
location_created_date,
location_updated_date,
location_id, 
location_code,
location_name,
discovery_display_name,
shelving_library_name,
location_status,
College_Financial_Group,
CASE
	WHEN main.College_Financial_Group = 'Unassigned' OR
	main.College_Financial_Group = 'WCM' 
	THEN 'NO' 
	ELSE 'YES'
	END AS Include_for_Annual_Data
FROM main
)
;
