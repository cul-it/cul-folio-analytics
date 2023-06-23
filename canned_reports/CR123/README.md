# CR123 Open Orders

This query provides a list of purchase orders with the workflow status "Open" showing the amount paid broken down by purchase order lines. 
Users can use multiple filters to narrow down their search by using parameters filters, located at the top of the query.

It is important to note that the transaction amount will differ from the invoice line sub-total amount when an adjustment is made at the invoice level. The invoice line amount is capturing the payments made on deposit accounts where the transaction amount would be $0. 

In addition, open orders without transactions are not associated with a fiscal year. If you select a fiscal year when you run
this query, it will only show open orders with transactions. To show ALL open orders, do not enter a fiscal year in the fiscal
year code parameter at the top of the query.

This report excludes any invoice line data not attached to a purchase order line and adjustments made at the invoice level.

This report does not show encumbrances on purchase orders. If you are looking for open/current encumbrances, please use CR213. 
