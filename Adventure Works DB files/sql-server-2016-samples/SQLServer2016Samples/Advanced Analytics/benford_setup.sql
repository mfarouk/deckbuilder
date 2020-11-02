use sqlr;
go
drop table if exists Fraud, FraudulentVendors, FraudulentVendorsPlots;
go
-- create the fraud table to hold invoice data:
create table Fraud(
	[VendorNumber] varchar(10),
	[VoucherNumber] int not null,
	[CheckNumber] int not null,
	[InvoiceNumber] int not null,
	[InvoiceDate] date not null,
	[PaymentDate] date not null,
   [DueDate] date not null,
   [InvoiceAmount] money not null,
   [PONumber] int not null);
go
-- Modify path to the data file: "po.txt"
bulk insert Fraud
from 'C:\sqlr\samples\po.txt'
with(
	fieldterminator = '\t',
	firstrow = 2);
go
create clustered columnstore index cs_Fraud on Fraud;
go

-- This table holds the plots generated for each fraudulent vendor.
-- This is optimization since we cannot return multiple varbinary(max) from R script at this time.
create table FraudulentVendorsPlots ( VendorNumber varchar(10) default ('') primary key, Plot varbinary(max) not null );

-- Stores the list of fraudulent vendors based on Benford law & specified threshold.
create table FraudulentVendors( VendorNumber varchar(10) primary key,
	   Digit1 int, Digit2 int, Digit3 int, Digit4 int, Digit5 int, Digit6 int, Digit7 int, Digit8 int, Digit9 int,
	   Pvalue float);
go

grant select on Fraud to rdemo;
go
