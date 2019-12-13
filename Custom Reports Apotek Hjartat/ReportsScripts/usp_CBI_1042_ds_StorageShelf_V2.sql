go
use [VBDCM]
go


if exists(select * from sysobjects WHERE name = N'usp_CBI_1042_ds_StorageShelf'  AND xtype = 'P' )
drop procedure usp_CBI_1042_ds_StorageShelf
GO


CREATE PROCEDURE [dbo].[usp_CBI_1042_ds_StorageShelf] (
	@StoreGroupNos AS VARCHAR(8000) = '',
	@parDaysSinceLastSold AS VARCHAR(100)= '',
	@parMinimumStockQty AS VARCHAR(100) = '',
	@parMaximumStockQty AS VARCHAR(100) = '',
	@parInkPrisMin AS VARCHAR(100) = '',
	@parInkPrisMax AS VARCHAR(100) = '',
	@parTop1 AS VARCHAR(1) = '',
	@parTop2 AS VARCHAR(1) = '',
	@parTop3 AS VARCHAR(1) = '',
	@parTop4 AS VARCHAR(1) = '',
	@parTop5 AS VARCHAR(1) = ''
)
as

	--Rapport nr 1042
	SET NOCOUNT ON;

	DECLARE @URVAL AS VARCHAR (100)
	DECLARE @URVAL2 AS VARCHAR (100)


	SET @Urval=''
	SET @Urval2=''



	DECLARE @sql AS NVARCHAR(MAX) = ''
	DECLARE @colsFinal AS VARCHAR(MAX)
	DECLARE @colsCreateTable AS VARCHAR(MAX)	-- create table dynamiclly
	DECLARE @colsToInsertTbl AS VARCHAR(MAX)

	DECLARE @ParamDefinition NVARCHAR(MAX)
	SET @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parDaysSinceLastSold int, @parMinimumStockQty nvarchar(100), @parMaximumStockQty nvarchar(100), 
	@parInkPrisMin nvarchar(100), @parInkPrisMax nvarchar(100)'

