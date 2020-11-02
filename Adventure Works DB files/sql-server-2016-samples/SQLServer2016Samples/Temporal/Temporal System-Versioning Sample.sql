----------------------------------------------------------------
-- AdventureWorks2016_EXT samples: Temporal System-Versioning
----------------------------------------------------------------

/*
	This demo uses two system-versioned temporal tables from AdventureWorks2016_EXT: 
	Person.Person_Temporal and HumanResources.Employee_Temporal
	This script includes query examples for the following scenarios:
	1) examining temporal tables by querying metadata
	2) modifying temporal data by using provided stored procedures
	3) running different temporal querying
	4) using historical data to recover from unwanted data change
	5) using ALTER TABLE to add, alter and modify columns
	6) converting non-temporal table into system-versioned temporal
	7) cleanup of temporarily created [Sales].[SalesPerson_Temporal] table
	
	It is recommended to execute scenario related batches one by one.
	If you want to reset example data run again Temporal\Temporal Setup.sql, located in the same folder
*/

USE AdventureWorks2016_EXT;
GO

----------------------------------------------------------------
-- PART 1: Review metadata for temporal tables
----------------------------------------------------------------
/* This query returns all temporal tables and their correlated history tables */
 SELECT T1.object_id, T1.name as TemporalTableName, SCHEMA_NAME(T1.schema_id) AS TemporalTableSchema,
 T2.name as HistoryTableName, SCHEMA_NAME(T2.schema_id) AS HistoryTableSchema,
 T1.temporal_type_desc
 FROM sys.tables T1
 LEFT JOIN sys.tables T2 
 ON T1.history_table_id = T2.object_id
 WHERE T1.temporal_type <> 0
 ORDER BY T1.temporal_type desc;

 ----------------------------------------------------------------
-- PART 2: Run data modification statements
-- on Person.Person_Temporal and HumanResources.Employee_Temporal
-----------------------------------------------------------------

/* Set VacationHours and SickLeaveHours to 0 for all Employees */
UPDATE [HumanResources].[Employee_Temporal] 
SET VacationHours = 0, SickLeaveHours = 0;

/* Run [Person].[sp_UpdatePerson_Temporal] to update Person properties for BusinessEntityID = 2 */
EXECUTE [Person].[sp_UpdatePerson_Temporal] 
   2,    --@BusinessEntityID
   NULL, --@PersonType, ignored if NULL
   'Mr'  --@Title
 
WAITFOR DELAY '00:00:02';

/* Run [Person].[sp_UpdatePerson_Temporal] to update Person properties for BusinessEntityID = 8 */
EXECUTE [Person].[sp_UpdatePerson_Temporal] 
   8,    --@BusinessEntityID
   NULL, --@PersonType, ignored if NULL
   'Mrs' --@Title

WAITFOR DELAY '00:00:01';
 
/* Run [Person].[sp_UpdatePerson_Temporal] to update Person properties for BusinessEntityID = 15 */ 
EXECUTE [Person].[sp_UpdatePerson_Temporal] 
   15,   --@BusinessEntityID
   NULL, --@PersonType, ignored if NULL
   'Mrs' --@Title

WAITFOR DELAY '00:00:01';

/*	Run [HumanResources].[sp_UpdateEmployee_Temporal]  to update Employee properties for BusinessEntityID = 2 */
EXECUTE [HumanResources].[sp_UpdateEmployee_Temporal] 
   2 --BusinessEntityID
  ,NULL--@LoginID
  ,NULL--@JobTitle
  ,'M'--@MaritalStatus  
GO
WAITFOR DELAY '00:00:01';

-----------------------------------------------------------------
-- PART 3: Run temporal queries
-----------------------------------------------------------------

/*
	Run temporal query with FOR SYSTEM_TIME ALL
	to get all  versions for recently updated rows 
*/
SELECT IIF(Year(ValidTo) = 9999, 1,0) AS IsCurrentVersion, *, 
ValidFrom, ValidTo FROM [Person].[Person_Temporal]
FOR SYSTEM_TIME ALL
WHERE BusinessEntityID IN (2, 8, 15)
ORDER BY BusinessEntityID, ValidFrom DESC;

