select f.physical_name from sys.master_files f, sys.databases d where f.database_id = d.database_id and
 d.name = 'ryantestdb' 