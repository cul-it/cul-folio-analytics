WITH barcodes AS 
(SELECT 
        bc1,
        bc2,
        concat(bc1,bc2) as full_barcode
        
FROM local.jl_physical_reserve_barcodes_fall
        ),

loans AS (
        SELECT 
                barcodes.full_barcode,
                count(li.loan_id) AS total_reserve_loans
        
        FROM barcodes 
                LEFT JOIN folio_reporting.loans_items AS li  
                ON barcodes.full_barcode = li.barcode
        
        WHERE (li.item_effective_location_name_at_check_out LIKE '%eserve%'
                        AND li.loan_date >= '2021-05-09'
                        AND li.loan_policy_name NOT LIKE '%month%'
                        AND li.loan_policy_name NOT LIKE '%year%')
                        OR li.loan_id IS NULL
        
        GROUP BY
                barcodes.full_barcode
        
        ORDER BY barcodes.full_barcode
        ),

alldata AS (
        SELECT *,
                concat(jl_fall.bc1, jl_fall.bc2) as alldata_barcode 
        
        FROM local.jl_fall)

--main query--
SELECT 
                alldata.semester,
                alldata.pickuplocation,
                alldata.processinglocation,
                alldata.courseid,
                alldata.itemid,
                alldata.currentstatus,
                alldata.currentstatusdate,
                alldata.deptfinal,
                alldata.coursenumber,
                alldata."Course Title",
                alldata.instructordisplayname,
                --alldata.instructor,
                --alldata.bc1,
                --alldata.bc2,
                alldata.url,
                --alldata.etas,
                alldata."Item Title",
                alldata.author,
                alldata.publisher,
                alldata.itemtype,
                alldata.itemformat,
                alldata.documenttype,
                alldata."Type of Reserve",
                alldata.shelflocation,
                alldata.callnumber,
                alldata.alldata_barcode,
                alldata.articletitle,
                alldata.volume,
                alldata.issue,
                alldata.journalyear,
                alldata.journalmonth,
                alldata.pages,
                CASE WHEN loans.full_barcode IS NULL THEN '0' else loans.total_reserve_loans END AS total_checkouts,
                CASE WHEN alldata."Total Clicks" = '9999' THEN '0' ELSE alldata."Total Clicks" END AS total_clicks,
                alldata."Number of Users"
                
FROM alldata
        LEFT JOIN barcodes
        ON alldata.alldata_barcode = barcodes.full_barcode
        
        LEFT JOIN loans 
        ON alldata.alldata_barcode = loans.full_barcode
        
ORDER BY pickuplocation, deptfinal, coursenumber, alldata."Item Title", barcodes.full_barcode
;
