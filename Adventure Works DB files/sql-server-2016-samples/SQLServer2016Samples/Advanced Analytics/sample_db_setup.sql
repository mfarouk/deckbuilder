if SUSER_SID('rdemo') is null
	create login rdemo with password = 'Password1!';
go
drop user if exists rdemo;
create user rdemo;
alter role db_rrerole add member rdemo;
go

drop database if exists sqlr;
create database sqlr;
go

use sqlr;
go

drop user if exists rdemo;
create user rdemo;

-- Grant permission to users to execute R scripts:
grant execute any external script to rdemo;
go