/*
	Run temporal query with FOR SYSTEM_TIME BETWEEN..AND 
	to get all  versions for recently updated row.
	Check the value of MaritalStatus column for BusinessEntityID  = 2 to observe changes
*/
SELECT *, ValidFrom, ValidTo FROM [HumanResources].[Employee_Temporal]
FOR SYSTEM_TIME BETWEEN '2015.01.01' AND '2016.12.31'
WHERE BusinessEntityID IN (2)
ORDER BY BusinessEntityID, ValidFrom DESC;

/*
	Analyze data change by comparing view state a minute ago and now
	Query demontrates how temporal clause is applied to view 
	[HumanResources].[vEmployeePersonTemporalInfo]
	If you want to go further in history change expression 
	SET @fromTime = DATEADD (minute, -1, @fromTime)
*/
DECLARE @now datetime2 = sysutcdatetime()
DECLARE @fromTime datetime2
SET @fromTime = DATEADD (minute, -1, @now)


SELECT * FROM [HumanResources].[vEmployeePersonTemporalInfo]
EXCEPT 
SELECT * FROM [HumanResources].[vEmployeePersonTemporalInfo]
FOR SYSTEM_TIME AS OF @fromTime

/*Query historical data only by using CONTAINED IN */
SELECT * FROM [HumanResources].[vEmployeePersonTemporalInfo]
FOR SYSTEM_TIME CONTAINED IN (@fromTime, @now);

----------------------------------------------------------------
-- PART 4: Recover from unwanted data changes (deletes)
----------------------------------------------------------------

/* Delete rows from [Person].[Person_Temporal] and [Person].[PersonPhone_Temporal] */
EXEC [Person].[sp_DeletePerson_Temporal] 2


/*Verify that row doesn't exist in current data*/
SELECT * FROM [HumanResources].[vEmployeePersonTemporalInfo]
WHERE BusinessEntityID = 2;

/*Recover deleted rows by getting latest change from the history  for both tables */
BEGIN TRAN
	INSERT INTO [HumanResources].[Employee_Temporal]
	(
	   [BusinessEntityID]
      ,[NationalIDNumber]
      ,[LoginID]
      ,[OrganizationNode]      
      ,[JobTitle]
      ,[BirthDate]
      ,[MaritalStatus]
      ,[Gender]
      ,[HireDate]
      ,[VacationHours]
      ,[SickLeaveHours]
	)
	
	SELECT TOP 1  
	   [BusinessEntityID]
      ,[NationalIDNumber]
      ,[LoginID]
      ,[OrganizationNode]      
      ,[JobTitle]
      ,[BirthDate]
      ,[MaritalStatus]
      ,[Gender]
      ,[HireDate]
      ,[VacationHours]
      ,[SickLeaveHours]
	FROM [HumanResources].[Employee_Temporal]
	FOR SYSTEM_TIME ALL
	WHERE BusinessEntityID = 2 and YEAR(ValidTo) < 9999
	ORDER BY [ValidTo] DESC

	INSERT INTO [Person].[Person_Temporal]
	([BusinessEntityID]
		  ,[PersonType]
		  ,[NameStyle]
		  ,[Title]
		  ,[FirstName]
		  ,[MiddleName]
		  ,[LastName]
		  ,[Suffix]
		  ,[EmailPromotion]
	)
	SELECT TOP 1 [BusinessEntityID]
		  ,[PersonType]
		  ,[NameStyle]
		  ,[Title]
		  ,[FirstName]
		  ,[MiddleName]
		  ,[LastName]
		  ,[Suffix]
		  ,[EmailPromotion]
	FROM [Person].[Person_Temporal]
	FOR SYSTEM_TIME ALL
	WHERE BusinessEntityID = 2 and YEAR(ValidTo) < 9999
	ORDER BY [ValidTo] DESC ;

COMMIT

