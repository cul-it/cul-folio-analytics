# CR123 Open Orders

This query provides a list of open purchase orders and their encumbrance and/or amount paid, broken down by purchase order lines. 
Users can use multiple filters to narrow down their search by using parameters filters, located at the top of the query.

It is important to note that the transaction amount will differ from the invoice line sub-total amount when an adjustment is made at the invoice level. The invoice line amount is capturing the payments made on deposit accounts where the transaction amount would be $0. 

In addition, open orders without transactions do not show fiscal year, so all open orders will only show if a fiscal year code is not included in the fiscal_year_code parameter at the top of the query.

This report excludes any invoice line data not attached to a purchase order line and adjustments made at the invoice level.


