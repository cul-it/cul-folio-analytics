--CR236
--lts_miscellaneous_titles_added
--Created by Natalya Pikulik
--Created on 03/18/24
--Used in LTS Aquisition Dashbaord, LTS Miscellaneous Titles Added
--This report pulls new titles added by instance statistical code


SELECT 
ii.metadata__created_date ::DATE AS instance_created_date,
ii.hrid AS inst_hrid,
ii.metadata__created_date,
isc.statistical_code,
case when isc.statistical_code ILIKE '%deposit%' then 'deposit'
     when isc.statistical_code ILIKE '%gift%' then 'gift'
     when isc.statistical_code ILIKE '%NPAC%' then 'NPAC'
     when isc.statistical_code ILIKE '%PL480%' then 'PL480'
     when isc.statistical_code ILIKE '%misc%' then 'misc:series/membership SO'
END AS statistical_code_name,
ii.discovery_suppress 
FROM inventory_instances ii
LEFT JOIN folio_reporting.instance_statistical_codes isc ON ii.id = isc.instance_id
LEFT JOIN folio_reporting.holdings_ext he ON he.instance_id = ii.id
WHERE isc.statistical_code ILIKE ANY(ARRAY['%deposit%', '%gift%', '%NPAC%', '%PL480%', '%misc%'])  
AND ii.metadata__created_date::date > '2021-07-01'
AND ii.discovery_suppress IS FALSE
;
