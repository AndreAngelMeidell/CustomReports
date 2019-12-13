go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1011_ds_StockValuePerItem')
drop procedure usp_CBI_1011_ds_StockValuePerItem
GO


Create Procedure [dbo].[usp_CBI_1011_ds_StockValuePerItem]
														(
															 @StoreGroupNos As varchar(8000)= ''
															, @parSupplierNo as varchar(8000)= ''
															, @parSupplierArticleID As varchar(100)= ''
															, @ParNarcoticsClass As varchar(200)= ''
															, @parInkPrisMin as varchar(1000)= ''
															, @parInkPrisMax as varchar(1000)= ''
															, @parTop1 as varchar(1)='Y'
															, @parTop2 as varchar(1)='Y'
															, @parTop3 as varchar(1)='Y'
															, @parTop4 as varchar(1)='Y'
															, @parTop5 as varchar(1)='Y'
															, @URVAL as varchar (200)= ''
														)
AS
BEGIN 

	set nocount on;	-- This has to be here. In some installations jasper is not returning a resultset if this is not here

	declare @sql As nvarchar(max) = ''
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)

	declare @ParamDefinition nvarchar(max)
	set @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parSupplierNo nvarchar (max), @parSupplierArticleID nvarchar(100),  @ParNarcoticsClass nvarchar(200),
							 @parInkPrisMin as nvarchar(1000), @parInkPrisMax as nvarchar(1000)'

