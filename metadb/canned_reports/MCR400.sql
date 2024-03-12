--MCR400
--Calendar settings by service point and semester

-- This query displays the calendar settings for a given service point and semester. Service points using a "Universal" calendar. (ILL, Borrow Direct, the Annex, contactless pickup and remote delivery SP's, and sometimes other units) will not have a year or semester value, so leave those filters blank; or enter "Universal" in the semester filter.
-- NOTE: Exception dates will repeat for every normal-hours weekday entry (usually seven weekdays times the number of exception calendars for that semester)

--Query writer: Joanne Leary
--Date written: 2/12/24


WITH parameters AS 
(SELECT
'%Mann%'::VARCHAR AS service_point_name_filter, -- enter a service point name (OK to enter just a library designation, such as "math", "ilr", "law" etc)
'2024'::VARCHAR AS calendar_year_filter, -- enter a year (ex: 2024) or leave blank
'%Fall%'::VARCHAR AS semester_filter -- enter a semester (ex: Spring) or "Universal" or leave blank
),

-- 1. Get normal hours

normal_hours AS 
(SELECT DISTINCT
       'Normal hours' AS type_of_hours,
       sp.id AS service_point_id,
       spc.id AS service_point_calendar_id,
       cal.id AS calendar_id,
       jsonb_extract_path_text (sp.jsonb,'name') AS service_point_name,
       jsonb_extract_path_text (sp.jsonb,'code') AS service_point_code,
       cal.name AS calendar_name,
       SUBSTRING (cal.name,'\d{4}') AS calendar_year,
       cal.start_date,
       cal.end_date,
       nh.start_day,
       CASE 
              WHEN nh.start_day = 'MONDAY' THEN 2
              WHEN nh.start_day = 'TUESDAY' THEN 3
              WHEN nh.start_day = 'WEDNESDAY' THEN 4
              WHEN nh.start_day = 'THURSDAY' THEN 5
              WHEN nh.start_day = 'FRIDAY' THEN 6
              WHEN nh.start_day = 'SATURDAY' THEN 7
              ELSE 1
              END AS weekday_number,
       TO_CHAR (nh.start_time::text::time,'hh:mi am') AS start_time,
       TO_CHAR (nh.end_time::text::time,'hh:mi am') AS end_time
       
FROM service_point AS sp
       LEFT JOIN folio_calendar.service_point_calendars AS spc 
       ON sp.id = spc.service_point_id
       
       LEFT JOIN folio_calendar.calendars__ AS cal 
       ON spc.calendar_id = cal.id
       
       LEFT JOIN folio_calendar.normal_hours__ AS nh 
       ON cal.id = nh.calendar_id

WHERE 
       ((SELECT service_point_name_filter FROM parameters) = '' OR jsonb_extract_path_text (sp.jsonb,'name') ILIKE (SELECT service_point_name_filter FROM parameters))
       AND ((SELECT calendar_year_filter FROM parameters) = '' OR SUBSTRING (cal.name,'\d{4}') = (SELECT calendar_year_filter FROM parameters))
       AND ((SELECT semester_filter FROM parameters) = '' OR cal.name ILIKE (SELECT semester_filter FROM parameters))

ORDER BY service_point_name, cal.start_date, cal.end_date, weekday_number
),

-- 2. Get exception hours

exception_hours AS 
(SELECT DISTINCT
       'Exception hours' AS type_of_hours,
       cal.name AS calendar_name,
       SUBSTRING (cal.name,'\d{4}') AS calendar_year,
       ex.calendar_id AS calendar_id,
       ex.id AS exception_id,
       ex.name AS exception_hours_name,
       ex.start_date AS exception_start_date,
       ex.end_date AS exception_end_date,
       CASE WHEN TO_CHAR (exh.open_start_time::time,'hh:mi am') IS NULL THEN 'Closed' ELSE  TO_CHAR (exh.open_start_time::time,'hh:mi am') END AS open_time,
       CASE WHEN TO_CHAR (exh.open_end_time::time, 'hh:mi am') IS NULL THEN 'Closed' ELSE TO_CHAR (exh.open_end_time::time, 'hh:mi am') END AS close_time

FROM service_point AS sp
       LEFT JOIN folio_calendar.service_point_calendars AS spc 
       ON sp.id = spc.service_point_id
       
       LEFT JOIN folio_calendar.calendars__ AS cal 
       ON spc.calendar_id = cal.id
       
       LEFT JOIN folio_calendar.exceptions__ AS ex 
       ON cal.id = ex.calendar_id

       LEFT JOIN folio_calendar.exception_hours__ AS exh 
       ON ex.id = exh.exception_id

WHERE 
       ((SELECT service_point_name_filter FROM parameters) = '' OR jsonb_extract_path_text (sp.jsonb,'name') ILIKE (SELECT service_point_name_filter FROM parameters))
       AND ((SELECT calendar_year_filter FROM parameters) = '' OR SUBSTRING (cal.name,'\d{4}') = (SELECT calendar_year_filter FROM parameters))
       AND ((SELECT semester_filter FROM parameters) = '' OR cal.name ILIKE (SELECT semester_filter FROM parameters))

ORDER BY cal.name, ex.start_date
)

-- 3. Join normal hours to exception hours

SELECT DISTINCT
       --TO_CHAR (generate_series (normal_hours.start_date, normal_hours.end_date,'1 day')::date,'mm/dd/yyyy') AS dates,
       normal_hours.service_point_name,
       normal_hours.calendar_name,
       concat (normal_hours.start_date,' - ',normal_hours.end_date) AS normal_hours_date_range,
       normal_hours.start_day AS weekday,
       normal_hours.weekday_number,
       normal_hours.start_time AS normal_hours_start_time,
       normal_hours.end_time AS normal_hours_end_time,
       exception_hours.exception_hours_name,
       exception_hours.exception_start_date,
       exception_hours.exception_end_date,
       exception_hours.open_time,
       exception_hours.close_time

FROM normal_hours 
       LEFT JOIN exception_hours 
       ON normal_hours.calendar_id = exception_hours.calendar_id

ORDER BY normal_hours.service_point_name, normal_hours_date_range, normal_hours.weekday_number, exception_hours.exception_start_date
;
