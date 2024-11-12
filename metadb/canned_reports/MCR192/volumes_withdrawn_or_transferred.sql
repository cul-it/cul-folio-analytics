--MRC192
--volumes withdrawn or transferred
--This query extracts holdings administrative note data to allow counts of physical items withdrawn by location AND to allow the identification of transfers that go from endowed to contract units, and vice-versa. These counts are used for volumes withdrawn figures needed by the Division of Financial Services each quarter. PLEASE SEE README FILE NOTES BEFORE USING THIS QUERY. 

WITH parameters AS 
        (SELECT 
        '20240701'AS begin_date, -- enter a begin date in the format 'yyyymmdd'
        '20250701'AS end_date -- enter an end date in the format 'yyyymmdd'
),

-- 1. get the format code from the leader
marc_formats AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             substring(marc__t."content", 7, 2) AS leader0607
       FROM folio_source_record.marc__t 
       WHERE marc__t.field = '000'
)--,

-- 2. sort locations into Endowed or Contract College
/*fbo as 
        (select 
        location__t.id as location_id,
        location__t.code as location_code,
        location__t.name as location_name,
        case when location__t.is_active = 'true' then 'Active' else 'Inactive' end as location_status,
        jsonb_extract_path_text (location.jsonb,'metadata','createdDate')::date as location_created_date,
        jsonb_extract_path_text (location.jsonb,'metadata','updatedDate')::date as location_updated_date,
        loclibrary__t.id as library_id,
        loclibrary__t.code as library_code,
        loclibrary__t.name as library_name,
        case 
                when location__t.code in ('cise','mann,hort','mann,ref','phys') then 'Not CUL'
                when location__t.code in ('acc,anx','agen','bd','bind,circ','bioc','cons,opt','cts,rev','engr','engr,ref','Engr,wpe','ent','fine,lock','food','hote,permres','hote,res',
        'jgsm,permres','law,ts','lts,ersm','mann,gate','mann,permres','mann,ts','nus','olin,ils','rmc,ts','serv,remo','vet,permres','vet,ref','void','xtest','z-test location') 
                        then 'Unknown'          
                when loclibrary__t.code = 'ANX' and location__t.code similar to '(asia|afr|fin|ech|sasa|engr|fine|law|math|mus|olin|phys|uris|was|hote|jgsm)%' then 'Endowed' -- hotel and jgsm annex are now endowed
                when loclibrary__t.code = 'ANX' and location__t.code similar to '(Ent|gnva|ilr|mann|orni|vet)%' then 'Contract College'
                when loclibrary__t.code in ('KHL','MA','VET','IL','HORT','ORN') then 'Contract College' 
                when loclibrary__t.code in ('VOID','SPC','DEL') then 'Unknown'
                else 'Endowed'  
        end as fbo_college_group

from folio_inventory.location 
        left join folio_inventory.location__t 
        on location.id = location__t.id

        left join folio_inventory.loclibrary__t 
        on location__t.library_id = loclibrary__t.id

where location.__current = 'true'

)*/