/*Check that data has been recovered sucessfuly*/
SELECT * FROM [HumanResources].[vEmployeePersonTemporalInfo]
WHERE BusinessEntityID = 2

----------------------------------------------------------------
-- PART 5: Use ALTER TABLE to simply ADD/ALTER/DROP a column
----------------------------------------------------------------

/* Add a new column (schema change will be transparently propagated to history) */
ALTER TABLE [Person].[Person_Temporal]
	ADD YearOfBirth DATE NULL;
GO

/*Remove HIDDEN flag for period columns*/
ALTER TABLE [Person].[Person_Temporal]
ALTER COLUMN ValidFrom DROP HIDDEN;
ALTER TABLE [Person].[Person_Temporal]
ALTER COLUMN ValidTo DROP HIDDEN;
GO

/*Verify that new columns is present and than period columns are not implicitly hidden*/
SELECT * FROM [Person].[Person_Temporal]
FOR SYSTEM_TIME ALL
ORDER BY [BusinessEntityID], ValidFrom;

/*Cleanup: remove added column*/
ALTER TABLE [Person].[Person_Temporal]
	DROP COLUMN  YearOfBirth;
GO

/*Restore  HIDDEN flag for period columns*/
ALTER TABLE [Person].[Person_Temporal]
ALTER COLUMN ValidFrom ADD HIDDEN;
ALTER TABLE [Person].[Person_Temporal]
ALTER COLUMN ValidTo ADD HIDDEN;
GO

/*Verify cleanup*/
SELECT * FROM [Person].[Person_Temporal]
FOR SYSTEM_TIME ALL
ORDER BY [BusinessEntityID], ValidFrom;

----------------------------------------------------------------
-- PART 6: Add versioning to a non-temporal table
----------------------------------------------------------------

/*Drop if exists, create and populate new table [Sales].[SalesPerson_Temporal]*/
IF EXISTS (SELECT * FROM sys.tables
WHERE [Name] = 'SalesPerson_Temporal' AND temporal_type = 2)
	ALTER TABLE [Sales].[SalesPerson_Temporal] SET (SYSTEM_VERSIONING = OFF);

DROP TABLE IF EXISTS [Sales].[SalesPerson_Temporal];
DROP TABLE IF EXISTS [Sales].[SalesPerson_Temporal_History];

SELECT TOP 10 [BusinessEntityID],[TerritoryID],[SalesQuota],[Bonus],[CommissionPct],[SalesYTD]
,[SalesLastYear] INTO [Sales].[SalesPerson_Temporal]
FROM [Sales].[SalesPerson];

GO

/*Temporal table must have primary key*/
ALTER TABLE [Sales].[SalesPerson_Temporal]
ADD CONSTRAINT PK_SalesPerson_Temporal PRIMARY KEY CLUSTERED (BusinessEntityID);

GO


/*Add period columns*/
ALTER TABLE [Sales].[SalesPerson_Temporal]
	 ADD SysStartTime datetime2(0) GENERATED ALWAYS AS ROW START HIDDEN 
         CONSTRAINT DF_SysStart DEFAULT DATEADD(second, -1, SYSUTCDATETIME()),
	 SysEndTime datetime2(0) GENERATED ALWAYS AS ROW END HIDDEN 
         CONSTRAINT DF_SysEnd DEFAULT CONVERT(datetime2 (0), '9999-12-31 23:59:59'),
	 PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime);
GO


/*Generate default history table*/
ALTER TABLE [Sales].[SalesPerson_Temporal]
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = [Sales].[SalesPerson_Temporal_History]));

GO

/*Query full history for newly created table*/
SELECT * FROM [Sales].[SalesPerson_Temporal]
FOR SYSTEM_TIME ALL;

----------------------------------------------------------------
-- PART 7: Cleanup of [Sales].[SalesPerson_Temporal];
----------------------------------------------------------------
/*Cleanup (run after verification)*/
ALTER TABLE [Sales].[SalesPerson_Temporal] SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS [Sales].[SalesPerson_Temporal];
DROP TABLE IF EXISTS [Sales].[SalesPerson_Temporal_History];










