PolyBase allows you to use T-SQL statements to query external data stored in Hadoop or Azure blob storage. This PolyBase sample will show you how to use PolyBase to query data stored in Azure blob storage.

To run the PolyBase sample, do the following:
1. install PolyBase on your SQL Server 2016 instance by running setup.exe and selecting PolyBase on the Feature Selection page.
2. restore the AdventureWorksDW2016_EXT backup to a SQL Server 2016 instance
3. upload sample data (FactResellerSalesArchive.txt) into a blob container on your Azure storage account
	upload using Azure Storage Explorer: https://azurestorageexplorer.codeplex.com/
	uploading using AzCopy: https://azure.microsoft.com/en-us/documentation/articles/storage-use-azcopy/
4. run the script 'PolybaseSample.sql' to query the sample data in Azure Storage