-- 3. get the holdings administractive notes and parse out the components: date withdrawn or transferred, action code, origination location, number of pieces; link to FBO subquery to sort the results into Endowed or Contract College
SELECT 

        current_date::date as todays_date,
        CONCAT ((SELECT begin_date FROM parameters),' - ', (SELECT end_date FROM parameters))AS date_range,
        CASE WHEN 
                date_part ('month',SUBSTRING (han.administrative_note,'\d{1,}')::timestamptz) > 6 --quotes, timestamptz
                THEN concat ('FY ', date_part ('year',SUBSTRING (han.administrative_note,'\d{1,}')::timestamptz) + 1) 
                ELSE concat ('FY ', date_part ('year',SUBSTRING (han.administrative_note,'\d{1,}')::timestamptz))
                END AS fiscal_year,
                
        instance__t.hrid as instance_hrid,
        han.holdings_hrid,
        instance__t.title,
        ll.name as holdings_location_name,
        ll.code as holdings_location_code,
        CASE WHEN instance__t.discovery_suppress = 'FALSE' OR  instance__t.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END AS instance_suppress,
    CASE WHEN he.discovery_suppress = 'FALSE' OR  he.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END AS holdings_suppress,
        TRIM (concat_ws (' ',he.call_number_prefix,he.call_number,he.call_number_suffix, 
        CASE WHEN he.copy_number>'' then concat ('c.',he.copy_number) else '' END))AS whole_call_number,
    mf.leader0607,            
        han.administrative_note as holdings_administrative_note,
        string_agg (distinct hn.note,' | ') as holdings_notes,
        SUBSTRING (han.administrative_note,'\d{8,}') AS date,            
        SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})') AS note_type,
        TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) AS ttype_code,
        SUBSTRING (SUBSTRING (han.administrative_note, 'userid:[a-z]{2,3}\d{1,}'),8) AS net_id,
        SUBSTRING (SUBSTRING (han.administrative_note, '(ploc:[a-z]{1,})'),6) AS processing_location,
        LOWER(TRIM(SUBSTRING (SUBSTRING (han.administrative_note,'orig:\s{0,1}.+'),6,10))) as originating_location,
        --fbo.fbo_college_group,
        adclt.dfs_college_group,

        CASE 
                WHEN han.administrative_note not ilike '%ttype%' then 0  -- WHEN the note does not contain a ttype, enter 0 
                WHEN TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) not in ('w','t') 
                        THEN 0 -- WHEN the ttype is not "w" or "t", enter "0"
                WHEN TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) in ('w','t') 
                        AND SUBSTRING (han.administrative_note,'pcs:') is null 
                        AND SUBSTRING (SUBSTRING (han.administrative_note,'(lts\s\d{1,})'),'\s\d{1,}') is not null
                        THEN SUBSTRING (SUBSTRING (han.administrative_note,'(lts\s\d{1,})'),'\s\d{1,}')::integer -- WHEN ttype is "w" or "t" AND "pcs:" is not there AND there is a string of digits at the end, enter the string of digits
                WHEN TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) in ('w','t')
                        AND SUBSTRING (SUBSTRING (han.administrative_note, '(pcs:\s{0,1}[0-9]{0,})'),5) is null 
                        THEN 1 -- WHEN the ttype is withdrawn or transferred, but the "pcs" code is not there (AND after the ones with digits at the end are taken care of), enter "1"                    
                WHEN SUBSTRING (SUBSTRING (han.administrative_note, '(pcs:\s{0,1}[0-9]{0,})'),5) = '' 
                        THEN 1 -- WHEN the pcs code is there, but no number is entered, enter "1"
                ELSE SUBSTRING (SUBSTRING (han.administrative_note, '(pcs:\s{0,1}[0-9]{0,})'),5)::integer -- else get the digits at the end of "pcs:"
        END
        AS number_of_pieces
        
FROM folio_derived.holdings_administrative_notes AS han
        INNER JOIN folio_inventory.instance__t 
        on han.instance_id = instance__t.id
        
        INNER JOIN folio_derived.holdings_ext AS he 
        on instance__t.id = he.instance_id 
        and han.holdings_id = he.holdings_id
        
        INNER JOIN folio_derived.holdings_notes AS hn
    ON he.holdings_id = hn.holding_id
        
        INNER JOIN folio_inventory.location__t AS ll 
        on he.permanent_location_id = ll.id
        
        INNER JOIN marc_formats AS mf 
        ON instance__t.id = mf.instance_id
        
       -- inner join fbo 
        --on he.permanent_location_id = fbo.location_id
        
        INNER JOIN local_shared.lm_adc_location_translation_table AS adclt ON he.permanent_location_id = adclt.inv_loc_id::UUID

