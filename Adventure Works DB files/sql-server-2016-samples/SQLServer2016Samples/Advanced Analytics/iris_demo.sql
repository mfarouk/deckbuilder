drop table if exists iris_data;
drop table if exists iris_models;
go
-- Setup table for holding data:
create table iris_data (
		id int not null identity primary key
		, "Sepal.Length" float not null, "Sepal.Width" float not null
		, "Petal.Length" float not null, "Petal.Width" float not null
		, "Species" varchar(100) null
);
-- Setup table for holding model(s):
create table iris_models (
	model_name varchar(30) not null default('default model') primary key,
	model varbinary(max) not null
);
go
drop procedure if exists get_iris_dataset;
go
create procedure get_iris_dataset
as
begin
	-- Return iris dataset from R to SQL:
	execute   sp_execute_external_script
					@language = N'R'
				  , @script = N'iris_data <- iris;'
				  , @input_data_1 = N''
				  , @output_data_1_name = N'iris_data'
	with result sets (("Sepal.Length" float not null, "Sepal.Width" float not null
				  , "Petal.Length" float not null, "Petal.Width" float not null, "Species" varchar(100)));
end;
go
--truncate table iris_data;
-- Populate data from iris dataset in R:
insert into iris_data ("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "Species")
exec dbo.get_iris_dataset;
select top(10) * from iris_data;
select count(*) from iris_data;
go

drop proc if exists generate_iris_model;
go
create procedure generate_iris_model
as
begin
	execute sp_execute_external_script
	  @language = N'R'
	, @script = N'
		library(e1071);
		irismodel <-naiveBayes(iris_data[,1:4], iris_data[,5]);
		trained_model <- data.frame(payload = as.raw(serialize(irismodel, connection=NULL)));
'
	, @input_data_1 = N'select "Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "Species" from iris_data'
	, @input_data_1_name = N'iris_data'
	, @output_data_1_name = N'trained_model'
	with result sets ((model varbinary(max)));
end;
go

--truncate table iris_models;
-- Generate model based on Naive Bayes algorithm in e1071 package:
insert into iris_models (model)
exec generate_iris_model;
update iris_models set model_name = 'e1071 - Naive Bayes' where model_name = 'default model';
select * from iris_models;
go

drop procedure if exists predict_species;
go
create procedure predict_species (@model varchar(100))
as
begin
	declare @nb_model varbinary(max) = (select model from iris_models where model_name = @model);
	-- Predict species based on the specified model:
	exec sp_execute_external_script 
					@language = N'R'
				  , @script = N'
library("e1071");
irismodel<-unserialize(nb_model)
species<-predict(irismodel, iris_data[,2:5]);
OutputDataSet <- cbind(iris_data[1], species, iris_data[6]);
colnames(OutputDataSet) <- c("id", "Species.Actual", "Species.Expected");
OutputDataSet <- subset(OutputDataSet, Species.Actual != Species.Expected);
'
	, @input_data_1 = N'
	select id, "Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width", "Species"
	  from iris_data'
	, @input_data_1_name = N'iris_data'
	, @params = N'@nb_model varbinary(max)'
	, @nb_model = @nb_model
	with result sets ( ("id" int, "Species.Actual" varchar(max), "Species.Expected" varchar(max))
			  );
end;
go

exec predict_species 'e1071 - Naive Bayes';
go


drop procedure if exists get_iris_plot1;
go
create procedure get_iris_plot1
as
begin
	-- Demonstrate how to generate plots from R & return to any SQL client:
	execute sp_execute_external_script
	  @language = N'R'
	, @script = N'
library("ggplot2");
image_file = tempfile();
jpeg(filename = image_file, width=600, height = 800);
print(qplot(Sepal.Length, Petal.Length, data = iris, color = Species,
    xlab = "Sepal Length", ylab = "Petal Length",
    main = "Sepal vs. Petal Length in Fisher''s Iris data"));
dev.off();
OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6));
'
	, @input_data_1 = N''
	with result sets ((plot varbinary(max)));


end;
go
grant execute on get_iris_plot1 to rdemo;
go

drop procedure if exists get_iris_plot2;
go
create procedure get_iris_plot2
as
begin
	-- Demonstrate how to generate plots from R & return to any SQL client:
	execute sp_execute_external_script
	  @language = N'R'
	, @script = N'
library("ggplot2");
image_file = tempfile();
jpeg(filename = image_file, width=600, height = 800);
print(qplot(Sepal.Length, Petal.Length, data = iris, color = Species, size = Petal.Width,
    xlab = "Sepal Length", ylab = "Petal Length",
    main = "Sepal vs. Petal Length with Width in Fisher''s Iris data"));
dev.off();
OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6));
'
	, @input_data_1 = N''
	with result sets ((plot varbinary(max)));
end;
go
grant execute on get_iris_plot2 to rdemo;
go