------------------------------------------------------------------------------------------------------

	IF LEN(@STOREGROUPNOS) > 0 
		BEGIN
			
			SET @sql = @sql +  '
			IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL DROP TABLE #DimStores
			SELECT StoreNo
			INTO #DimStores
			FROM dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) 
			'
		END
	ELSE
		BEGIN
			SET @sql = @sql +  '
			IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL DROP TABLE #DimStores
			SELECT 
			NULL AS StoreNo,
			NULL AS StoreID
			INTO #DimStores
			'
		END

	
	DECLARE @StoreIds NVARCHAR(MAX) 
	

	SELECT @StoreIds = COALESCE(@StoreIds + ',', '') + stor.StoreID 
	FROM 
	(
	SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString] (@StoreGroupNos,',')
		UNION
	SELECT CASE WHEN LEN(@StoreGroupNos) > 0 THEN '0' ELSE NULL END AS ParameterValue 
	) AS storC
	INNER JOIN stores stor WITH (NOLOCK) ON storC.ParameterValue = stor.StoreNo
	
	SET @sql = @sql + '

	DECLARE @SqlText NVARCHAR(4000)

	SET @SqlText = ''SELECT * FROM RSItemESDB.dbo.[fn_CBI_uniqueArticlePrices] (''''' + @StoreIds + ''''')''

	IF OBJECT_ID(''tempdb..#uniqueArticlePrices'') IS NOT NULL DROP TABLE #uniqueArticlePrices
	create table #uniqueArticlePrices (
		storeno  INT
		,storeid VARCHAR(100)
		,articleno  INT
		,articleid  VARCHAR(100)
		,SalesPrice MONEY
		,NetCostPrice MONEY
	)

	CREATE CLUSTERED INDEX indx_tempUniqueArtPrices on #uniqueArticlePrices (ArticleID, storeid) 

	INSERT INTO #uniqueArticlePrices
	EXEC RS17_1.RSItemESDB.dbo.sp_executesql @SqlText

	'


	set @sql = @sql + ' 
			IF OBJECT_ID(''tempdb..#ds_StorageShelf'') IS NOT NULL DROP TABLE #ds_StorageShelf
			SELECT  
				sto.internalstoreid, 
				sto.StoreName, 
				ltrim(isnull(art.WholesalerArticleID, art.SupplierArticleID )) as supplierarticleid,
				art.ArticleName, 
				art.ArticleID,
				art.ArticleNo,
				art.EanNo,
				art.SupplierName,
				art.ArticleHierNoTop,
				art.ArticleHierNameTop,
				art.ArticleHierID,
				art.ArticleHierName, 
				tsai.TotalStockAmount as lagervarde,
				sai.MinimumStockQty,
				sai.MaximumStockQty,
				COALESCE(uapReg.NetCostPrice, uapCentr.NetCostPrice) as NetCostPrice,
				ISNULL(SP1.Infovalue,'''') as Hyllplats1, 
				ISNULL(SP2.infovalue,'''') as Hyllplats2,

				ISNULL(sai.InStockQty,0) as InStockQtySalesStock,
				CASE WHEN IsNull(tsai.TotalStockQty,0) > 0
					THEN  IsNull(tsai.TotalStockQty,0)
					ELSE 0
				END AS TotalStoQty,

				CASE WHEN art.ArticleHierIDTop=(100) THEN (''Läkemdel RX'')
					 WHEN art.ArticleHierIDTop=(200) THEN (''Läkemdel OTC'')
					 WHEN art.ArticleHierIDTop=(300) THEN (''Livsmedel RX'')
					 WHEN art.ArticleHierIDTop=(400) THEN (''Hjälpmedel medicinskt'')
					 WHEN art.ArticleHierIDTop=(900) THEN (''Handelsvaror'')
					 ELSE ('''')
				END AS Gruppering,

				CASE WHEN (sai.LastUpdatedSoldDate) IS NOT NULL
				THEN DATEDIFF(day, sai.LastUpdatedSoldDate, getdate())    
				ELSE DATEDIFF(day,(ISNULL(sai.LastUpdatedSoldDate,sai.LastPurchased)),getdate ())
				END AS LastUpdatedSoldDateDays,
				sai.LastUpdatedSoldDate,sai.LastPurchased,

				CASE WHEN sai.AverageSalesQty = 0 OR sai.AverageSalesQty IS NULL
					THEN sai.InStockQty * 28 
					ELSE ISNULL(sai.InStockQty/NULLIF(sai.AverageSalesQty/6, 0),0)
				END AS RemainingDaysInStock
			into #ds_StorageShelf
			FROM StoreArticleInfos sai WITH (NOLOCK)
			JOIN dbo.vw_TotalStoreArticleInfos tsai WITH (NOLOCK) ON tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo 
			JOIN Stores sto WITH (NOLOCK) ON (sai.StoreNo = sto.StoreNo)
			JOIN #DimStores dimStr ON sto.StoreNo = dimStr.StoreNo
			JOIN AllArticles art WITH (NOLOCK) ON (sai.ArticleNo = art.ArticleNo AND art.MasterArticle=0 AND art.ArticleStatus=1)
			JOIN #UniqueArticlePrices uapCentr WITH (NOLOCK)  ON  uapCentr.ArticleID = art.ArticleID AND uapCentr.StoreID = 0 
			LEFT outer JOIN StoreArticleInfoDetails AS SP1 WITH (NOLOCK) ON  sai.storeno = sp1.storeNo AND sp1.ArticleNo = art.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
			LEFT outer JOIN StoreArticleInfoDetails AS SP2 WITH (NOLOCK) ON  sai.storeno = sp2.storeNo AND sp2.ArticleNo = art.ArticleNo AND SP2.infoid = ''RS_ShelfPosition2''
			LEFT JOIN #UniqueArticlePrices uapReg WITH (NOLOCK)  ON uapReg.ArticleID = art.ArticleID AND uapReg.StoreID = sto.StoreID  AND uapReg.StoreID <> 0
			WHERE tsai.TotalStockQty> 0
	'


	IF LEN(@parDaysSinceLastSold) > 0 
		SET @sql = @sql + ' AND sai.LastUpdatedSoldDate IS NOT NULL AND sai.LastUpdatedSoldDate +  @parDaysSinceLastSold < GETDATE()
		AND sai.LastPurchased +  @parDaysSinceLastSold < GETDATE()'  

	IF LEN(@parInkPrisMin) > ''
		SET @sql = @sql + ' AND coalesce(uapReg.NetCostPrice, uapCentr.NetCostPrice) >=  @parInkPrisMin'
	IF LEN(@parInkPrisMax) >''
		SET @sql = @sql + ' AND coalesce(uapReg.NetCostPrice, uapCentr.NetCostPrice) <=  @parInkPrisMax'


	IF @parTop1= 'Y' 
		SET @URVAL = '100,' 
	IF @parTop2= 'Y'
		SET @URVAL = '200,'+@Urval 
	IF @parTop3= 'Y'
		SET @URVAL = '300,'+@Urval 
	IF @parTop4= 'Y'
		SET @URVAL = '400,'+@Urval 
	IF @parTop5= 'Y'	
		SET @URVAL = '900,'+@Urval 

	IF LEN(@URVAL) > 0
	BEGIN
		SET @URVAL= LEFT(@URVAL, LEN(@URVAL)-1) 
		SET @Sql = @Sql + ' AND art.ArticleHierIDTop IN ('  + @Urval + ')'
	END

	SET @Sql = @Sql + ' OR sai.TotalStockQty> 0'


	IF LEN(@parDaysSinceLastSold) > 0 
		SET @sql = @sql + ' AND (ISNULL(sai.LastUpdatedSoldDate,sai.LastPurchased)) +  @parDaysSinceLastSold < GETDATE()'  

	IF LEN(@parInkPrisMin) > ''
		SET @sql = @sql + ' AND COALESCE(uapReg.NetCostPrice, uapCentr.NetCostPrice) >= @parInkPrisMin'

	IF LEN(@parInkPrisMax) >''
		SET @sql = @sql + ' AND COALESCE(uapReg.NetCostPrice, uapCentr.NetCostPrice) <= @parInkPrisMax'

	IF @parTop1= 'Y' 
		SET @URVAL2 = '100,' 
	IF @parTop2= 'Y'
		SET @URVAL2 = '200,'+@Urval2 
	IF @parTop3= 'Y'
		SET @URVAL2 = '300,'+@Urval2 
	IF @parTop4= 'Y'
		SET @URVAL2 = '400,'+@Urval2 
	IF @parTop5= 'Y'	
		SET @URVAL2 = '900,'+@Urval2 

	IF LEN(@URVAL2) > 0
	BEGIN
		SET @URVAL2= LEFT(@URVAL2, LEN(@URVAL2)-1) 
		SET @sql = @sql + ' AND art.ArticleHierNoTop in ('  + @URVAL2 + ')'
	END


	SET @sql = @sql + ' 
	IF OBJECT_ID(''tempdb..#ds_StorageShelfWithTotals'') IS NOT NULL DROP TABLE #ds_StorageShelfWithTotals
		SELECT 
			1 AS id
			,internalstoreid	
			,StoreName	
			,supplierarticleid	
			,ArticleName	
			,ArticleID
			,ArticleNo
			,EanNo	
			,SupplierName	
			,ArticleHierNoTop	
			,ArticleHierNameTop	
			,ArticleHierID	
			,ArticleHierName	
			,lagervarde	
			,MinimumStockQty	
			,MaximumStockQty	
			,NetCostPrice	
			,Hyllplats1	
			,Hyllplats2	
			,InStockQtySalesStock	
			,TotalStoQty
			,Gruppering AS GrupperingOrd
			,Gruppering	
			,LastUpdatedSoldDateDays	
			,LastUpdatedSoldDate	
			,LastPurchased	
			,RemainingDaysInStock
		INTO #ds_StorageShelfWithTotals
		FROM #ds_StorageShelf
		UNION ALL
		SELECT 
			2 AS id
			,null AS internalstoreid	
			,null AS StoreName	
			,null AS supplierarticleid	
			,null AS ArticleName
			,null AS ArticleNo	
			,null AS ArticleID	
			,null AS EanNo	
			,null AS SupplierName	
			,null AS ArticleHierNoTop	
			,null AS ArticleHierNameTop	
			,null AS ArticleHierID	
			,null AS ArticleHierName	
			,SUM(ISNULL(lagervarde, 0)) AS lagervardeTotal	
			,null AS MinimumStockQty	
			,null AS MaximumStockQty	
			,null AS NetCostPrice	
			,null AS Hyllplats1	
			,null AS Hyllplats2	
			,null AS InStockQtySalesStock	
			,SUM(TotalStoQty) AS lagervardeTotal
			,Gruppering AS GrupperingOrd	
			,''Sum Huvudgrupp '' + Gruppering	
			,null AS LastUpdatedSoldDateDays	
			,null AS LastUpdatedSoldDate	
			,null AS LastPurchased	
			,null AS RemainingDaysInStock
		FROM #ds_StorageShelf
		GROUP BY Gruppering
'


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
	FROM #ds_StorageShelf

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
		from #ds_StorageShelfWithTotals a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		order by a.GrupperingOrd, a.id, a.StoreName, a.ArticleHierNoTop, a.ArticleName'



	--print(right(@sql,2000))

	exec sp_executesql @sql,
					   @ParamDefinition,
					   @StoreGroupNos = @StoreGroupNos,
					   @parDaysSinceLastSold = @parDaysSinceLastSold,
					   @parMinimumStockQty = @parMinimumStockQty,
					   @parMaximumStockQty = @parMaximumStockQty,
					   @parInkPrisMin = @parInkPrisMin,
					   @parInkPrisMax = @parInkPrisMax


GO



/*

exec [dbo].[usp_CBI_1042_ds_StorageShelf] @StoreGroupNos = '3000,3004'

*/