WHERE TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) in ('t','w')
        AND SUBSTRING (han.administrative_note,'\d{8,}') >= (SELECT begin_date FROM parameters)
        AND SUBSTRING (han.administrative_note,'\d{8,}') < (SELECT end_date FROM parameters)
        AND mf.leader0607 LIKE ANY (ARRAY ['a%','t%','c%','d%'])
    AND ll.code != 'serv,remo'

GROUP BY 
        current_date::date,
        CONCAT ((SELECT begin_date FROM parameters),' - ', (SELECT end_date FROM parameters)),
        CASE WHEN 
                date_part ('month',SUBSTRING (han.administrative_note,'\d{1,}')::timestamptz) > 6 --quotes, timestamptz
                THEN concat ('FY ', date_part ('year',SUBSTRING (han.administrative_note,'\d{1,}')::timestamptz) + 1) 
                ELSE concat ('FY ', date_part ('year',SUBSTRING (han.administrative_note,'\d{1,}')::timestamptz))
                END,
                
        instance__t.hrid,
        han.holdings_hrid,
        instance__t.title,
        ll.name,
        ll.code,
        CASE WHEN instance__t.discovery_suppress = 'FALSE' OR  instance__t.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END,
    CASE WHEN he.discovery_suppress = 'FALSE' OR  he.discovery_suppress IS NULL THEN 'FALSE' ELSE 'TRUE' END,
        TRIM (concat_ws (' ',he.call_number_prefix,he.call_number,he.call_number_suffix, 
        CASE WHEN he.copy_number>'' then concat ('c.',he.copy_number) else '' END)),
    mf.leader0607,            
        han.administrative_note,
        SUBSTRING (han.administrative_note,'\d{8,}'),            
        SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),
        TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)),
        SUBSTRING (SUBSTRING (han.administrative_note, 'userid:[a-z]{2,3}\d{1,}'),8),
        SUBSTRING (SUBSTRING (han.administrative_note, '(ploc:[a-z]{1,})'),6),
        LOWER(TRIM(SUBSTRING (SUBSTRING (han.administrative_note,'orig:\s{0,1}.+'),6,10))) ,

        CASE 
                WHEN han.administrative_note not ilike '%ttype%' then 0  -- WHEN the note does not contain a ttype, enter 0 
                WHEN TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) not in ('w','t') 
                        THEN 0 -- WHEN the ttype is not "w" or "t", enter "0"
                WHEN TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) in ('w','t') 
                        AND SUBSTRING (han.administrative_note,'pcs:') is null 
                        AND SUBSTRING (SUBSTRING (han.administrative_note,'(lts\s\d{1,})'),'\s\d{1,}') is not null
                        THEN SUBSTRING (SUBSTRING (han.administrative_note,'(lts\s\d{1,})'),'\s\d{1,}')::integer -- WHEN ttype is "w" or "t" AND "pcs:" is not there AND there is a string of digits at the end, enter the string of digits
                WHEN TRIM (SUBSTRING (SUBSTRING (han.administrative_note, '(ttype:\s{0,1}[a-z]{1,5})'),7)) in ('w','t')
                        AND SUBSTRING (SUBSTRING (han.administrative_note, '(pcs:\s{0,1}[0-9]{0,})'),5) is null 
                        THEN 1 -- WHEN the ttype is withdrawn or transferred, but the "pcs" code is not there (AND after the ones with digits at the end are taken care of), enter "1"                    
                WHEN SUBSTRING (SUBSTRING (han.administrative_note, '(pcs:\s{0,1}[0-9]{0,})'),5) = '' 
                        THEN 1 -- WHEN the pcs code is there, but no number is entered, enter "1"
                ELSE SUBSTRING (SUBSTRING (han.administrative_note, '(pcs:\s{0,1}[0-9]{0,})'),5)::integer -- else get the digits at the end of "pcs:"
        end,
        --fbo.fbo_college_group,
        adclt.dfs_college_group
        
ORDER BY title 
;

