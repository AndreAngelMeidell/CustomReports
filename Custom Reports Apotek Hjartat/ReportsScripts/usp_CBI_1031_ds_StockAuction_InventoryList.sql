go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1031_ds_StockAuction_InventoryList')
drop procedure usp_CBI_1031_ds_StockAuction_InventoryList
go


CREATE Procedure [dbo].[usp_CBI_1031_ds_StockAuction_InventoryList]
														(
															@parStoreNo as varchar(500) = ''
															,@parStockCountNo As varchar(10) = ''
															,@parArticleHierNo As varchar(8000) = ''
															,@parArticleHierNoSubGroups As varchar(8000) = ''
															,@parSupplierNo As varchar(8000) = ''
															,@parArticleName As varchar(500) = ''
															,@parOrderBy As varchar(100) = ''
															,@parShowNumberInDPacks  As varchar(1) = 'N'
														)
AS
BEGIN 

	--Rapport nr 1031
	set NOCOUNT ON 
	set ANSI_WARNINGS OFF
	set ARITHABORT OFF


	declare @sql As nvarchar(max) = ''
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)

	declare @ParamDefinition nvarchar(max)
	set @ParamDefinition = N'@parStoreNo nvarchar(500), @parStockCountNo nvarchar(10), @parArticleHierNo nvarchar (max), @parArticleHierNoSubGroups nvarchar(max),
							 @parSupplierNo nvarchar (max), @parArticleName nvarchar(500), @parOrderBy nvarchar(100), @parShowNumberInDPacks nvarchar(1)'


	set @sql = @sql + 'IF OBJECT_ID(''tempdb..ds_StockAuction_InventoryList'') IS NOT NULL DROP TABLE ds_StockAuction_InventoryList
	'

	if len(isnull(@parSupplierNo, '') ) > 0 
	set @sql = @sql + '	IF OBJECT_ID(''tempdb..#supplierNoFltrTbl'') IS NOT NULL  DROP TABLE #supplierNoFltrTbl
						select distinct  cast(ParameterValue as int) as supplierNo 
					    into #supplierNoFltrTbl
						from [dbo].[ufn_RBI_SplittParameterString](@parSupplierNo,'','')
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

	set @sql = @sql + '
		select 
			isnull(art.SupplierName,'''') as SupplierName,
			isnull(art.ArticleHierID, art.ArticleHierNo) as ArticleHierNo,
			art.ArticleHierName,
			isnull(cast(art.EANNo as varchar(20)) , '''') as EANNo ,
			art.ArticleID,
			art.ArticleNo,
			art.ArticleName,
			isnull(art.SupplierArticleID,'''') as SupplierArticleID ,
			ssl.StockCountNo,
			'

	if @parShowNumberInDPacks = 'Y'
		begin
		  set @sql = @sql + '	case isnull(cast(ssl.countedqty as varchar(10)), ''0'') when ''0'' then '''' else cast(ssl.countedqty/isnull(saleunitsinorderpackage,0) as varchar(10)) end as countedqty'
		end
	else
		begin
		  set @sql = @sql + '	case isnull(cast(ssl.countedqty as varchar(10)), ''0'') when ''0'' then '''' else cast(ssl.countedqty as varchar(10)) end  as countedqty'
		end
	
	set @sql = @sql + ',isnull(SP1.InfoValue,'''') as ShelfPosition1, isnull(SP2.InfoValue,'''') as ShelfPosition2'
	
	set @sql = @sql + '
		into #ds_StockAuction_InventoryList
		FROM STORES sto with (nolock)
		JOIN AllArticles art on 1=1
		'

	if (len(isnull(@parArticleHierNo,'')) > 0  and len(isnull(@parArticleHierNoSubGroups,'')) = 0) or (len(isnull(@parArticleHierNo,'')) >= 0  and len(isnull(@parArticleHierNoSubGroups,'')) > 0)
		set @sql = @sql + 'JOIN ArticleHierNoFilter as artFiltr with (nolock) on art.articlehierno = artFiltr.ArticleHierNo 
		'
	
	if len(isnull(@parSupplierNo,'') ) > 0 
		set @sql = @sql + 'JOIN #supplierNoFltrTbl as supTbl on art.supplierno = supTbl.supplierNo 
		'

	set @sql = @sql + 'JOIN STORESTOCKCOUNTLINES  ssl with (nolock) on sto.StoreNo = ssl.StoreNo  AND art.Articleno = ssl.ArticleNo
		LEFT JOIN StoreArticleInfoDetails AS SP1 with (nolock)   ON  ssl.storeno = SP1.STORENO AND art.ArticleNo = SP1.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
		LEFT JOIN StoreArticleInfoDetails AS SP2 with (nolock)   ON   ssl.storeno = SP2.STORENO AND art.ArticleNo = SP2.ArticleNo AND SP2.infoid = ''RS_ShelfPosition2''         
		'

	if Len(@parStockCountNo ) > 0
		set @sql = @sql + ' WHERE  ssl.StockCountNo = @parStockCountNo '
	else
		set @sql = @sql + ' WHERE  ssl.StockCountNo is null '
	
	if Len(@parStoreNo ) > 0
		set @sql = @sql + ' And ssl.StoreNo = @parStoreNo ' 
	

	if Len(@parArticleName) > 0
		set @sql = @sql + ' AND ART.ARTICLENAME LIKE ''%'' + @parArticleName + ''%'''

   
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
	FROM #ds_StockAuction_InventoryList

	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'


	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_StockAuction_InventoryList a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		'

	if @parOrderBy = 'Ean'
		set @sql = @sql + ' ORDER BY  eanno'
	else if @parOrderBy ='Varenavn'
		set @sql = @sql + ' ORDER BY  ArticleName'
	else if @parOrderBy ='Varegruppe'
		set @sql = @sql + ' ORDER BY  ArticleHierName, ArticleName'                
	else
		set @sql = @sql + ' ORDER BY ArticleName'     

	--print(@sql)

	exec sp_executesql @sql,
					   @ParamDefinition,
					   @parStoreNo = @parStoreNo,
					   @parStockCountNo = @parStockCountNo,
					   @parArticleHierNo = @parArticleHierNo,
					   @parArticleHierNoSubGroups = @parArticleHierNoSubGroups,
					   @parSupplierNo = @parSupplierNo,
					   @parArticleName = @parArticleName,
					   @parOrderBy = @parOrderBy,
					   @parShowNumberInDPacks = @parShowNumberInDPacks
	

END

GO




/*
exec  [dbo].[usp_CBI_1031_ds_StockAuction_InventoryList]	@parStoreNo = '3000'
															,@parStockCountNo  = '935'
															,@parArticleHierNo  = ''
															,@parArticleHierNoSubGroups  = ''
															,@parSupplierNo  = ''
															,@parArticleName  = ''
															,@parOrderBy = ''
															,@parShowNumberInDPacks = 'N'



*/