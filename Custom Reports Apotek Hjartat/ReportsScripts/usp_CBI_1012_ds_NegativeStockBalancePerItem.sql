go
use [VBDCM] 
go

if exists(select * from sysobjects where name = N'usp_CBI_1012_ds_NegativeStockBalancePerItem' and xtype = 'P')
drop procedure usp_CBI_1012_ds_NegativeStockBalancePerItem
go



Create Procedure [dbo].[usp_CBI_1012_ds_NegativeStockBalancePerItem]
														(
														 @StoreGroupNos As varchar(8000) = ''
														,@parSupplierNo as varchar(8000)
														,@parArticleHierNo as varchar(8000)
														,@parArticleHierNoSubGroups as varchar(8000)
														,@parArticleName as varchar(500)
														,@parArticleID as varchar(100)
														,@parEanNo as varchar(8000)
														,@parSupplierArticleID as varchar(100)
														)
AS
BEGIN 														

	SET NOCOUNT ON;

--Rapport nr 1012													
	DECLARE @sql As nvarchar(max) = ''
	DECLARE @ParamDefinition nvarchar(max)

	DECLARE @colsFinal as varchar(max)
	DECLARE @colsCreateTable as varchar(max)	-- create table dynamiclly
	DECLARE @colsToInsertTbl as varchar(max)


	set @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parSupplierNo nvarchar(max), @parArticleHierNo nvarchar(max), @parArticleHierNoSubGroups nvarchar(max),
							 @parArticleID nvarchar(100), @parArticleName nvarchar(500), @parEanNo nvarchar(max), @parSupplierArticleID nvarchar(100)'

	
	if len(isnull(@parSupplierNo, '') ) > 0 
	set @sql = @sql + '
	IF OBJECT_ID(''tempdb..#supplierNoFltrTbl'') IS NOT NULL  DROP TABLE #supplierNoFltrTbl
	select a.ArticleID as ArticleID
		into #supplierNoFltrTbl
    FROM RS17_1.[RSItemESDb].[dbo].articles a
	inner join RS17_1.[RSItemESDb].[dbo].[SupplierArticles] b on a.articleno = b.ArticleNo and a.DefaultSupplierArticleNo = b.SupplierArticleNo
	inner join RS17_1.[RSItemESDb].[dbo].[Suppliers] c on c.supplierno = b.supplierno
	inner join [dbo].[SupplierOrgs] supOrg on c.SupplierID = supOrg.SupplierID
	inner join [dbo].[ufn_RBI_SplittParameterString](@parSupplierNo,'','')  on supOrg.SupplierNo = cast(ParameterValue as int)
	'

	if len(isnull(@parEanNo, '')) > 0
	set @sql = @sql  + 'IF OBJECT_ID(''tempdb..#eanFltrTbl'') IS NOT NULL  DROP TABLE #eanFltrTbl
						select articleno 
						into #eanFltrTbl
						from ean
						inner join [dbo].[ufn_RBI_SplittParameterString](@parEanNo,'','') as eanPar on ean.EANno = eanPar.ParameterValue 
						'
	
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
			null as StoreNo
			into #DimStores
			'
		End


	SET @sql = @sql + '
	IF OBJECT_ID(''tempdb..#ds_NegativeStockBalancePerItem'') IS NOT NULL  DROP TABLE #ds_NegativeStockBalancePerItem
	'

	if len(isnull(@parArticleHierNo,'')) > 0  and len(isnull(@parArticleHierNoSubGroups,'')) = 0
	begin
		set @sql = @sql + '
		;with ArticleHierNoFilter as (
		select distinct ah2.ArticleHierNo
		from ArticleHierarchys ah1 with (nolock) 
		LEFT JOIN ArticleHierarchys ah2 with (nolock) on ah2.ArticleHierLinkNo = ah1.ArticleHierNo 
			and ah2.ArticleHierLevelNo > 1
			and ah2.ArticleHierNo > 0
			and ah2.ArticleHierNo is not null
			and ah2.ArticleHierName <> ''XX''
			and ah2.ArticleHierName not like ''%Opprettet fra%'' 
			and ah2.ArticleHierName <> ''Systemgenerert'' 
			and ah2.ArticleHierNo in (select ArticleHierNo from Articles with (nolock))
		INNER JOIN [dbo].[ufn_RBI_SplittParameterString](@parArticleHierNo,'','') as ArtHierNoFiltr on ah1.ArticleHierNo = ArtHierNoFiltr.ParameterValue
		where ah1.ArticleHierNo > 0
		and ah1.ArticleHierName <> ''XX''
		and ah1.ArticleHierName not like ''%Opprettet fra%''
		and ah1.ArticleHierName <> ''Systemgenerert''
		)
		'
	end
	
	if len(isnull(@parArticleHierNo,'')) >= 0  and len(isnull(@parArticleHierNoSubGroups,'')) > 0
		set @sql = @sql + ';with ArticleHierNoFilter as (
							select distinct cast(ParameterValue as int) as ArticleHierNo
							from [dbo].[ufn_RBI_SplittParameterString](@parArticleHierNoSubGroups,'','')
						  )
						  '



	SET @sql = @sql + '
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
		art.ArticleHierID,  
		art.ArticleHierName,  
		art.SupplierName, 
		IsNull(sai.InStockQty, 0) as InStockQtySalesStock,
		tsai.TotalStockAmount as TotalNetCostAmount,
		CASE WHEN IsNull(tsai.TotalStockQty,0) <0
			THEN  IsNull(tsai.TotalStockQty,0)
			ELSE 0
		END as TotalStock,
		CASE WHEN IsNull(sai.InStockQty,0) < 0
			THEN CASE WHEN sai.AverageSalesQty = 0 or sai.AverageSalesQty IS NULL
					THEN sai.InStockQty * 28 
					ELSE ISNULL(sai.InStockQty/NULLIF(sai.AverageSalesQty/6, 0),0)
				 END
			ELSE 0
		END as RemainingDaysInStock,
		sai.LastUpdatedStockCount,
		tsai.TotalStockAmount / tsai.TotalStockQty as NetPriceDerived
	into #ds_NegativeStockBalancePerItem
	FROM StoreArticleInfos sai with (nolock)
	JOIN vw_TotalStoreArticleInfos tsai with (nolock) on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo 
	JOIN AllArticles art with (nolock) on (sai.ArticleNo = art.ArticleNo)
	'
	

	if len(isnull(@parSupplierNo,'') ) > 0 
		set @sql = @sql + 'JOIN #supplierNoFltrTbl as supTbl on art.ArticleID = supTbl.ArticleID  
		'

	if len(isnull(@parArticleHierNo,'')) > 0  and len(isnull(@parArticleHierNoSubGroups,'')) = 0
		set @sql = @sql + 'join ArticleHierNoFilter as artFiltr with (nolock) on art.articlehierno = artFiltr.ArticleHierNo
		'
	
	if len(isnull(@parEanNo,'')) > 0
		set @sql = @sql + 'JOIN #eanFltrTbl AS eanFltr on art.articleno = eanFltr.articleno
		'
	
	set @sql = @sql + '
	JOIN Stores sto with (nolock) on (sai.StoreNo = sto.StoreNo)
	JOIN #DimStores DimSto with (nolock) on (DimSto.StoreNo = sto.StoreNo)
	JOIN activeallarticleprices aaap with (nolock) on (sai.storeno = aaap.storeno and sai.articleno = aaap.articleno)
	WHERE  art.MasterArticle = 0 
	AND tsai.TotalStockQty < 0 and  articlehierid not in (610,620,630,640,510)' --art.ArticleHierNoTop not in  (5,6)  

	--print(@sql)


	if len(isnull(@parArticleName,'')) > 0 
      	set @sql = @sql + ' AND art.articleName like ''%''  + @parArticleName + ''%'''


	if len(isnull(@parArticleID,'')) > 0 
		set @sql = @sql + ' AND art.articleID = @parArticleID' 

	if len(isnull(@parSupplierArticleID,'')) > 0
		begin
			set @sql = @sql + ' AND art.ArticleNo IN (SELECT suar.ArticleNo FROM 
									 SupplierArticles AS suar WHERE ltrim(suar.SupplierArticleID)  =  @parSupplierArticleID '
			set @sql = @sql + ')'
		end


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
	FROM #ds_NegativeStockBalancePerItem

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
		from #ds_NegativeStockBalancePerItem a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		ORDER BY StoreName, ArticleHierNoTop, ArticleName 
		'



	--print (@sql)

	exec sp_executesql @sql
					   ,@ParamDefinition
					   ,@StoreGroupNos = @StoreGroupNos
					   ,@parSupplierNo = @parSupplierNo
					   ,@parArticleHierNo = @parArticleHierNo
					   ,@parArticleHierNoSubGroups = @parArticleHierNoSubGroups
					   ,@parArticleID = @parArticleID
					   ,@parArticleName = @parArticleName
					   ,@parEanNo = @parEanNo
					   ,@parSupplierArticleID = @parSupplierArticleID



END

GO

/*


exec [dbo].[usp_CBI_1012_ds_NegativeStockBalancePerItem]  @StoreGroupNos = '3000',--3004,9865,9157,9485', 
															@parSupplierNo = '1',
															@parArticleHierNo = '1',
															@parArticleHierNoSubGroups = '',--'1,19',
															@parArticleName = 'abi',
															@parArticleID = null,
															@parEanNo = '',
															@parSupplierArticleID = 55030





*/