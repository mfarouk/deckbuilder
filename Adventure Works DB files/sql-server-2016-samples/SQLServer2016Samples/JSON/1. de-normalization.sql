USE AdventureWorks2016_EXT
GO
/********************************************************************************
*	SCENARIO 1 – De-normalization.
*	Steps
*	1.1. Create utility function.
*	1.2. Simplify database structure
*	1.2.1. De-normalize Person table
*	1.2.1. De-normalize SalesOrder table
********************************************************************************/

/*******************************************************************************
* Step 1.1. Create utility function.
* Utility function that removes keys from JSON
* Used when we need to remove keys from FOR JSON output, 
* e.g. to generate [1,2,"cell"] format instead of [{"val":1,{"val":2},{"val":"cell"}] 
********************************************************************************/

DROP FUNCTION IF EXISTS dbo.ufnToRawJsonArray
GO
CREATE FUNCTION
dbo.ufnToRawJsonArray(@json nvarchar(max), @key nvarchar(400)) returns nvarchar(max)
as begin
	return replace(replace(@json, FORMATMESSAGE('{"%s":', @key),''), '}','')
end
go




/*******************************************************************************
* Step 1.2.1. De-normalize Person/Person related tables
* 1. Create PhoneNumbers JSON column and populate it with content of PersonPhone/PersonPhoneType tables 
* 2. Create EmailAddresses JSON column and populate it with content of EmailAddress table
********************************************************************************/

-- Create additional JSON column that will contain an array of phone numbers and types.
ALTER TABLE Person.Person_json
ADD PhoneNumbers NVARCHAR(MAX)
	CONSTRAINT [Phone numbers must be formatted as JSON array]
		CHECK (ISJSON(PhoneNumbers)>0)
GO

-- Populate PersonInfo from PersonPhone/PhoneNumberType tables using FOR JSON
UPDATE Person.Person_json
SET PhoneNumbers = (SELECT Person.PersonPhone.PhoneNumber, Person.PhoneNumberType.Name AS PhoneNumberType
					FROM  Person.PersonPhone
						INNER JOIN Person.PhoneNumberType ON Person.PersonPhone.PhoneNumberTypeID = Person.PhoneNumberType.PhoneNumberTypeID
					WHERE Person.Person_json.PersonID = Person.PersonPhone.BusinessEntityID
					FOR JSON PATH) 
GO

-- Create additional JSON column that will contain an array of phone numbers.
ALTER TABLE Person.Person_json
ADD EmailAddresses NVARCHAR(MAX)
	CONSTRAINT [Email addresses must be formatted as JSON array]
		CHECK (ISJSON(EmailAddresses)>0)
GO

-- Populate EmailAddresses JSON column from EmailAddress using FOR JSON
UPDATE Person.Person_json
SET EmailAddresses = 
			dbo.ufnToRawJsonArray(
					(SELECT Person.EmailAddress.EmailAddress
						FROM Person.EmailAddress
						WHERE Person.Person_json.PersonID = Person.EmailAddress.BusinessEntityID
						FOR JSON PATH)
					, 'EmailAddress')

/*******************************************************************************
* Step 1.2.2. De-normalize SalesOrder table structure
* 1. Create SalesReasons JSON column and populate it with content of SalesOrderHeaderSalesReason/SalesReason tables 
* 2. Create OrderItems JSON column and populate it with content of SalesOrderDetail and Product tables
* 3. Create Info JSON column and populate it with content of various tables related to SalesOrder table
********************************************************************************/

-- Create SalesReasons JSON column that will contain an array of sales reason strings.
ALTER TABLE Sales.SalesOrder_json
ADD	SalesReasons NVARCHAR(MAX)
		CONSTRAINT [SalesOrder reasons must be formatted as JSON array]
			CHECK (ISJSON(SalesReasons)>0)
GO

-- Populate SalesReasons JSON column from SalesOrderHeaderSalesReason/SalesReason tables using FOR JSON
UPDATE Sales.SalesOrder_json
SET SalesReasons = 
	dbo.ufnToRawJsonArray(
			(SELECT SalesReason.Name
				FROM Sales.SalesOrderHeaderSalesReason
					JOIN Sales.SalesReason
						ON Sales.SalesOrderHeaderSalesReason.SalesReasonID = Sales.SalesReason.SalesReasonID
				WHERE Sales.SalesOrder_json.SalesOrderID = Sales.SalesOrderHeaderSalesReason.SalesOrderID
			FOR JSON PATH)
			, 'Name')

