go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1030_ds_StockCount_Differences')
drop procedure usp_CBI_1030_ds_StockCount_Differences
go

CREATE Procedure [dbo].usp_CBI_1030_ds_StockCount_Differences
														(														 
															 @parStoreNo As varchar(500) = ''
															, @parStockCountNo As varchar(10) = ''
															, @parArticleHierNo as varchar(8000) = ''
															, @parArticleHierNoSubGroups as varchar(8000) = ''
															, @parSupplierNo As varchar(8000) = ''
															, @parIncl As varchar(5) = ''
															, @parShowNumberInDPacks  As varchar(1) = 'N'

														)
AS
BEGIN 
--------------------------------------------------------------------------------------------------------------------------
-- Things to have in mind:
-- (isnull(art.ArticleHierID, art.ArticleHierNo) as ArticleHierNo) and we are filtering by ArticleHierNo so there could be
-- some misunderstandings
--
--
--
--------------------------------------------------------------------------------------------------------------------------

	--Rapport nr 1030
	set NOCOUNT ON 
	set ANSI_WARNINGS OFF
	set ARITHABORT OFF

	declare @sql As nvarchar(max) = ''
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)
	
	declare @ParamDefinition as nvarchar(max) = ''
	set @ParamDefinition = N'@parStoreNo nvarchar(500), @parStockCountNo nvarchar(10), @parArticleHierNo nvarchar (max), @parArticleHierNoSubGroups nvarchar(max),
							 @parSupplierNo nvarchar (max), @parIncl nvarchar(5), @parShowNumberInDPacks nvarchar(1)'

