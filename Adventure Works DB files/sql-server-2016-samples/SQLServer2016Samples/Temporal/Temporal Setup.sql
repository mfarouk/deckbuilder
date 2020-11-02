/*
	AdventureWorks2016_EXT Temporal System-Versioning samples: Setup
*/

USE [AdventureWorks2016_EXT]
GO

/*
	If Temporal system-versioned tables already exist, firts drop versioning
*/

IF EXISTS (SELECT * FROM sys.tables
WHERE [Name] = 'Employee_Temporal' AND temporal_type = 2)
	ALTER TABLE [HumanResources].[Employee_Temporal] SET (SYSTEM_VERSIONING = OFF);

IF EXISTS (SELECT * FROM sys.tables
WHERE [Name] = 'Person_Temporal' AND temporal_type = 2)
	ALTER TABLE [Person].[Person_Temporal] SET (SYSTEM_VERSIONING = OFF);

/*
	Drop all objects from the sample if  exist:
		view
		stored procedures
		tables
*/
DROP VIEW IF EXISTS [HumanResources].[vEmployeePersonTemporalInfo];

DROP PROCEDURE IF EXISTS [Person].[sp_UpdatePerson_Temporal];
DROP PROCEDURE IF EXISTS [Person].[sp_DeletePerson_Temporal];
DROP PROCEDURE IF EXISTS [HumanResources].[sp_UpdateEmployee_Temporal];
DROP PROCEDURE IF EXISTS [HumanResources].[sp_GetEmployee_Person_Info_AsOf]

DROP TABLE IF EXISTS [HumanResources].[Employee_Temporal];
DROP TABLE IF EXISTS [HumanResources].[Employee_Temporal_History];

DROP TABLE IF EXISTS [Person].[Person_Temporal];
DROP TABLE IF EXISTS [Person].[Person_Temporal_History];

/*
	Table [Person].[Person_Temporal] with schema similar to [Person].[Person]
*/
CREATE TABLE [Person].[Person_Temporal](
	[BusinessEntityID] [int] NOT NULL,
	[PersonType] [nchar](2) NOT NULL,
	[NameStyle] [dbo].[NameStyle] NOT NULL,
	[Title] [nvarchar](8) NULL,
	[FirstName] [dbo].[Name] NOT NULL,
	[MiddleName] [dbo].[Name] NULL,
	[LastName] [dbo].[Name] NOT NULL,
	[Suffix] [nvarchar](10) NULL,
	[EmailPromotion] [int] NOT NULL,

	CONSTRAINT [PK_Person_Temporal_BusinessEntityID] PRIMARY KEY CLUSTERED 
	(
		[BusinessEntityID] ASC
	),

	ValidFrom datetime2(7) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
	ValidTo datetime2(7) GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
	PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
) 
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = [Person].[Person_Temporal_History]));

CREATE TABLE [HumanResources].[Employee_Temporal](
	[BusinessEntityID] [int] NOT NULL,
	[NationalIDNumber] [nvarchar](15) NOT NULL,
	[LoginID] [nvarchar](256) NOT NULL,
	[OrganizationNode] [hierarchyid] NULL,
	[OrganizationLevel]  AS ([OrganizationNode].[GetLevel]()),
	[JobTitle] [nvarchar](50) NOT NULL,
	[BirthDate] [date] NOT NULL,
	[MaritalStatus] [nchar](1) NOT NULL,
	[Gender] [nchar](1) NOT NULL,
	[HireDate] [date] NOT NULL,
	[VacationHours] [smallint] NOT NULL,
	[SickLeaveHours] [smallint] NOT NULL,
	
	CONSTRAINT [PK_Employee_History_BusinessEntityID] PRIMARY KEY CLUSTERED 
	(
		[BusinessEntityID] ASC
	),
	
	ValidFrom datetime2(7) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
	ValidTo datetime2(7) GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
	PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = [HumanResources].[Employee_Temporal_History]));

GO

/*
	View that joins [Person].[Person_Temporal] [HumanResources].[Employee_Temporal]
	This view can be later used in temporal querying which is extremely flexible and convenient
	given that participating tables are temporal and can be changed independently
*/
CREATE VIEW [HumanResources].[vEmployeePersonTemporalInfo]
AS
SELECT P.BusinessEntityID, P.Title, P. FirstName, P.LastName, P.MiddleName
, E.JobTitle, E.MaritalStatus, E.Gender, E.VacationHours, E.SickLeaveHours
FROM [Person].Person_Temporal P
JOIN  [HumanResources].[Employee_Temporal] E
ON P.[BusinessEntityID] = E.[BusinessEntityID]

