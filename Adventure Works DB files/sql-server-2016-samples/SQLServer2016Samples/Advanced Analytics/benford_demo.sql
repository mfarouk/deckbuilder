use sqlr;
go
drop procedure if exists getFraudData
go
create procedure getFraudData
as
begin
	select VendorNumber, VoucherNumber, CheckNumber, InvoiceNumber, InvoiceDate, PaymentDate, DueDate, InvoiceAmount
	  from Fraud;
end;
go
grant execute on getFraudData to rdemo;
go

-- Generates the Digits and Frequency for each vendor
drop function if exists VendorInvoiceDigits
go
create function VendorInvoiceDigits (@VendorNumber varchar(10) = null)
returns table
as
return
	with f as (
		select VendorNumber
			 , InvoiceAmount
			 , round(case
					when InvoiceAmount >= 1000000000 then InvoiceAmount / 1000000000
					when InvoiceAmount >= 100000000 then InvoiceAmount / 100000000
					when InvoiceAmount >= 10000000 then InvoiceAmount / 10000000
					when InvoiceAmount >= 1000000 then InvoiceAmount / 1000000
					when InvoiceAmount >= 100000 then InvoiceAmount / 100000
					when InvoiceAmount >= 10000 then InvoiceAmount / 10000
					when InvoiceAmount >= 1000 then InvoiceAmount / 1000
					when InvoiceAmount >= 100 then InvoiceAmount / 100
					when InvoiceAmount >= 10 then InvoiceAmount / 10
					when InvoiceAmount < 10 then InvoiceAmount
				end, 0, 1) as Digits
			, count(*) over(partition by VendorNumber) as #Transactions
		  from Fraud
	)
	select VendorNumber, Digits, count(*) as Freq
	  from f
	where #Transactions > 2 and InvoiceAmount > 0 and (VendorNumber = @VendorNumber or @VendorNumber IS NULL)
	group by VendorNumber, Digits
go

drop procedure if exists getPotentialFraudulentVendors;
go
create procedure getPotentialFraudulentVendors (@threshold float = 0.1)
as
begin
	-- Use Benford law to get the potential fraud vendors.
	exec sp_execute_external_script
		  @language = N'R',
		  @script = N'
			 library(reshape2);
			 dd = dcast(InputDataSet, VendorNumber ~ Digits, value.var="Freq");
			 OutputDataSet = cbind(
				dd,
				apply(dd[,-1], 1, function(xx) chisq.test(xx, p=(log(1+1/(1:9))/log(10)))$p.value)); ## Equation using Benford law
			 colnames(OutputDataSet) <- c("VendorNumber", "Digit1", "Digit2", "Digit3", "Digit4",
											"Digit5", "Digit6", "Digit7", "Digit8", "Digit9", "Pvalue");
			OutputDataSet <- subset(OutputDataSet, Pvalue < threshold);
		  ',
		  @input_data_1 = N'
	select VendorNumber, Digits, Freq
	  from VendorInvoiceDigits(default)
	order by VendorNumber asc, Digits asc;
		  ',
		  @params = N'@threshold float',
		  @threshold = @threshold
	with result sets (( VendorNumber varchar(10),
	   Digit1 int, Digit2 int, Digit3 int, Digit4 int, Digit5 int, Digit6 int, Digit7 int, Digit8 int, Digit9 int,
	   Pvalue float));
end;
go
drop procedure if exists getVendorInvoiceDigits;
go
create procedure getVendorInvoiceDigits (@VendorNumber varchar(10))
as
begin
	-- Produces plot for a specific vendor showing the distribution of invoice amount digits (Actual) vs. Benford distribution for the digit (Expected)
	exec sp_execute_external_script
		  @language = N'R',
		  @script = N'
			 require(ggplot2)
			 require(ggthemes)
			 require(reshape2)

			 qq = as.numeric(InputDataSet[,1])
			 pp = data.frame(num=factor(1:9),pct=round(100*(log(1+1/(1:9))/log(10))))
			 pp = data.frame(num=pp$num, Actual=round(100*qq/sum(qq)), Expected=pp$pct)
			 pp = melt(pp)
   
			 title = "Distribution of Leading Digits in Invoices"
   
			 gg = ggplot(pp, aes(x=num, y=value, fill=variable)) + geom_bar(stat="identity", position="dodge", alpha=0.85)
			 gg = gg + labs(x="Leading Digit", y="Percent")
			 windowsFonts(Verdana="TT Verdana")
			 gg = gg + theme_igray(base_size=16, base_family="Verdana")
			 gg = gg + theme(legend.title=element_blank())

			 ff = tempfile()
			 png(filename=ff, width=620, height=240)
			 print(gg)
			 dev.off()
			 OutputDataSet = data.frame(data=readBin(file(ff, "rb"), what=raw(), n=1e6))
		  ',
		  @input_data_1 = N'select Freq from VendorInvoiceDigits(@vendor) order by Digits;',
		  @params = N'@vendor varchar(10)',
		  @vendor = @VendorNumber
	with result sets(([chart] varbinary(max)));
end;
go

drop procedure if exists getVendorInvoiceDigitsPlots;
go
create procedure getVendorInvoiceDigitsPlots (@threshold float = 0.1)
as
begin
	-- Produces plots for all vendors suspected of fraud showing
	-- the distribution of invoice amount digits (Actual) vs. Benford distribution for the digit (Expected)
	create table #v ( VendorNumber varchar(10),
	   Digit1 int, Digit2 int, Digit3 int, Digit4 int, Digit5 int, Digit6 int, Digit7 int, Digit8 int, Digit9 int,
	   Pvalue float);

	insert into #v exec getPotentialFraudulentVendors @threshold;
	truncate table FraudulentVendorsPlots;

	declare @p cursor, @vendor varchar(10);
	set @p = cursor fast_forward for select VendorNumber from #v;
	open @p;
	while(1=1)
	begin
		fetch @p into @vendor;
		if @@fetch_status < 0 break;

		insert into FraudulentVendorsPlots (Plot)
		exec getVendorInvoiceDigits @vendor;

		update FraudulentVendorsPlots set VendorNumber = @vendor where VendorNumber = '';
	end;
	deallocate @p;
end;
go

drop procedure if exists getPotentialFraudulentVendorsList
go
create procedure getPotentialFraudulentVendorsList (@threshold float)
as
begin
	-- Optimized version of the proc that uses staging table for the fraud data
	select fv.*, fvp.Plot
	  from FraudulentVendors as fv
	  join FraudulentVendorsPlots as fvp
		on fvp.VendorNumber = fv.VendorNumber;
end;
go
grant execute on getPotentialFraudulentVendorsList to rdemo;
go

-- Get the fraudulent vendors:
insert into FraudulentVendors
exec getPotentialFraudulentVendors 0.10;

-- Generate plots for the fraudulent vendors:
exec getVendorInvoiceDigitsPlots 0.10;

-- Generate plot for a specific fraudulent vendor:
exec getVendorInvoiceDigits '105436'
go

-- Get the vendor / plots:
select VendorNumber, Plot from FraudulentVendorsPlots;
go
