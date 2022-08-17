WITH filters AS 
(SELECT
        '2015-01-01'::DATE AS begin_date, -- enter the begin date or the FIRST semester you want
        '2020-05-15'::DATE AS end_date, -- enter the end date of the LAST semester you want
        'fine,circ'::VARCHAR AS circ_location_filter -- enter a Voyager circ desk location code, such as 'law,circ', 'math,circ', 'olin,circ', 'mann,circ' etc.
        
        -- Please note: After the start of the pandemic in Spring 2020, certain circ desk names were changed to show as contactless pickup locations in the OPAC. 
        -- For example, the display name for "mann,circ" was changed to "Mann Lobby"; "anx,circ" was changed to "Annex Main Entrance Foyer". 
        -- But the underlying "xxx,circ" location codes were the same.
),

data AS 
(SELECT 
        loc.location_name AS charge_location,
        pg.patron_group_name,
        it.item_type_name,
        CONCAT (cpm.loan_period, ' ', CASE WHEN cpm.loan_interval = 'D' THEN 'day' ELSE 'min' END) AS loan_period,
        
        CASE WHEN it.item_type_name::VARCHAR IN ('equipment','keys','umbrella','specloan') THEN 'equipment'
                WHEN it.item_type_name::VARCHAR = 'laptop' THEN 'laptop'
                WHEN cpm.loan_interval = 'M' THEN 'reserve'
                ELSE 'regular_collection'
                END AS collection_group,
        
        DATE_PART ('year', cta.charge_date) AS year_of_checkout,
        DATE_PART ('month', cta.charge_date) AS month_num,
        TO_CHAR (cta.charge_date,'Mon') AS "month",
        EXTRACT (dow FROM cta.charge_date) AS day_of_week_num,
        TO_CHAR (cta.charge_date,'Day') AS weekday,
        DATE_PART ('hour',cta.charge_date::timestamp) AS hour_num,
        TO_CHAR (cta.charge_date,'HH am') AS "hour",

CASE 
        WHEN DATE_PART ('month',(SELECT begin_date FROM filters)) < 7 THEN CONCAT ('Spring',' ', DATE_PART ('year',(SELECT begin_date FROM filters)+1)) 
        WHEN DATE_PART ('month',(SELECT begin_date FROM filters)) < 9 THEN CONCAT ('Summer',' ', DATE_PART ('year',(SELECT begin_date FROM filters)+1))
        ELSE concat ('Fall',' ', DATE_PART ('year',(SELECT begin_date FROM filters))) END AS semester,
        
COUNT (cta.circ_transaction_id) AS number_of_checkouts

FROM vger.circ_trans_archive AS cta 
        INNER JOIN vger.circ_policy_matrix AS cpm 
        ON cta.circ_policy_matrix_id = cpm.circ_policy_matrix_id
        
        INNER JOIN vger.patron_group AS pg 
        ON cpm.patron_group_id = pg.patron_group_id 
        
        INNER JOIN vger.item_type AS it 
        ON cpm.item_type_id = it.item_type_id 
        
        INNER JOIN vger.location AS loc 
        ON cta.charge_location = loc.location_id 

WHERE cta.charge_date::DATE >= (SELECT begin_date::DATE FROM filters) AND cta.charge_date::DATE <= (SELECT end_date::DATE FROM filters)
        AND loc.location_code = (SELECT circ_location_filter FROM filters)

GROUP BY 
        loc.location_name,
        pg.patron_group_name,
        it.item_type_name,
        cpm.loan_interval,
        cpm.loan_period,
        cta.charge_date
) 

SELECT 
        data.charge_location,
       data.semester,
        data.patron_group_name,
        data.item_type_name,
        data.loan_period,
        data.collection_group,
        data.year_of_checkout::VARCHAR,
        data.month_num,
        data."month",
        data.day_of_week_num,
        data.weekday,
        data.hour_num,
        data."hour",
        SUM (data.number_of_checkouts) AS total_checkouts
        
FROM data 

GROUP BY 
        data.charge_location,
        data.semester,
        data.patron_group_name,
        data.item_type_name,
        data.loan_period,
        data.collection_group,
        data.year_of_checkout::VARCHAR,
        data.month_num,
        data."month",
        data.day_of_week_num,
        data.weekday,
        data.hour_num,
        data."hour"
        
        
ORDER BY 
        patron_group_name, collection_group, year_of_checkout, month_num, day_of_week_num, hour_num
;
