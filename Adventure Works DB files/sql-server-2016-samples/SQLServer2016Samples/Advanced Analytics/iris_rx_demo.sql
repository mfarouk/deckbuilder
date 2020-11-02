use sqlr;
go
-- Setup data:
drop table if exists iris_rx_data;
drop table if exists iris_rx_models;
go
create table iris_rx_data (
		id int not null identity primary key
		, "Sepal.Length" float not null, "Sepal.Width" float not null
		, "Petal.Length" float not null, "Petal.Width" float not null
		, "Species" varchar(100) null
);
create table iris_rx_models (
	model_name varchar(30) not null default('default model') primary key,
	model varbinary(max) not null
);
go
drop procedure if exists get_iris_dataset;
go
create procedure get_iris_dataset
as
begin
	execute   sp_execute_external_script
					@language = N'R'
				  , @script = N'iris_data <- iris;'
				  , @input_data_1 = N''
				  , @output_data_1_name = N'iris_data'
	with result sets (("Sepal.Length" float not null, "Sepal.Width" float not null
				  , "Petal.Length" float not null, "Petal.Width" float not null, "Species" varchar(100)));
end;
go
truncate table iris_rx_data;
insert into iris_rx_data ("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "Species")
exec dbo.get_iris_dataset;
select top(10) * from iris_rx_data;
select count(*) from iris_rx_data;
go

drop proc if exists generate_iris_rx_model;
go
create procedure generate_iris_rx_model
as
begin
	execute sp_execute_external_script
	  @language = N'R'
	, @script = N'
		require("RevoScaleR");
		irisLinMod <- rxLinMod(Sepal.Length ~ Sepal.Width + Petal.Length + Petal.Width + Species, data = iris_rx_data);
		trained_model <- data.frame(payload = as.raw(serialize(irisLinMod, connection=NULL)));
'
	, @input_data_1 = N'select "Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "Species" from iris_rx_data'
	, @input_data_1_name = N'iris_rx_data'
	, @output_data_1_name = N'trained_model'
	with result sets ((model varbinary(max)));
end;
go

--truncate table iris_rx_models;
insert into iris_rx_models (model)
exec generate_iris_rx_model;
update iris_rx_models set model_name = 'rxLinMod' where model_name = 'default model';
select * from iris_rx_models;
go

drop procedure if exists predict_species_sepal_length;
go
create procedure predict_species_sepal_length (@model varchar(100))
as
begin
	declare @rx_model varbinary(max) = (select model from iris_rx_models where model_name = @model);
	-- Predict based on the specified model:
	exec sp_execute_external_script 
					@language = N'R'
				  , @script = N'
require("RevoScaleR");
irismodel<-unserialize(rx_model);
irispred <-rxPredict(irismodel, iris_rx_data[,2:6]);
OutputDataSet <- cbind(iris_rx_data[1], irispred$Sepal.Length_Pred, iris_rx_data[2]);
colnames(OutputDataSet) <- c("id", "Sepal.Length.Actual", "Sepal.Length.Expected");
#OutputDataSet <- subset(OutputDataSet, Species.Length.Actual != Species.Expected);
'
	, @input_data_1 = N'
	select id, "Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "Species"
	  from iris_rx_data'
	, @input_data_1_name = N'iris_rx_data'
	, @params = N'@rx_model varbinary(max)'
	, @rx_model = @rx_model
	with result sets ( ("id" int, "Species.Length.Actual" float, "Species.Length.Expected" float)
			  );
end;
go

exec predict_species_sepal_length 'rxLinMod';
go
