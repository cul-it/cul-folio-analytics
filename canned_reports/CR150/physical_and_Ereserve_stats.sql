WITH loans AS 

(SELECT 
                jls.itembarcode,
                count(li.loan_id) AS total_checkouts
        
        FROM local.jl_spring_2022 as jls
                LEFT JOIN folio_reporting.loans_items AS li  
                ON jls.itembarcode = li.barcode
        
        WHERE (li.item_effective_location_name_at_check_out LIKE '%eserve%'
                AND li.loan_date >= '2021-11-18')
                OR li.loan_id IS NULL
        
        GROUP BY
                jls.itembarcode
        
        ORDER BY jls.itembarcode
        )

        
SELECT distinct
        to_char(current_date::DATE,'mm/dd/yyyy') as todays_date,
        jls.semester,
        jls.processinglocation,
        jls.pickuplocation,
        jls.courseid,
        jls.itemid,
        jls.currentstatus,
        jls.currentstatusdate,
        jls.deptfinal,
        jls.coursenumber,
        jls."Course Title",
        jls.instructordisplayname,
        jls.itembarcode,
        jls.url,
        jls."Item Title",
        jls.author,
        jls.publisher,
        jls.itemtype,
        jls.itemformat,
        jls.documenttype,
        jls."Type of Reserve",
        jls.shelflocation,
        jls.callnumber,
        jls.articletitle,
        jls.volume,
        jls.issue,
        jls.journalyear,
        jls.journalmonth,
        jls.pages,
        CASE WHEN loans.total_checkouts IS NULL THEN '0' ELSE total_checkouts END AS total_checkouts,
        jls."Number of Users",
        jls."Total Clicks"
        
FROM 
        local.jl_spring_2022 AS jls
                
        LEFT JOIN loans  
        ON jls.itembarcode = loans.itembarcode
                
ORDER BY pickuplocation, processinglocation, deptfinal, coursenumber, instructordisplayname, "Item Title", callnumber, articletitle
;
