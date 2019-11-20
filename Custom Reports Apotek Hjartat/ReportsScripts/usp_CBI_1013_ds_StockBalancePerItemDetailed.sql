go
use[VBDCM] 
go

if exists(select * from sysobjects where name = N'usp_CBI_1013_ds_StockBalancePerItemDetailed' and xtype = 'P')
drop procedure usp_CBI_1013_ds_StockBalancePerItemDetailed
go


Create procedure [dbo].[usp_CBI_1013_ds_StockBalancePerItemDetailed] (	@parStoreNo As varchar(100) = ''
																	,@parSupplierNo as varchar(8000) = ''
																	,@parArticleHierNo as varchar(8000) = ''
																	,@parArticleHierNoSubGroups as varchar(8000) = ''
																	,@parArticleName as varchar(500) = ''
																	,@parArticleID as varchar(100) = ''
																	,@parEanNo as varchar(8000) = ''
																	,@parSupplierArticleID as varchar(100) = '')
as
	SET NOCOUNT ON;

	DECLARE @sql As nvarchar(max) = ''
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)
	
	DECLARE @ParamDefinition nvarchar(max)

	set @ParamDefinition = N'@parStoreNo nvarchar(100), @parSupplierNo nvarchar(max), @parArticleHierNo nvarchar(max), @parArticleHierNoSubGroups nvarchar(max),
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
	

	set @sql = @sql + '	IF OBJECT_ID(''tempdb..#ds_StockBalancePerItemDetailed'') IS NOT NULL  DROP TABLE #ds_StockBalancePerItemDetailed'

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

	set @sql = @sql + '
	Select 
		sto.internalstoreid, 
		sto.StoreName, 
		ltrim(isnull(art.WholesalerArticleID, art.SupplierArticleID )) as supplierarticleid,
		art.EanNo, 
		art.ArticleID, 
		art.ArticleName,
		art.ArticleNo,
		-- Netp.infovalue as AIP, 
		art.ArticleHierID,  
		art.ArticleHierName,  
		art.SupplierName, 
		IsNull(sai.InStockQty, 0) as InStockQtySalesStock,
		tsai.TotalStockAmount as TotalNetCostAmount,
		IsNull(sai.AvailableStockQty, 0) as AvalibleStock,
		IsNull(sai.MinimumStockQty, 0) as MinLager,
		IsNull(sai.MaximumStockQty, 0) as MaxLager,
		IsNull(sai.StockInOrderQty, 0) as OrderedQty,
		isnull(SP1.Infovalue,'''') as Hyllplats1, 
		Sai.InStockQty-sai.AvailableStockQty as Diff,
		sai.LastUpdatedStockCount,
		tsai.TotalStockAmount / tsai.TotalStockQty as NetPriceDerived,
		art.supplierno
	into #ds_StockBalancePerItemDetailed
	FROM StoreArticleInfos sai
	JOIN vw_TotalStoreArticleInfos tsai on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo 
	JOIN AllArticles art on (sai.ArticleNo = art.ArticleNo)
	'

	if len(isnull(@parSupplierNo,'') ) > 0 
		set @sql = @sql + 'JOIN #supplierNoFltrTbl as supTbl on art.ArticleID = supTbl.ArticleID  
		'

	if (len(isnull(@parArticleHierNo,'')) > 0  and len(isnull(@parArticleHierNoSubGroups,'')) = 0) or (len(isnull(@parArticleHierNo,'')) >= 0  and len(isnull(@parArticleHierNoSubGroups,'')) > 0)
		set @sql = @sql + 'JOIN ArticleHierNoFilter as artFiltr with (nolock) on art.articlehierno = artFiltr.ArticleHierNo 
		'

	if LEN(isnull(@parEanNo,'')) > 0
		set @sql = @sql + 'JOIN #eanFltrTbl AS eanFltr on art.articleno = eanFltr.articleno
		'

	set @sql = @sql + 
	'JOIN Stores sto with (nolock) on (sai.StoreNo = sto.StoreNo)
	JOIN activeallarticleprices aaap  with (nolock) on (sai.storeno = aaap.storeno and sai.articleno = aaap.articleno)
	LEFT JOIN StoreArticleInfoDetails AS SP1 with (nolock) ON  sai.storeno = SP1.STORENO AND sai.ArticleNo = SP1.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
	WHERE  art.MasterArticle = 0 
	AND tsai.TotalStockQty > 0 '

	if len(isnull(@parStoreNo,'')) > 0
		set @sql = @sql + ' and sai.StoreNo = @parStoreNo'

	if len(isnull(@parArticleName,'')) > 0 
		set @sql = @sql + ' AND art.articleName like ''%''+ @parArticleName +''%'''

	if len(isnull(@parArticleID,'')) > 0 
		set @sql = @sql + ' AND art.articleID = @parArticleID' 

	if Len(isnull(@parSupplierArticleID,'')) > 0
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
	FROM #ds_StockBalancePerItemDetailed


	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'


	set @sql = @sql + '
		(select a.*,
		'+ @colsFinal
		+'
		from #ds_StockBalancePerItemDetailed a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		) ORDER BY StoreName, ArticleName
		'

	declare @SqlBack nvarchar(4000) = right(@sql, 4000) 

	print (@SqlBack)

	exec sp_executesql @sql,
					   @ParamDefinition,
					   @parStoreNo = @parStoreNo,
					   @parSupplierNo = @parSupplierNo,
					   @parArticleHierNo = @parArticleHierNo,
					   @parArticleHierNoSubGroups = @parArticleHierNoSubGroups,
					   @parArticleID = @parArticleID,
					   @parArticleName = @parArticleName,
					   @parEanNo = @parEanNo,
					   @parSupplierArticleID = @parSupplierArticleID


go

/*


exec usp_CBI_1013_ds_StockBalancePerItemDetailed   @parStoreNo = '3010'
													 ,@parSupplierNo = null --''--'1,27' --'28,1,27,54,7,2,59,14,12,65,45,47,34,32,11,57,60,61'---'1,27'
													 ,@parArticleHierNo = null -- '163' --'1,19' --'1,19' --''
													 ,@parArticleHierNoSubGroups = null --'' --'145,146,147,148' --'1,19'
													 ,@parArticleName = null-- ''
													 ,@parArticleID = null -- '' --'335'
													 ,@parEanNo = null --'' --'7046264430651,5060064171394,5060064171400' --'4046719869824'
													 ,@parSupplierArticleID = null --'' -- '13708'



*/







