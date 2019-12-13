




go 
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1014_ds_OutstandingBalanceOfStocks')
drop procedure [usp_CBI_1014_ds_OutstandingBalanceOfStocks]
GO

Create Procedure [dbo].[usp_CBI_1014_ds_OutstandingBalanceOfStocks]
														(
															@StoreGroupNos as varchar(8000)
															,@parExpiredateFrom as varchar(40)
															,@parExpiredateTo as varchar(40)
														)
AS
BEGIN 
	--Rapport nr 1014
	--SET DATEFORMAT dmy

	Set ANSI_NULLS ON;
	Set ANSI_WARNINGS ON;
	set nocount on;	-- This has to be here. In some installations jasper is not returning a resultset if this is not here
	
	declare @sql As nvarchar(max) = ''
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)

------------------------------------------------------------------------------------------------------

	SET @sql = @sql +  '
	IF OBJECT_ID(''tempdb..#ds_OutstandingBalanceOfStocks'') IS NOT NULL  DROP TABLE #ds_OutstandingBalanceOfStocks '

	if len(@StoreGroupNos) > 0 
		Begin
			
			SET @sql = @sql +  '
			;WITH DimStores AS (
			select StoreNo
			from  dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) 
			)
			'
		End
	else
		Begin
			SET @sql = @sql +  '
			;WITH DimStores AS (
			select null as StoreNo
			)
			'
		End


	SET @sql = @sql + '
	select 
		stor.internalstoreid, 
		stor.storename, 
		alar.supplierarticleid, 
		alar.EANNo, 
		alar.ArticleID, 
		alar.ArticleName,
		alar.ArticleNo, 
		ISNULL(sai.InStockQty,0) as InStockQtySalesStock,
		ISNULL(tsai.TotalStockAmount,0) as TotalNetCostAmount,
		ISNULL(tsai.TotalStockQty,0) as TotalStockQty,
		alar.DeletedDate, 
	CASE WHEN alar.ArticleHierIDTop=(100) THEN (''Läkemdel RX'')
		 WHEN alar.ArticleHierIDTop=(200) THEN (''Läkemdel OTC'')
		 WHEN alar.ArticleHierIDTop=(300) THEN (''Livsmedel RX'')
		 WHEN alar.ArticleHierIDTop=(400) THEN (''Hjälpmedel medicinskt'')
		 WHEN alar.ArticleHierIDTop=(900) THEN (''Handelsvaror'')
	  ELSE ('''')
	END as Gruppering,
		isnull(ItemAlar.ExpiryDate,''01-jun-2005'') as ExpireDate
	into #ds_OutstandingBalanceOfStocks
	--FROM RS13_1.vbdcm.dbo.allarticles alar with (nolock)
	FROM openquery(RS17_1, ''Select * from RSItemESDB.dbo.articles'') ItemAlar
	JOIN dbo.allarticles alar with (nolock) on alar.articleId = ItemAlar.Articleid
	JOIN StoreArticleInfos sai with (nolock) on alar.ArticleNo = sai.ArticleNo
	JOIN Stores stor with (nolock) on stor.StoreNo = sai.StoreNo
	JOIN vw_TotalStoreArticleInfos tsai on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo
	JOIN DimStores dimSto with (nolock) on stor.StoreNo = dimSto.StoreNo
	WHERE stor.storetypeno = 7
	AND alar.articlestatus >= 8 
	AND sai.InStockQty >0
	'

	if len(@parExpiredateFrom ) > 0 
      	SET @sql = @sql + ' AND ItemAlar.ExpiryDate >= cast(@parDateFrom as datetime)'

	if len(@parExpiredateTo ) > 0 
		SET @sql = @sql + ' AND ItemAlar.ExpiryDate <= cast(@parDateTo as datetime)'
    

	
---------------------------------------------------------------------------------------------------------------------------	
-- Geting additional article info and adding to final select
---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------
-- Function ufn_CBI_getDynamicColsStrings available values for parameter @typeOfCols
 -- Col types descriptions
 --1 - Creating string to create temp table with dynamic fields this one forms dynamic fields;	(@colsCreateTable)
 --2 - Creating string to fill temp table with values insert into #dynamic (-values-);	(@colsToInsertTbl)
 --3 - Creating string to select Cols from final select;	(@colsFinal)
 --4 - Creating string to pivot dynamic cols in proc; (@colsPivot)
 --5 - Creating string to filter pivot in proc. (@colsPivotFilt) e. g.: ''ATC-KOD''
 --6 - Creating string to filter pivot in proc. (@colsPivotFilt) e. g.: 'ATC-KOD'
---------------------------------------------------------------------------------------------------------------------------

	select 	@colsCreateTable = dbo.ufn_CBI_getDynamicColsStrings (1)
	select 	@colsToInsertTbl = dbo.ufn_CBI_getDynamicColsStrings (2)
	select 	@colsFinal = dbo.ufn_CBI_getDynamicColsStrings (3)


	-- Creating table dynamically
	set @sql = @sql + '

	IF OBJECT_ID(''tempdb..#DynamicValues'') IS NOT NULL  DROP TABLE #DynamicValues 
	CREATE TABLE #DynamicValues ( articleNo int, articleId varchar(50),
	'+
	@colsCreateTable
	+')
	
	'

	-- In proc selecting from  #ArticleNos and inserting into #DynamicValues
	set @sql = @sql + '

	IF OBJECT_ID(''tempdb..#ArticleNos'') IS NOT NULL DROP TABLE #ArticleNos
	SELECT distinct ArticleNo
	into #ArticleNos 
	FROM #ds_OutstandingBalanceOfStocks

	'

	if len(@StoreGroupNos ) > 0 and (select charindex(',', @StoreGroupNos ) ) > 0
	begin
		set @sql = @sql + ' 	
		insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
		exec CBI_vrsp_GetDynamicValues @StoreNo = 0, @GetStoreArticleValues = 1 '
	end

	if len(@StoreGroupNos ) > 0 and (select charindex(',', @StoreGroupNos ) ) = 0 
	begin
		set @sql = @sql + ' 
		insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
		exec CBI_vrsp_GetDynamicValues @StoreNo = ' + @StoreGroupNos + ', @GetStoreArticleValues = 1
		'
	end




	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_OutstandingBalanceOfStocks a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		 order by ArticleId, internalstoreid 
		'


	--print(@sql)

	exec sp_executesql @sql,
					   N'@StoreGroupNos nvarchar(max), @parDateFrom nvarchar(40), @parDateTo nvarchar(40) ',
					   @StoreGroupNos = @StoreGroupNos,
					   @parDateFrom = @parExpiredateFrom,
					   @parDateTo = @parExpiredateTo



END


GO

/*
exec usp_CBI_1014_ds_OutstandingBalanceOfStocks	@StoreGroupNos = '3000,1725,1250,3010',
													@parExpiredateFrom = '2008-01-01', 
													@parExpiredateTo = '2018-07-20'

*/








