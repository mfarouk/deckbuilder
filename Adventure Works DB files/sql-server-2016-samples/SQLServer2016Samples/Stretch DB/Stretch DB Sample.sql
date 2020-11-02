-------------------------------------------------------------------------------
-- AdventureWorks2016_EXT samples: Stretch DB
-------------------------------------------------------------------------------
/*
   This demo explores how to use Stretch Database with the following tables and 
   stored procedures in the AdventureWorks2016_EXT sample database.
      
   tables:
      Sales.OrderTracking 
      Sales.TrackingEvent 
   
   stored procedures:
      uspAddOrderTrackingEvent
      uspGetOrderTrackingByTrackingNumber
      uspGetOrderTrackingBySalesOrderID

*/
--USE AdventureWorks2016_EXT
GO

-------------------------------------------------------------------------------
-- Before stretching the Sales.OrderTracking table in the AdventureWorks2016_EXT database
--    1. Execute sp_SpaceUsed to view amount of data stored in Sales.OrderTracking.  
-------------------------------------------------------------------------------
EXEC sp_spaceused 'Sales.OrderTracking';

-------------------------------------------------------------------------------
-- You will run this query and the following query again after you enable 
-- Stretch Database to demonstrate that queries continue to work unchanged after 
-- data migration.
--    2. Execute uspGetOrderTrackingBySalesOrderID to retrieve tracking events for a 
--       given SalesOrderID in the Sales.OrderTracking table
-------------------------------------------------------------------------------
DECLARE @SalesOrderID   INT;

   SET @SalesOrderID = (SELECT MAX(ot.SalesOrderID) FROM Sales.OrderTracking ot);
   EXEC uspGetOrderTrackingBySalesOrderID @SalesOrderID;
GO

-------------------------------------------------------------------------------
--    3. Execute uspGetOrderTrackingByTrackingNumber to retrieve tracking events for a 
--       given CarrierTrackingNumber in the Sales.OrderTracking table
-------------------------------------------------------------------------------
DECLARE @TrackingNumber NVARCHAR(25);

SET @TrackingNumber = (
   SELECT TOP 1 ot.CarrierTrackingNumber
     FROM Sales.OrderTracking ot
    WHERE ot.SalesOrderID = (SELECT MAX(SalesOrderID) FROM Sales.OrderTracking));

EXEC uspGetOrderTrackingByTrackingNumber @TrackingNumber;
GO

-------------------------------------------------------------------------------
--    4. Next:  Stretch the Sales.OrderTracking table
--       This can be done using Microsoft SQL Server Management Studio:
--       - Connect to your AdventureWorks2016 database
--       - In the object explorer window, find and select the Sales.OrderTracking table.
--       - Right click on the Sales.OrderTracking and select the Stretch/Enable
--          menu option to launch the 'Enable Database for Stretch' wizard
--       - Follow the guided instructions in the wizard to enable and configure
--         Sales.OrderTracking for stretch to Azure.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--    5. Once stretch configuration is complete and data migration has begun
--       you can monitor the progress of data migration via the wizard or by
--       executing a query from sys.dm_db_rda_migration.
-------------------------------------------------------------------------------
SELECT * FROM sys.dm_db_rda_migration_status;
GO

-------------------------------------------------------------------------------
--    6. You can view local and remote data storage by running sp_spaceused
--       with the 'LOCAL_ONLY', 'REMOTE_ONLY' & 'ALL' parameters as follows
-------------------------------------------------------------------------------
EXEC sp_spaceused 'Sales.OrderTracking', 'true', 'LOCAL_ONLY';
EXEC sp_spaceused 'Sales.OrderTracking', 'true', 'REMOTE_ONLY';
EXEC sp_spaceused 'Sales.OrderTracking', 'true', 'ALL';
GO

-------------------------------------------------------------------------------
--    7. While migration is in progress or complete, you can continue to insert
--       new records into Sales.OrderTracking as before
-------------------------------------------------------------------------------
DECLARE @SalesOrderID   INT,
        @TrackingNumber NVARCHAR(25);

SET @SalesOrderID = (
   SELECT MAX(ot.SalesOrderID) 
     FROM Sales.OrderTracking ot);

SET @TrackingNumber = (
   SELECT TOP 1 ot.CarrierTrackingNumber
     FROM Sales.OrderTracking ot
    WHERE ot.SalesOrderID = @SalesOrderID);

EXEC dbo.uspGetOrderTrackingBySalesOrderID @SalesOrderID
EXEC dbo.uspGetOrderTrackingByTrackingNumber @TrackingNumber

EXEC dbo.uspAddOrderTrackingEvent @SalesOrderID, 7, 'invalid address, package is undeleverable'

GO

-------------------------------------------------------------------------------
--    8. While migration is in progress or complete, you can also continue to
--       query tracking events as before
-------------------------------------------------------------------------------
DECLARE @SalesOrderID   INT,
        @TrackingNumber NVARCHAR(25);

SET @SalesOrderID = (
   SELECT MAX(ot.SalesOrderID) 
     FROM Sales.OrderTracking ot);

SET @TrackingNumber = (
   SELECT TOP 1 ot.CarrierTrackingNumber
     FROM Sales.OrderTracking ot
    WHERE ot.SalesOrderID = @SalesOrderID);

EXEC dbo.uspGetOrderTrackingBySalesOrderID @SalesOrderID;
EXEC dbo.uspGetOrderTrackingByTrackingNumber @TrackingNumber;

GO