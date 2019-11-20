go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1032_ds_StockCount_StockCountProposal')
drop procedure usp_CBI_1032_ds_StockCount_StockCountProposal
go


CREATE PROCEDURE [dbo].[usp_CBI_1032_ds_StockCount_StockCountProposal]
														(														 
															 @StoreGroupNos As varchar(8000) = ''
															, @parArticleHierNo as varchar(8000) = ''
															, @parArticleHierNoSubGroups as varchar(8000) = ''
															, @parArticleName as varchar(500) = ''
															, @ParHylla1 as varchar(50) = ''
															, @ParHylla2 as varchar(50) = ''
															, @parNotCountedInXDays As varchar(100) = ''
														)
AS
BEGIN 

	SET NOCOUNT ON;	-- This has to be here. In some installations jasper is not returning a resultset if this is not here

	--Rapport nr 1032
	declare @sql As nvarchar(max) = ''
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)

	declare @ParamDefinition nvarchar(max)
	set @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parArticleHierNo nvarchar (max), @parArticleHierNoSubGroups nvarchar(max), @parArticleName nvarchar(500),
							 @ParHylla1 as nvarchar(50), @ParHylla2 as nvarchar(50), @parNotCountedInXDays int'

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
			null as StoreNo
			into #DimStores
			'
		End


	set @sql = @sql + 'IF OBJECT_ID(''tempdb..#ds_StockCountStockCountProposal'') IS NOT NULL DROP TABLE #ds_StockCountStockCountProposal
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

	set @sql =  @sql + '
	select 
		sto.internalstoreid, 
		sto.StoreName,
		isnull(ltrim(isnull(art.WholesalerArticleID, art.SupplierArticleID )), '''') as supplierarticleid,
		isnull(cast(art.EanNo as varchar(20)), '''') as EanNo, 
		art.ArticleID,
		art.ArticleNo,
		art.ArticleName,
		-- IsNull(sai.InStockQty, 0) as InStockQtySalesStock,
		ISNULL(sai.ReservedStockQty, 0) As Reserverat,
		ISNULL(SP1.Infovalue,'''') as Hyllplats1, 
		ISNULL(SP2.Infovalue,'''') as Hyllplats2, 
		CONVERT(varchar, sai.LastUpdatedStockCount, 23) as invdatum,
		DATEDIFF(day, sai.LastUpdatedStockCount, GetDate()) as invdatum2
	into #ds_StockCountStockCountProposal
	FROM StoreArticleInfos sai with (nolock)
	JOIN Stores sto with (nolock) on (sai.StoreNo = sto.StoreNo)
	JOIN #DimStores dimStr on sto.StoreNo = dimStr.StoreNo
	JOIN vw_TotalStoreArticleInfos tsai with (nolock) on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo 
	JOIN AllArticles art with (nolock) on (sai.ArticleNo = art.ArticleNo)
	'

	if (len(isnull(@parArticleHierNo,'')) > 0  and len(isnull(@parArticleHierNoSubGroups,'')) = 0) or (len(isnull(@parArticleHierNo,'')) >= 0  and len(isnull(@parArticleHierNoSubGroups,'')) > 0)
		set @sql = @sql + 'JOIN ArticleHierNoFilter as artFiltr with (nolock) on art.articlehierno = artFiltr.ArticleHierNo 
		'

	set @sql = @sql + 
	'JOIN activeallarticleprices aaap with (nolock) on (sai.storeno = aaap.storeno and sai.articleno = aaap.articleno)
	LEFT JOIN StoreArticleInfoDetails AS SP1 with (nolock) ON  sai.storeno = SP1.STORENO AND sai.ArticleNo = SP1.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
	LEFT OUTER JOIN StoreArticleInfoDetails AS SP2 with (nolock) ON  sai.storeno = sp2.storeNo and sai.ArticleNo = SP2.ArticleNo AND SP2.infoid = ''RS_ShelfPosition2''
	WHERE  (art.MasterArticle = 0 AND tsai.TotalStockQty <> 0) '



	if len(@parArticleName) > 0 
      	set @sql = @sql + ' AND art.articleName like ''%''+ @parArticleName +''%'''


	if (@ParHylla1 Not Like '')
		set @sql = @sql + ' AND SP1.Infovalue like ''''+@ParHylla1+''%'''

	if (@ParHylla2 Not Like '')
		set @sql = @sql + ' AND SP2.Infovalue like ''''+@ParHylla2+''%'''


	if Len(@parNotCountedInXDays) > 0 and isnumeric(@parNotCountedInXDays) = 1
		set @sql = @sql + ' AND isnull(dateadd(d, @parNotCountedInXDays ,sai.LastUpdatedStockCount) , getdate()) <= GetDate()'


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
	FROM #ds_StockCountStockCountProposal

	'

-- Checking if there is one store or more stores according that we execute proc with store no or with zero.
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
		from #ds_StockCountStockCountProposal a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo
		ORDER BY StoreName, ArticleName  
		'
			
	--print(@sql)

	exec sp_executesql @sql
					   ,@ParamDefinition
					   ,@StoreGroupNos = @StoreGroupNos
					   ,@parArticleHierNo = @parArticleHierNo
					   ,@parArticleHierNoSubGroups = @parArticleHierNoSubGroups
					   ,@parArticleName = @parArticleName
					   ,@ParHylla1 = @ParHylla1
					   ,@ParHylla2 = @ParHylla2
					   ,@parNotCountedInXDays = @parNotCountedInXDays



END
GO


/*

exec [dbo].usp_CBI_1032_ds_StockCount_StockCountProposal									 
															 @StoreGroupNos = '3000'--,1725,1000,3010'
															, @parArticleHierNo = '' --'1,19'
															, @parArticleHierNoSubGroups = ''--'1,19' --'1,19'--'123,321'
															, @parArticleName = ''
															, @ParHylla1 = ''
															, @ParHylla2 = '' --'B2'
															, @parNotCountedInXDays = '120'

*/