------------------------------------------------------------------------------------------------------
	
	if len(@StoreGroupNos) > 0 
		Begin
			
			set @sql = @sql +  '
			IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL DROP TABLE #DimStores
			select StoreNo
			into #DimStores
			from dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) 
			'
		End
	else
		Begin
			SET @sql = @sql +  '
			IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL DROP TABLE #DimStores
			select 
			null as StoreNo,
			null as StoreID
			into #DimStores
			'
		End

	DECLARE @StoreIds NVARCHAR(MAX) 
	

	SELECT @StoreIds = COALESCE(@StoreIds + ',', '') + stor.StoreID 
	from 
	(
	select ParameterValue from [dbo].[ufn_RBI_SplittParameterString] (@StoreGroupNos,',')
		union
	select case when len(@StoreGroupNos) > 0 then '0' else null end as ParameterValue 
	) as storC
	inner join stores stor with (nolock) on storC.ParameterValue = stor.StoreNo
	
	set @sql = @sql + '

	Declare @SqlText nvarchar(4000)

	Set @SqlText = ''SELECT * FROM RSItemESDB.dbo.fn_CBI_uniqueArticlePrices (''''' + @StoreIds + ''''')''

	if object_id(''tempdb..#uniqueArticlePrices'') is not null drop table #uniqueArticlePrices
	create table #uniqueArticlePrices (
		storeno  int
		,storeid  varchar(100)
		,articleno  int
		,articleid  varchar(100)
		,SalesPrice  money
		,NetCostPrice  money
	)

	CREATE CLUSTERED INDEX indx_tempUniqueArtPrices on #uniqueArticlePrices (ArticleID, storeid) 

	insert into #uniqueArticlePrices
	EXEC RS17_1.RSItemESDB.dbo.sp_executesql @SqlText

	--select * from #uniqueArticlePrices
	'


	if len(isnull(@parSupplierNo, '') ) > 0 
	set @sql = @sql + '	IF OBJECT_ID(''tempdb..#supplierNoFltrTbl'') IS NOT NULL  DROP TABLE #supplierNoFltrTbl
						select distinct  cast(ParameterValue as int) as supplierNo 
					    into #supplierNoFltrTbl
						from [dbo].[ufn_RBI_SplittParameterString](@parSupplierNo,'','') 
						'

	if len(isnull(@parSupplierArticleID, '') ) > 0 
	set @sql = @sql + '	IF OBJECT_ID(''tempdb..#supplierArtIdFltrTbl'') IS NOT NULL  DROP TABLE #supplierArtIdFltrTbl
						select distinct  ParameterValue as SupplierArticleID 
					    into #supplierArtIdFltrTbl
						from [dbo].[ufn_RBI_SplittParameterString](@parSupplierArticleID,'','') 
						'

	set @sql = @sql + '
	IF OBJECT_ID(''tempdb..#ds_StockValuePerItem'') IS NOT NULL  DROP TABLE #ds_StockValuePerItem
	Select 
		sto.internalstoreid, 
		sto.StoreName,  
		ltrim(isnull(art.WholesalerArticleID, art.SupplierArticleID )) as supplierarticleid,
		art.EanNo, 
		art.ArticleID, 
		art.ArticleName,
		art.ArticleNo, 
		art.ArticleHierNoTop, 
		art.ArticleHierNameTop,
  		IsNull(sai.InStockQty, 0) as InStockQtySalesStock,
		IsNull(tsai.TotalStockAmount,0) as Totaltlagervarde,
		CASE WHEN IsNull(tsai.TotalStockQty,0) > 0
			THEN  IsNull(tsai.TotalStockQty,0)
			ELSE 0
		END as TotalStock,
		CASE WHEN IsNull(sai.InStockQty,0) > 0
			THEN CASE WHEN sai.AverageSalesQty = 0 or sai.AverageSalesQty IS NULL
					THEN sai.InStockQty * 28 
					ELSE ISNULL(sai.InStockQty/NULLIF(sai.AverageSalesQty/6, 0),0)
				 END
			ELSE 0
		END as RemainingDaysInStock,
	  CASE WHEN art.ArticleHierIDTop=(100) THEN (''Läkemdel RX'')
		 WHEN art.ArticleHierIDTop=(200) THEN (''Läkemdel OTC'')
		 WHEN art.ArticleHierIDTop=(300) THEN (''Livsmedel RX'')
		 WHEN art.ArticleHierIDTop=(400) THEN (''Hjälpmedel medicinskt'')
		 WHEN art.ArticleHierIDTop=(900) THEN (''Handelsvaror'')
	  ELSE ('''')
	  END as Gruppering,
		--CASE WHEN art.ArticleHierNoTop=(1) THEN (''Läkemdel RX'')
		--		WHEN art.ArticleHierNoTop=(2) THEN (''Läkemdel OTC'')
		--		WHEN art.ArticleHierNoTop=(3) THEN (''Livsmedel RX'')
		--		WHEN art.ArticleHierNoTop=(4) THEN (''Hjälpmedel medicinskt'')
		--		WHEN art.ArticleHierNoTop>(49) THEN (''Handelsvaror'')
		--	ELSE ('''')
		--END as Gruppering,
		coalesce(uapReg.NetCostPrice, uapCentr.NetCostPrice) as ikopspris,
		coalesce(uapReg.salesprice, uapCentr.salesprice) as förspris,
		tsai.TotalStockAmount / tsai.TotalStockQty as Vagtinpris
	into #ds_StockValuePerItem
	FROM StoreArticleInfos sai
	JOIN vw_TotalStoreArticleInfos tsai on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo 
	JOIN AllArticles art on (sai.ArticleNo = art.ArticleNo and art.MasterArticle=0 and art.ArticleStatus=1)
	'
	
	if len(isnull(@parSupplierNo,'') ) > 0 
		set @sql = @sql + 'JOIN #supplierNoFltrTbl as supTbl on art.supplierno = supTbl.supplierNo 
		'
	if len(isnull(@parSupplierArticleID, '') ) > 0 
		set @sql = @sql + 'JOIN #supplierArtIdFltrTbl as supArtId on supArtId.SupplierArticleID = art.SupplierArticleID
		'

	set @sql = @sql + 'JOIN Stores sto on (sai.StoreNo = sto.StoreNo)
	JOIN #DimStores dimSto on (dimSto.StoreNo = sto.StoreNo)
	JOIN #UniqueArticlePrices uapCentr with (nolock)  on ( uapCentr.ArticleID = art.ArticleID and uapCentr.StoreID = 0 )
	LEFT outer JOIN ArticleInfos AS ArticleInfoNarcoClass ON  (sai.articleno = ArticleInfoNarcoClass.articleNo and ArticleInfoNarcoClass.infoid = ''RS_DrugClassification'')
	LEFT JOIN #UniqueArticlePrices uapReg with (nolock)  on ( uapReg.ArticleID = art.ArticleID and uapReg.StoreID = sto.StoreID  and uapReg.StoreID <> 0 ) 
	WHERE  tsai.TotalStockQty > 0
	 '

	If len(@parInkPrisMin) > ''
		set @sql = @sql + ' AND coalesce(uapReg.NetCostPrice, uapCentr.NetCostPrice) >= @parInkPrisMin'

	If len(@parInkPrisMax) >''
		set @sql = @sql + ' AND coalesce(uapReg.NetCostPrice, uapCentr.NetCostPrice) <= @parInkPrisMax'

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

	if (@ParNarcoticsClass not like '') 
	set @sql = @sql + '  and ArticleInfoNarcoClass.Infovalue Like ''''+ @ParNarcoticsClass +''%'' '



	set @sql = @sql + '
	IF OBJECT_ID(''tempdb..#ds_StockValuePerItemTotal'') IS NOT NULL  DROP TABLE #ds_StockValuePerItemTotal 
		select  internalstoreid
			,StoreName
			,supplierarticleid
			,EanNo
			,ArticleID
			,ArticleName
			,ArticleNo
			,ArticleHierNoTop
			,ArticleHierNameTop
			,InStockQtySalesStock
			,sum(Totaltlagervarde) as Totaltlagervarde	
			,TotalStock
			,RemainingDaysInStock
			,case when  GROUPING_ID(internalstoreid, StoreName, supplierarticleid, EanNo, ArticleID, ArticleName, ArticleNo, ArticleHierNoTop, ArticleHierNameTop, InStockQtySalesStock	
						,Totaltlagervarde, TotalStock, RemainingDaysInStock, Gruppering	, ikopspris, förspris, Vagtinpris) = 131063 
				  then ''Sum Huvudgrupp '' + Gruppering
				  when  GROUPING_ID(internalstoreid, StoreName, supplierarticleid, EanNo, ArticleID, ArticleName, ArticleNo, ArticleHierNoTop, ArticleHierNameTop, InStockQtySalesStock	
						,Totaltlagervarde, TotalStock, RemainingDaysInStock, Gruppering	, ikopspris, förspris, Vagtinpris) = 131071
				  then ''Total sum''
				  else Gruppering
			end as Gruppering	
			,ikopspris
			,förspris
			,Vagtinpris
			,IDENTITY(INT,1,1) AS rowSortId
	into #ds_StockValuePerItemTotal
	from #ds_StockValuePerItem
	group by GROUPING SETS
		(	
			(internalstoreid, StoreName, supplierarticleid, EanNo, ArticleID, ArticleName, ArticleNo, ArticleHierNoTop, ArticleHierNameTop, InStockQtySalesStock	
			,Totaltlagervarde, TotalStock, RemainingDaysInStock, Gruppering	, ikopspris, förspris, Vagtinpris),
			(Gruppering),
			()
		)
	'


---------------------------------------------------------------------------------------------------------------------------	
-- Geting additional article info and adding to final select
---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------
-- Function ufn_CBI_getDynamicColsStrings available values for parameter @typeOfCols
-- Col types descriptions
-- 1 - Creating string to create temp table with dynamic fields this one forms dynamic fields;	(@colsCreateTable)
-- 2 - Creating string to fill temp table with values insert into #dynamic (-values-);	(@colsToInsertTbl)
-- 3 - Creating string to select Cols from final select;	(@colsFinal)
-- 4 - Creating string to pivot dynamic cols in proc; (@colsPivot)
-- 5 - Creating string to filter pivot in proc. (@colsPivotFilt)
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
	FROM #ds_StockValuePerItemTotal

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
		from #ds_StockValuePerItemTotal a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		order by rowSortId asc
		'


	--print(@sql)
	exec sp_executesql @sql
					   ,@ParamDefinition
					   ,@StoreGroupNos = @StoreGroupNos
					   ,@parSupplierNo = @parSupplierNo
					   ,@parSupplierArticleID = @parSupplierArticleID
					   ,@ParNarcoticsClass = @ParNarcoticsClass
					   ,@parInkPrisMin =  @parInkPrisMin
					   ,@parInkPrisMax = @parInkPrisMax


END
GO



/*

exec usp_CBI_1011_ds_StockValuePerItem	@StoreGroupNos = '3000,3010,1202,1725,1152,1562',
											@parSupplierNo = '28,1',
											@parSupplierArticleID = '160041,160052',--'202998,000106',
											@ParNarcoticsClass ='III - Narkotika',
											@parInkPrisMin = '1',
											@parInkPrisMax = '200',
											@parTop1='Y',
											@parTop2='Y',
											@parTop3='Y',
											@parTop4='Y',
											@parTop5='Y',
											@Urval=''




exec usp_CBI_1011_ds_StockValuePerItem	@StoreGroupNos = '3004,3010,1202,1725,1152,1562',
											@parSupplierNo = '', --'28,1',
											@parSupplierArticleID = NULL, --'160041,160052',--'202998,000106',
											@ParNarcoticsClass = NULL, -- 'III - Narkotika',
											@parInkPrisMin = NULL, --'1',
											@parInkPrisMax = NULL, --'200',
											@parTop1='Y',
											@parTop2='Y',
											@parTop3='Y',
											@parTop4='Y',
											@parTop5='Y',
											@Urval=''



*/