------------------------------------------------------------------------------------------------------
	
	set @sql = @sql + 'IF OBJECT_ID(''tempdb..#ds_StockCount_Differences'') IS NOT NULL DROP TABLE #ds_StockCount_Differences
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
	begin
		set @sql = @sql + ';with ArticleHierNoFilter as (
							select distinct cast(ParameterValue as int) as ArticleHierNo
							from [dbo].[ufn_RBI_SplittParameterString](@parArticleHierNoSubGroups,'','')
						  )
						  '
	end


	set @sql = @sql +  '
	SELECT  
 			sto.Internalstoreid,
			sto.StoreName,
			isnull(art.ArticleHierID, art.ArticleHierNo) as ArticleHierNo,
			art.ArticleHierName,
			isnull(art.ArticleHierIDTop, art.ArticleHierNoTop) as ArticleHierNoTop,
			art.ArticleHierNameTop, 
			isnull(art.SupplierName,'''') as SupplierName,
			art.EANNo,
			art.ArticleID,
			art.ArticleNo,
			art.ArticleName,
			sai.ReservedStockQty as reserverat,
			isnull(art.SupplierArticleID,'''') as SupplierArticleID ,
			isnull(SP1.Infovalue,'''') as Shelf_1, 
			isnull(SP2.infovalue,'''') as Shelf_2,
			ssl.StockCountNo,'

	if @parShowNumberInDPacks = 'Y'
		begin
			set @sql = @sql + '
				(IsNull(ssl.CountedQty,0) - IsNull(sai.InStockQty,0))/isnull(saleunitsinorderpackage,0) as CountedDiff,
				isnull(ssl.InStockQty,0)/isnull(saleunitsinorderpackage,0) as TheoreticalInstockqty,
				isnull(ssl.CountedQty,0)/isnull(saleunitsinorderpackage,0) as CountedQty,'
		end
	else
		begin
			set @sql = @sql + '
				IsNull(ssl.CountedQty,0) - IsNull(sai.InStockQty,0) as CountedDiff,
				isnull(ssl.InStockQty,0) as TheoreticalInstockqty,
				isnull(ssl.CountedQty,0) as CountedQty,'
		end

	set @sql = @sql + '
			isnull(ISNULL(ssl.CountedDerivedNetCostAmount,ssl.CountedNetCostAmount),0) as CountedNetCostAmount ,
			isnull(ssl.CountedVatAmount,0) as  CountedVatAmount ,
			isnull(ssl.CountedSalesAmount,0) - isnull(ssl.CountedVatAmount,0) as CountedNetSalesAmount,
			isnull(ssl.CountedSalesAmount,0) as CountedSalesAmount, 
			isnull(sai.instockQty,0) as InStock'


	set @sql = @sql + '
			,isnull(ssl.netPriceClosedDate,0) as NetpriceCount
			,isnull(ssl.SalesPriceClosedDate,0) as SalesPriceCount
			,case isnull(ssl.countedqty,0)
				when 0 then 0
			else        
				((IsNull(ssl.countedqty,0)-IsNull(ssl.instockQty,0))*100)/IsNull(ssl.countedqty,0) 
			end  as Percent_CountDiff
			,IsNull(ssl.instockQty,0) * IsNull(ssl.netPriceClosedDate,0)  as TheoreticalINSTOCKAMOUNT'
	

	set @sql = @sql + '
			, art.NoosArticle
			, art.ArtCategory1 
			, ari2.InfoValue as ArtCategory2'

	set @sql = @sql + '
	into #ds_StockCount_Differences 
	FROM
	STORESTOCKCOUNTLINES  ssl
	JOIN STORES sto on (sto.StoreNo = ssl.StoreNo)
	JOIN AllArticles art on (art.Articleno = ssl.ArticleNo)
	'

	if (len(isnull(@parArticleHierNo,'')) > 0  and len(isnull(@parArticleHierNoSubGroups,'')) = 0) or (len(isnull(@parArticleHierNo,'')) >= 0  and len(isnull(@parArticleHierNoSubGroups,'')) > 0)
		set @sql = @sql + 'JOIN ArticleHierNoFilter as artFiltr with (nolock) on art.articlehierno = artFiltr.ArticleHierNo 
		'

	if len(isnull(@parSupplierNo,'') ) > 0 
		set @sql = @sql + 'JOIN #supplierNoFltrTbl as supTbl on art.supplierno = supTbl.supplierNo 
		'

	set @sql = @sql + 'LEFT JOIN StoreArticleInfoDetails AS SP1   ON  sto.storeno = sp1.storeNo and sp1.ArticleNo = art.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
	LEFT JOIN StoreArticleInfoDetails AS SP2   ON  sto.storeno = sp2.storeNo and sp2.ArticleNo = art.ArticleNo AND SP2.infoid = ''RS_ShelfPosition2''
	LEFT JOIN storearticleinfos sai on (art.articleno = sai.articleno and  sai.storeno = sto.storeno)
	LEFT JOIN articleinfos ari2 on (ari2.articleno = art.articleno and ari2.infoid = ''SE_Kat2'')'


	if Len(isnull(@parStockCountNo, '')) > 0
		set @sql = @sql + 'WHERE ssl.StockCountNo = @parStockCountNo'
	else
		set @sql = @sql + ' WHERE ssl.StockCountNo IS NULL'

	if @parIncl <>  'Y'
		set @sql = @sql + ' And isnull(ssl.storestockcountlinetype, 0) NOT IN (41,42)' 

	if Len(@parStoreNo ) > 0
		set @sql = @sql + ' And ssl.StoreNo = @parStoreNo and (IsNull(ssl.CountedQty,0) - IsNull(sai.InStockQty,0)) <> ''0''' 

	  
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
	FROM #ds_StockCount_Differences

	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'

	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_StockCount_Differences a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		'

	set @sql = @sql + ' ORDER BY StoreName, ArticleName'   



	--print(@sql)
	exec sp_executesql @sql,
					   @ParamDefinition,
					   @parStoreNo = @parStoreNo,
					   @parStockCountNo = @parStockCountNo,
					   @parArticleHierNo = @parArticleHierNo,
					   @parArticleHierNoSubGroups = @parArticleHierNoSubGroups,
					   @parSupplierNo = @parSupplierNo,
					   @parIncl = @parIncl,
					   @parShowNumberInDPacks = @parShowNumberInDPacks



END
GO





/*

exec [dbo].usp_CBI_1030_ds_StockCount_Differences	@parStoreNo  = '3000'
													,@parStockCountNo  = '935'
													,@parArticleHierNo  = '1,19' --'310,410'
													,@parArticleHierNoSubGroups = '' --'8,145,146,147,148,151,152,153,154,155,156,157,158,159,160,161' --'1,19'
													,@parSupplierNo  = '2,27'
													,@parIncl = ''
													,@parShowNumberInDPacks = 'N'


*/
