declare @DatabaseTemplate nvarchar(max) = 'Customer2'
declare @DatabaseDestination nvarchar(max) = 'ReportingDb'
declare @TableSchema nvarchar(max)
declare @TableName nvarchar(max)

declare @DatabaseCurrent nvarchar(max)
declare @DatabaseCounter int = 1

declare @TableListGenerateCode nvarchar(max) = ''
declare @TableCounter int = 1

declare @DropView nvarchar(255) = ''

declare @TableSelectFromCurrentDatabaseCode nvarchar(max) = ''
declare @TableSelectFromAllDatabaseCode nvarchar(max) = ''

declare @ColumnSelectFromCurrentTableCode nvarchar(max) = ''

declare @PrintColumnList nvarchar(max)

IF OBJECT_ID('tempdb..#DatabaseList') IS NOT NULL drop table #DatabaseList
create table #DatabaseList (DatabaseId int identity(1,1), DatabaseName varchar(255))


IF OBJECT_ID('tempdb..#TableList') IS NOT NULL drop table #TableList
create table #TableList (TableId int identity(1,1), TableSchema varchar(255), TableName varchar(255))

IF OBJECT_ID('tempdb..#ColumnList') IS NOT NULL drop table #ColumnList
create table #ColumnList (ColumnId int identity(1,1), ColumnName varchar(255))


insert into #DatabaseList (databasename)
select db.name  
from sys.databases db
where 
database_id > 4 
and db_Name(database_id) <> @DatabaseTemplate and db_Name(database_id) <> 'reportingdb' and db_Name(database_id) <> 'electronics' and db_Name(database_id) <> 'mytestdb'
and state = 0;

set @TableListGenerateCode=
'
Insert into #TableList (TableSchema, TableName)
SELECT TABLE_SCHEMA, TABLE_NAME
FROM ' + @DatabaseTemplate + '.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = ''BASE TABLE'' AND table_catalog = ' + '''' + @DatabaseTemplate + ''''

exec (@TableListGenerateCode)



while @TableCounter <= (select count(*) from #TableList) 
begin

	set @TableSchema = (select TableSchema from #TableList where Tableid = @TableCounter)
	set @TableName = (select TableName from #TableList where Tableid = @TableCounter)
	set @DatabaseCounter = 1


	while @DatabaseCounter <= (select count(*) from #DatabaseList)
	begin

		set @DatabaseCurrent = (select DatabaseName from #DatabaseList where DatabaseId = @DatabaseCounter)

		truncate table #ColumnList
		set @ColumnSelectFromCurrentTableCode = 'insert into #ColumnList   select STUFF((
			SELECT '', 
		'' + QUOTENAME(c.name) 
			FROM ' + @DatabaseCurrent + '.sys.columns c where c.object_id = object_id(''' +  @DatabaseCurrent + '.' + @TableSchema + '.' + @Tablename +''')
			FOR XML PATH(''''), TYPE).value(''.'',''nvarchar(max)''),1,2,'''')'

		exec (@ColumnSelectFromCurrentTableCode)

		set @TableSelectFromCurrentDatabaseCode = 
	'
	UNION ALL 

	SELECT ' + (select top 1 ColumnName from #ColumnList) +
			' 
	FROM ' + @DatabaseCurrent + '.' + @TableSchema + '.' +  @Tablename + CHAR(13)+CHAR(10) + '
			'
		set @TableSelectFromAllDatabaseCode = @TableSelectFromCurrentDatabaseCode + @TableSelectFromAllDatabaseCode 

		set @DatabaseCounter = @DatabaseCounter + 1

	end

		set @PrintColumnList = (select ColumnName from #ColumnList)

		set @TableSelectFromAllDatabaseCode = N' EXEC ' + @DatabaseDestination + '.sys.sp_executesql ' + 'N''Create Procedure ' + @Tablename + 'Import as
	Insert into ' + @Tablename + '
	( ' + @PrintColumnList + '
	) 
	' + RIGHT(@TableSelectFromAllDatabaseCode, LEN(@TableSelectFromAllDatabaseCode) - 13)+''''
			
		PRINT @TableSelectFromAllDatabaseCode
				
		set @DropView = N' EXEC ' + @DatabaseDestination + '.sys.sp_executesql ' + 'N''IF OBJECT_ID(''''' + @TableName + 'IMPORT'''', ''''P'''') IS NOT NULL   DROP PROCEDURE ' + @Tablename + 'Import' + ''''

		exec (@DropView)
		exec (@TableSelectFromAllDatabaseCode)
		set @TableCounter = @TableCounter + 1
		
		set @DropView = ''
		set @TableSelectFromCurrentDatabaseCode = ''
		set @TableSelectFromAllDatabaseCode = ''


end


