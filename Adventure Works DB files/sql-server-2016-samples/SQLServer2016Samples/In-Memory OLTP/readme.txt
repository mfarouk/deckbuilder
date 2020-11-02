This readme contains instructions for running the sample workload that illustrates the performance benefits, as well as instructions for inspecting the In-Memory OLTP objects in the database.

---- Running the sample workload -----

To run the In-Memory OLTP sample workload, do the following:
1. restore the AdventureWorks2016_EXT backup to a SQL Server 2016 instance
2. install the RML utilities from the following location: http://blogs.msdn.com/b/psssql/archive/2013/10/29/cumulative-update-2-to-the-rml-utilities-for-microsoft-sql-server-released.aspx
3. open the 'RML Cmd Prompt', which can be found under 'All Apps' -> 'RML Utilities for SQL Server'
4. navigate to the folder that has this readme file as well as the sample scripts for In-Memory OLTP
5. run the following commands in the RML Cmd Prompt window, and compare the run-time for the workload on memory-optimized tables versus disk-based tables

  Inserting 1 million sales orders in memory-optimized tables: 

    ostress.exe –n100 –r500 -S. -E -dAdventureWorks2016_EXT -q -i"Memory-optimized Inserts.sql"


  Inserting 1 million sales orders in disk-based tables: 

    ostress.exe –n100 –r500 -S. -E -dAdventureWorks2016_EXT -q -i"Disk-based Inserts.sql"



  For the best performance comparison, we recommend running the sample workload in a server with hardware similar to your production systems. In particular, the database log file should be located on a device with fast access, such as an SSD.



----- Inspecting the In-Memory OLTP objects in the sample -----

The sample contains the following memory-optimized tables:
•SalesLT.Product_inmem
•SalesLT.SalesOrderHeader_inmem
•SalesLT.SalesOrderDetail_inmem
•Demo.DemoSalesOrderHeaderSeed
•Demo.DemoSalesOrderDetailSeed

Inspect memory-optimized tables through object explorer in SQL Server management studio, or through catalog view queries. 

Example:

    SELECT name, object_id, type, type_desc, is_memory_optimized, durability, durability_desc
    FROM sys.tables
    WHERE is_memory_optimized=1


The natively compiled modules can be inspected through object explorer or queries of the catalog views. The sample contains three kinds of natively compiled modules:
•A Stored Procedure
•Scalar User-Defined Functions
•Inline Table-Valued Functions

Example:

    SELECT object_name(object_id), object_id, definition, uses_native_compilation 
    FROM sys.sql_modules
    WHERE uses_native_compilation=1


The sample contains one memory-optimized table type, which can be inspected through object explorer or the following query:

Example:

    SELECT name, user_type_id, is_memory_optimized
    FROM sys.table_types
    WHERE is_memory_optimized=1