GO

/*
	Stored procedure for updating columns of Person_Temporal
	If all parameters except @BusinessEntityID are NULL no update is performed 
	For NON NULL columns NULL values are ignored (i.e. existing values is applied)
*/
CREATE PROCEDURE [Person].[sp_UpdatePerson_Temporal]
@BusinessEntityID INT,
@PersonType nchar(2) = NULL,
@Title nvarchar(8) = NULL,
@FirstName nvarchar(50) = NULL,
@MiddleName nvarchar(50) = NULL,
@LastName nvarchar(50) = NULL,
@Suffix nvarchar(10) = NULL,
@EmailPromotion smallint = NULL

AS

IF @PersonType IS NOT NULL OR @Title IS NOT NULL OR @FirstName IS NOT NULL OR @MiddleName IS NOT NULL
OR @LastName IS NOT NULL OR @Suffix IS NOT NULL OR @EmailPromotion IS NOT NULL 

	UPDATE Person.Person_Temporal
	SET PersonType = ISNULL (@PersonType, PersonType),
	Title = @Title,
	FirstName = ISNULL (@FirstName, FirstName),
	MiddleName = ISNULL (@MiddleName, MiddleName),
	LastName = ISNULL (@LastName, LastName),
	Suffix = @Suffix,
	EmailPromotion = ISNULL(@EmailPromotion, EmailPromotion)
	WHERE BusinessEntityID = @BusinessEntityID;
	
GO 

/*
	Stored procedure that deletes row in [Person].[Person_Temporal]
	and corresponding row in [HumanResources].[Employee_Temporal]
*/
CREATE PROCEDURE [Person].[sp_DeletePerson_Temporal]
@BusinessEntityID INT
AS

DELETE FROM [HumanResources].[Employee_Temporal] WHERE [BusinessEntityID] = @BusinessEntityID;
DELETE FROM [Person].[Person_Temporal] WHERE [BusinessEntityID] = @BusinessEntityID;

GO

/*
	Stored procedure for updating columns of [HumanResources].[Employee_Temporal]
	If all parameters except @BusinessEntityID are NULL no update is performed 
	For NON NULL columns NULL values are ignored (i.e. existing values is applied)
*/
CREATE PROCEDURE [HumanResources].[sp_UpdateEmployee_Temporal]
 @BusinessEntityID INT
,@LoginID nvarchar(256) = NULL   
,@JobTitle nvarchar(50) = NULL
,@MaritalStatus nchar(1) = NULL
,@Gender nchar(1) = NULL
,@VacationHours smallint = 0
,@SickLeaveHours smallint = 0

AS
IF @LoginID IS NOT NULL OR @JobTitle IS NOT NULL OR @MaritalStatus IS NOT NULL 
OR @Gender IS NOT NULL OR @VacationHours IS NOT NULL OR @SickLeaveHours IS NOT NULL 

	UPDATE [HumanResources].[Employee_Temporal]
	SET  [LoginID] = ISNULL (@LoginID, LoginID),
	JobTitle = ISNULL (@JobTitle, JobTitle),
	MaritalStatus = ISNULL (@MaritalStatus, MaritalStatus),
	Gender = ISNULL (@Gender, Gender),
	VacationHours = ISNULL (@VacationHours, VacationHours),
	SickLeaveHours = ISNULL (@SickLeaveHours, SickLeaveHours)	
	WHERE BusinessEntityID = @BusinessEntityID;	
	
GO 

/*
	Stored procedure used for querying Employee and Person data AS OF
	If @AsOf parameter is NULL, current data is queried
	otherwise both current and historical data is queried
*/
CREATE  PROCEDURE [HumanResources].[sp_GetEmployee_Person_Info_AsOf]
@asOf datetime2 = NULL
AS
IF @asOf IS NULL
	SELECT * FROM [HumanResources].[vEmployeePersonTemporalInfo]
ELSE
	SELECT * FROM [HumanResources].[vEmployeePersonTemporalInfo] FOR SYSTEM_TIME AS OF @asOf;
GO

/*
	Loading data from the corresponing tables
	[Person].[Person],
	[HumanResources].[Employee]	
*/
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
SELECT [BusinessEntityID]
      ,[PersonType]
      ,[NameStyle]
      ,[Title]
      ,[FirstName]
      ,[MiddleName]
      ,[LastName]
      ,[Suffix]
      ,[EmailPromotion]
FROM [Person].[Person] ORDER BY [BusinessEntityID];


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
SELECT [BusinessEntityID]
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
FROM [HumanResources].[Employee];




