USE AdventureWorks2016_EXT
GO

/********************************************************************************
*	Workload cleanup
********************************************************************************/

-- Delete sales order that is inserted in query examples section.
DELETE Sales.SalesOrder_json
WHERE SalesOrderID = 1

--	Cleanup indexes, views, and procedures
if( (select count(*) from sys.fulltext_indexes where object_id = object_id('Person.Person_json')) = 1)
begin
	print 'Dropping FT index on Person.Person_json'
	DROP FULLTEXT INDEX ON Person.Person_json
end
if( (select count(*) from sys.fulltext_indexes where object_id = object_id('Sales.SalesOrder_json')) = 1)
begin
	print 'Dropping FT index on Sales.SalesOrder_json'
	DROP FULLTEXT INDEX ON Sales.SalesOrder_json
end
if( (select count(*) from sys.fulltext_catalogs where name = 'jsonFullTextCatalog') = 1)
begin
	print 'Dropping FT catalog jsonFullTextCatalog'
	DROP FULLTEXT CATALOG jsonFullTextCatalog
end
go
-- Using new DROP IF EXISTS syntax for tables, views, indexes, procedures, and functions 
DROP INDEX IF EXISTS idx_SalesOrder_json_CustomerName ON Sales.SalesOrder_json
go
DROP PROCEDURE IF EXISTS Person.PersonList_json
go
DROP PROCEDURE IF EXISTS Person.PersonInfo_json
go
DROP PROCEDURE IF EXISTS Person.PersonInsert_json
go
DROP PROCEDURE IF EXISTS Person.PersonUpdate_json
go
DROP PROCEDURE IF EXISTS Person.PersonSearchByPhone_json
go
DROP PROCEDURE IF EXISTS Person.PersonSearchByPhoneNumberAndType_json
go
DROP PROCEDURE IF EXISTS Person.PersonSearchByEmail_json
go
DROP PROCEDURE IF EXISTS Person.PersonSearchByEmailAddressQuery_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderSearchByReason_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderSearchByReasonQuery_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderSearchByCustomer_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderList_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderInfo_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderInfoRel_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrdersBySalesReasonReport_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrdersPerCustomerAndStatusReport_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderExport_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderInsert_json
go
DROP PROCEDURE IF EXISTS Sales.SalesOrderUpdate_json
go
DROP VIEW IF EXISTS Sales.vwSalesOrderInfo_json
go
DROP VIEW IF EXISTS Sales.vwSalesOrderItems_json
go
DROP VIEW IF EXISTS Sales.vwSalesOrderInfo_json
go
DROP VIEW IF EXISTS Sales.vwSalesOrderInfo2_json
go
DROP VIEW IF EXISTS Sales.vwSalesOrderInfoRel_json
go
DROP FUNCTION IF EXISTS dbo.ufnToRawJsonArray
go
-- Drop JSON columns and constraints
GO
ALTER TABLE Sales.SalesOrder_json
DROP
	COLUMN IF EXISTS vCustomerName,
	CONSTRAINT IF EXISTS [SalesOrder reasons must be formatted as JSON array],
	COLUMN IF EXISTS SalesReasons,
	CONSTRAINT IF EXISTS [SalesOrder items must be formatted as JSON array],
	COLUMN IF EXISTS OrderItems,
	CONSTRAINT IF EXISTS [SalesOrder additional information must be formatted as JSON],
	COLUMN IF EXISTS Info
	
GO
ALTER TABLE Person.Person_json
DROP
	CONSTRAINT IF EXISTS [Phone numbers must be formatted as JSON array],
	COLUMN IF EXISTS PhoneNumbers,
	CONSTRAINT IF EXISTS [Email addresses must be formatted as JSON array],
	COLUMN IF EXISTS EmailAddresses
GO