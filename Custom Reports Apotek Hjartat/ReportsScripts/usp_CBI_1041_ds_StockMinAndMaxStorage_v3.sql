go
use [VBDCM]
go


If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1041_ds_StockMinAndMaxStorage')
drop procedure usp_CBI_1041_ds_StockMinAndMaxStorage
go



CREATE PROCEDURE [dbo].[usp_CBI_1041_ds_StockMinAndMaxStorage] (
	@StoreGroupNos  As varchar(8000) = '',
	@parInkPrisMin as varchar(100) = '',
	@parInkPrisMax as varchar(100) = '',
	@parTop1 as varchar(1) = '',
	@parTop2 as varchar(1) = '',
	@parTop3 as varchar(1) = '',
	@parTop4 as varchar(1) = '',
	@parTop5 as varchar(1) = ''
)
AS
	DECLARE @URVAL as varchar (100)
	SET @URVAL=''

	declare @sql As nvarchar(max)
	set @sql = ''

	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)
	declare @colsToInsertTbl as varchar(max)

	set nocount on;

------------------------------------------------------------------------------------------------------

	SET @sql = @sql +  '
	IF OBJECT_ID(''tempdb..#ds_StockMinAndMaxStorage'') IS NOT NULL  DROP TABLE #ds_StockMinAndMaxStorage '

	if len(@StoreGroupNos) > 0 
		Begin
			
			SET @sql = @sql +  '
			select StoreNo
			into #DimStores
			from  dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos)
			'
		End
	else
		Begin
			SET @sql = @sql +  '
			select null as StoreNo
			into #DimStores
			'
		End


	set @sql =  @sql + '
				create table #ds_StockMinAndMaxStorage (internalstoreid varchar(50),
														StoreName varchar(100),
														supplierarticleid varchar(50),
														EANNo bigint,
														ArticleID varchar(50),
														ArticleName varchar(100),
														ArticleNo int,
														ArticleHierID varchar(50),
														ArticleHierName varchar(100),
														SupplierName varchar(100),
														InStockQtySalesStock float,
														TotalNetCostAmount float,
														AvalibleStock float,
														MinLager real,
														MaxLager float,
														OrderedQty float,
														Hyllplats1 varchar(4000),
														Diff float,
														Gruppering varchar(50),
														monthsale float,
														LastUpdatedStockCount datetime,
														NetPriceDerived float
														)
		

				create index StockMinAndMaxStorage_indx on #ds_StockMinAndMaxStorage (ArticleNo);
				'

	set @sql =  @sql + '
				WITH StoreGrArticles AS (
					SELECT artInf.*, a.ArticleId, s.StoreId --DISTINCT SGL2.StoreGroupNo --*
					FROM RS17_1.RSItemESDB.dbo.StoreGroupArticles artInf WITH (NOLOCK)
					INNER JOIN RS17_1.RSItemESDB.dbo.StoreGroupLinks AS SGL WITH (NOLOCK) ON SGL.StoreGroupNo = artInf.StoreGroupNo
					INNER JOIN RS17_1.RSItemESDB.dbo.Stores AS s WITH (NOLOCK) ON s.StoreNo = SGL.StoreNo
					INNER JOIN RS17_1.RSItemESDB.dbo.Articles AS a WITH (NOLOCK) ON a.ArticleNo = artInf.ArticleNo
					INNER JOIN dbo.Stores AS rs17Stor WITH (NOLOCK) ON rs17Stor.Storeid = s.Storeid
					INNER JOIN #DimStores AS ds WITH (NOLOCK) ON rs17Stor.StoreNo = ds.StoreNo
					)

				insert into #ds_StockMinAndMaxStorage  (internalstoreid, StoreName, supplierarticleid, EANNo, ArticleID, ArticleName, ArticleNo, ArticleHierID, ArticleHierName,
														SupplierName, InStockQtySalesStock, TotalNetCostAmount, AvalibleStock, MinLager, MaxLager, OrderedQty, Hyllplats1, Diff,
														Gruppering, monthsale, LastUpdatedStockCount, NetPriceDerived )
				Select 
					sto.internalstoreid, 
					sto.StoreName, 
					ltrim(isnull(art.WholesalerArticleID, art.SupplierArticleID )) as supplierarticleid,
					art.EanNo, 
					art.ArticleID, 
					art.ArticleName,
					art.ArticleNo,
					art.ArticleHierID,  
					art.ArticleHierName,  
					art.SupplierName, 
					IsNull(sai.InStockQty, 0) as InStockQtySalesStock,
					tsai.TotalStockAmount as TotalNetCostAmount,
					IsNull(sai.AvailableStockQty, 0) as AvalibleStock,
					IsNull(SGL.MinStockLevel, 0) as MinLager,
					IsNull(SGL.MaxStockLevel, 0) as MaxLager,
					IsNull(sai.StockInOrderQty, 0) as OrderedQty,
					isnull(SP1.Infovalue,'''') as Hyllplats1, 
					Sai.InStockQty-sai.AvailableStockQty as Diff,
					CASE WHEN art.ArticleHierIDTop=(100) THEN (''Läkemdel RX'')
							WHEN art.ArticleHierIDTop=(200) THEN (''Läkemdel OTC'')
							WHEN art.ArticleHierIDTop=(300) THEN (''Livsmedel RX'')
							WHEN art.ArticleHierIDTop=(400) THEN (''Hjälpmedel medicinskt'')
							WHEN art.ArticleHierIDTop=(900) THEN (''Handelsvaror'')
						ELSE ('''')
					END as Gruppering,
					--art.ArticleHierNoTop as Gruppering, -- case in jasper report
					isnull(sai.AverageSalesQty, 0) as monthsale,
					sai.LastUpdatedStockCount,
					CASE WHEN  ISNULL(tsai.TotalStockQty, 0) = 0 THEN 0
						 ELSE  tsai.TotalStockAmount / tsai.TotalStockQty 
					END AS NetPriceDerived
				FROM StoreArticleInfos sai with (nolock)
				JOIN Stores sto with (nolock) on (sai.StoreNo = sto.StoreNo)
				JOIN #DimStores dimStor on dimStor.StoreNo = sto.StoreNo
				JOIN vw_TotalStoreArticleInfos tsai  with (nolock) on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo
				JOIN AllArticles art with (nolock) on (sai.ArticleNo = art.ArticleNo)
				JOIN activeallarticleprices aaap with (nolock) on (sai.storeno = aaap.storeno and sai.articleno = aaap.articleno)
				LEFT JOIN StoreArticleInfoDetails AS SP1 with (nolock) ON  sai.storeno = SP1.STORENO AND sai.ArticleNo = SP1.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
				LEFT JOIN StoreGrArticles AS SGL with (nolock) ON  SGL.ArticleId = art.ArticleID AND SGL.StoreId = sto.StoreID 
				WHERE art.MasterArticle = 0 
				AND tsai.TotalStockQty > 0 
				AND sai.InStockQty > 0
				AND ((sai.MinimumStockQty IS NOT NULL OR sai.MinimumStockQty <> 0) AND (sai.MaximumStockQty IS NOT NULL OR sai.MaximumStockQty <> 0))
				'


	If len(@parInkPrisMin) > ''
		set @sql = @sql + ' AND  (tsai.TotalStockAmount / tsai.TotalStockQty) >= @parInkPrisMin'

	If len(@parInkPrisMax) >''
		set @sql = @sql + ' AND (tsai.TotalStockAmount / tsai.TotalStockQty) <=  @parInkPrisMax'

	if @parTop1= 'Y' 
		set @URVAL = '100,' 
	if @parTop2= 'Y'
		set @URVAL = '200,'+@Urval 
	if @parTop3= 'Y'
		set @URVAL = '300,'+@Urval 
	if @parTop4= 'Y'
		set @URVAL = '400,'+@Urval 
	if @parTop5= 'Y'	
		set @URVAL = '900,'+@Urval 
	
	if len(@URVAL) > 0
	begin
		set @URVAL= LEFT(@URVAL, LEN(@URVAL)-1) 
		set @sql = @sql + ' AND art.ArticleHierIDTop in ('  + @Urval + ')'
	end

	SET @sql = @sql + '
	ORDER BY sto.StoreName, art.ArticleHierNoTop,art.ArticleName '


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
	FROM #ds_StockMinAndMaxStorage

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
		from #ds_StockMinAndMaxStorage a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		'

	--print(RIGHT(@sql,4000))
	--print(LEFT(@sql,4000))
	

		exec sp_executesql @sql,
						   N'@StoreGroupNos nvarchar(max), @parInkPrisMin nvarchar(100), @parInkPrisMax nvarchar(100)',
						   @StoreGroupNos = @StoreGroupNos,
						   @parInkPrisMin = @parInkPrisMin,
						   @parInkPrisMax = @parInkPrisMax


GO






/*


exec usp_CBI_1041_ds_StockMinAndMaxStorage	@StoreGroupNos = '3004',--,3000',,3000,1725
												@parInkPrisMin = null, --- '100',
												@parInkPrisMax = null,  --'200',
												@parTop1='Y',
												@parTop2='Y',
												@parTop3='Y',
												@parTop4='Y',
												@parTop5='Y'

*/