-- Note: We don't have FOR JSON clause that returns simple arrays (i.e. only values without keys)
-- Therefore, we need to use a custom UDF (dbo.ufnToRawJsonArray) to remove keys from the array.
GO
-- Create JSON column that will contain an array of sales order items
ALTER TABLE Sales.SalesOrder_json
ADD OrderItems NVARCHAR(MAX)
	CONSTRAINT [SalesOrder items must be formatted as JSON array]
		CHECK (ISJSON(OrderItems)>0)
GO
-- Move all sales order items from the SalesOrderDetails table into OrderItems column
-- Populate OrderItems column using SalesOrderDetails table and FOR JSON.
-- Note: We will group properties in Item and Product JSON objects using dot notation in column aliases.
UPDATE Sales.SalesOrder_json
SET OrderItems = (SELECT CarrierTrackingNumber,
						OrderQty as [Item.Qty], UnitPrice as [Item.Price],
						UnitPriceDiscount as [Item.Discount], LineTotal as [Item.Total],
						ProductNumber as [Product.Number], Name as [Product.Name]
					FROM  Sales.SalesOrderDetail 
						JOIN Production.Product
						 ON Sales.SalesOrderDetail.ProductID = Production.Product.ProductID
					WHERE Sales.SalesOrderDetail.SalesOrderID = Sales.SalesOrder_json.SalesOrderID
					FOR JSON PATH)
GO
-- Create Info column that will contain various information about sales order.
ALTER TABLE Sales.SalesOrder_json
ADD Info NVARCHAR(MAX)
	CONSTRAINT [SalesOrder additional information must be formatted as JSON]
		CHECK (ISJSON(Info)>0)
GO
-- Populate info column.
UPDATE Sales.SalesOrder_json
SET Info = (
		SELECT
			shipaddr.AddressLine1 + COALESCE ( ', ' + shipaddr.AddressLine2, '') as [ShippingInfo.Address], shipaddr.City as [ShippingInfo.City], shipaddr.PostalCode as [ShippingInfo.PostalCode],
			shipprovince.Name as [ShippingInfo.Province], shipprovince.TerritoryID as [ShippingInfo.TerritoryID],
				shipmethod.Name as [ShippingInfo.Method], shipmethod.ShipBase as [ShippingInfo.ShipBase], shipmethod.ShipRate as [ShippingInfo.ShipRate],
			billaddr.AddressLine1 + COALESCE ( ', ' + shipaddr.AddressLine2, '') as [BillingInfo.Address], billaddr.City as [BillingInfo.City], billaddr.PostalCode as [BillingInfo.PostalCode],
			sp.FirstName + ' ' +  sp.LastName as [SalesPerson.Name], sp.BusinessEntityID AS [SalesPerson.ID],
			cust.FirstName + ' ' + cust.LastName as [Customer.Name], cust.BusinessEntityID AS [Customer.ID]					
			FOR JSON PATH)
FROM Sales.SalesOrder_json
	JOIN Person.Address shipaddr
		ON Sales.SalesOrder_json.ShipToAddressID = shipaddr.AddressID
			LEFT JOIN Person.StateProvince shipprovince
				ON shipaddr.StateProvinceID = shipprovince.StateProvinceID
	JOIN Purchasing.ShipMethod shipmethod
		ON Sales.SalesOrder_json.ShipMethodID = shipmethod.ShipMethodID
	JOIN Person.Address billaddr
		ON Sales.SalesOrder_json.BillToAddressID = billaddr.AddressID
	LEFT JOIN Sales.SalesPerson
		ON Sales.SalesPerson.BusinessEntityID = Sales.SalesOrder_json.SalesPersonID
		LEFT JOIN Person.Person AS sp
			ON Sales.SalesPerson.BusinessEntityID = sp.BusinessEntityID
	LEFT JOIN Sales.Customer
		ON Sales.Customer.CustomerID = Sales.SalesOrder_json.CustomerID
		LEFT JOIN Person.Person AS cust
			ON Sales.Customer.CustomerID = cust.BusinessEntityID
GO