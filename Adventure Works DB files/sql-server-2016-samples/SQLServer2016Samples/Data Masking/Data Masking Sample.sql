----------------------------------------------------------------
-- AdventureWorks2016_EXT samples: Dynamic Data Masking
----------------------------------------------------------------

-- This demo uses the Sales.CustomerPII table in the AdventureWorks2016_EXT sample database
-- to demonstrate how Dynamic Data Masking (DDM) can be used to mask (fully or partially) data
-- in sensitive columns.
--
USE AdventureWorks2016_EXT
go


-- DDM is already enabled in the sample database to mask the EmailAddress and PhoneNumber columns
-- in the Sales.CustomerPII table. 

-- If you are connected as 'dbo', you will always see unmasked data:
SELECT * FROM Sales.CustomerPII
go

-- Unprivileged users see masked data by default. For example, this SalesPerson 'michael9' will
-- see masked data:
EXECUTE AS USER = 'michael9'
SELECT * FROM Sales.CustomerPII -- EmailAddress and PhoneNumber are masked
REVERT
go

-- Granting users or roles the UNMASK permission will enable them to see unmasked data:
GRANT UNMASK TO SalesPersons -- role
go

EXECUTE AS USER = 'michael9'
SELECT * FROM Sales.CustomerPII -- EmailAddress and PhoneNumber are no longer masked
REVERT
go

-- Reset the changes
REVOKE UNMASK TO SalesPersons
go

-- DDM is configured in the table schema. For example, if you have the ALTER ANY MASK permission,
-- you can remove a mask on a column like this:
ALTER TABLE Sales.CustomerPII
ALTER COLUMN EmailAddress DROP MASKED
go

-- And you can add a mask like this: 
ALTER TABLE Sales.CustomerPII
ALTER COLUMN EmailAddress ADD MASKED WITH (FUNCTION = 'email()')
go

-- You can also edit a mask with a different masking function. This shows how to define a custom
-- mask, where you specify how many characters to reveal (prefix and suffix) and your own padding
-- string in the middle: 
ALTER TABLE Sales.CustomerPII
ALTER COLUMN EmailAddress ADD MASKED WITH (FUNCTION = 'partial(2, "zzz@abab", 4)')  -- New mask for email
go
ALTER TABLE Sales.CustomerPII
ALTER COLUMN PhoneNumber ADD MASKED WITH (FUNCTION = 'partial(0, "111-111-11", 2)') -- New mask for phone
go

-- See how that masks now:
EXECUTE AS USER = 'michael9'
SELECT * FROM Sales.CustomerPII -- New custom masks for EmailAddress and Phone
REVERT
go

-- Reset the changes
ALTER TABLE Sales.CustomerPII
ALTER COLUMN EmailAddress ADD MASKED WITH (FUNCTION = 'email()')
go
ALTER TABLE Sales.CustomerPII
ALTER COLUMN PhoneNumber ADD MASKED WITH (FUNCTION = 'default()')
go

-- Try doing a SELECT INTO from the table with a mask into a temp table (with a user that doesn't 
-- have the UNMASK permission), and you'll find that the temp table contains masked data:
EXECUTE AS USER = 'michael9'

SELECT CustomerId, EmailAddress, PhoneNumber INTO #temp_table
FROM Sales.CustomerPII -- Masked Email and Phone

SELECT * FROM #temp_table  -- temp table has masked data

DROP TABLE #temp_table
REVERT
go
