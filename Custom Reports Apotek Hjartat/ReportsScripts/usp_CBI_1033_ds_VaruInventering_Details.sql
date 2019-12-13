GO
USE [VBDCM]
GO

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1033_ds_VaruInventering_Details')
drop procedure [usp_CBI_1033_ds_VaruInventering_Details]
GO

CREATE Procedure [dbo].[usp_CBI_1033_ds_VaruInventering_Details]
		 @parStoreNo As varchar(500) = ''
		,@parStockCountNo As varchar(10) = ''
		,@parShowNumberInDPacks  As varchar(1) = 'N'
		as
BEGIN

--Rapport nr 1033
	set NOCOUNT ON 
	set ANSI_WARNINGS OFF
	set ARITHABORT OFF


	declare @sql As nvarchar(max)
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)
	declare @colsToInsertTbl as varchar(max)

	set @sql = '
	IF OBJECT_ID(''tempdb..#ds_VaruInventering_Details'') IS NOT NULL DROP TABLE #ds_VaruInventering_Details
	SELECT  
		max(sto.Internalstoreid) as Internalstoreid,
		max(sto.StoreName) as StoreName, 
		max(isnull(art.SupplierName,'''')) as SupplierName,
		max(ISNULL(art.ArticleHierID, art.ArticleHierNo)) as ArticleHierNo,
		max(art.ArticleHierName) as ArticleHierName,
		max(ISNULL(art.ArticleHierIDTop,
		art.ArticleHierNoTop)) as ArticleHierNoTop,
		max(art.ArticleHierNameTop) as ArticleHierNameTop,
		max(art.EANNo) As EANNo,
		max(art.ArticleID) As ArticleID,
		max(art.ArticleName) as ArticleName,
		max(art.ArticleNo) as ArticleNo,
		max(isnull(art.SupplierArticleID,'''')) as SupplierArticleID ,
		ssl.StockCountNo,'

	if @parShowNumberInDPacks = 'Y'
		begin
			set @sql = @sql + 'CAST(sum(isnull(ssl.InStockQty,0) * isnull(arli.LinkQty,1)/ isnull(saleunitsinorderpackage,1)) AS INT) AS InStockQtyPreC,
			CAST(sum(isnull(ssl.CountedQty,0) * isnull(arli.LinkQty,1) /isnull(saleunitsinorderpackage,1)) AS INT) AS CountedQtys,
 			CAST(sum((IsNull(ssl.CountedQty,0) * isnull(arli.LinkQty,1) - IsNull(ssl.InStockQty,0) * isnull(arli.LinkQty,1))/isnull(saleunitsinorderpackage,1)) AS INT) AS CountDiff,'
		end
	else
		begin
			set @sql = @sql + ' CAST(sum(isnull(ssl.InStockQty,0) * isnull(arli.LinkQty,1)) AS INT) InStockQtyPreC,
			CAST(sum(isnull(ssl.CountedQty,0) * isnull(arli.LinkQty,1)) AS INT) AS CountedQtys,
 			CAST(sum(IsNull(ssl.CountedQty,0) * isnull(arli.LinkQty,1) - IsNull(ssl.InStockQty,0) * isnull(arli.LinkQty,1)) AS INT) AS CountDiff,'
		end

	set @sql = @sql + '
		CAST(sum(isnull(ssl.CountedDerivedNetCostAmount,CountedNetCostAmount)) AS INT) as NetCostAmountPostC,
		CAST(sum(isnull(ssl.InStockQty,0) * isnull(arli.LinkQty,1)) * isnull(saist.NetPriceDerived,isnull(ssl.NetpriceClosedDate,0)) AS INT) AS NetCostAmountPreC,
		CAST(sum((isnull(CountedDerivedNetCostAmount, CountedNetCostAmount)) - isnull(saist.NetPriceDerived, isnull(ssl.NetpriceClosedDate,0)) 
								* isnull(Instockqty,0) * isnull(arli.LinkQty,1)) AS INT) as NetCostDif,  
		CAST(case sum(isnull(ssl.countedqty,0) *isnull(arli.LinkQty,1))
			when 0 then 0
		else        
			sum(((isnull(ssl.countedqty,0) * isnull(arli.LinkQty,1) - isnull(ssl.instockQty,0)* isnull(arli.LinkQty,1))*100)/
				(isnull(ssl.countedqty,0) * isnull(arli.LinkQty,1))) 
		end AS INT) as Percent_Dif
	into #ds_VaruInventering_Details
	FROM VBDCM..STORESTOCKCOUNTLINES  ssl with (nolock)
	LEFT OUTER JOIN VBDCM..articleLinks arli with (nolock)  on ssl.ArticleNo = arli.MasterArticleNo
	JOIN VBDCM..STORES sto with (nolock) ON sto.StoreNo = ssl.StoreNo 
	JOIN VBDCM..AllArticles art with (nolock) ON art.Articleno = isnull(arli.Articleno,ssl.ArticleNo)
	LEFT JOIN VBDCM..StoreArticleInfoStockTypes saist with (nolock) ON saist.articleno=isnull(arli.Articleno,ssl.ArticleNo) and saist.storeno=ssl.storeno        -- VPT-1880 changed JOIN to LEFT JOIN KB.
	WHERE '
			
	if len(@parStockCountNo) > 0
		set @sql = @sql + ' ssl.StockCountNo = @parStockCountNo '
	else
		set @sql = @sql + ' ssl.StockCountNo is null'

	set @sql = @sql + ' AND StoreStockCountLineStatus = 80 '

	if Len(@parStoreNo ) > 0
		set @sql = @sql + ' And ssl.StoreNo  =  @parStoreNo ' 

	set @sql = @sql + ' GROUP BY ssl.StockCountNo, ssl.StoreNo, isnull(arli.Articleno,ssl.ArticleNo),saist.NetPriceDerived, ssl.NetpriceClosedDate
		HAVING sum(isnull(Instockqty,0)) <> sum(isnull(CountedQty,0))
		ORDER BY max(sto.StoreName), max(art.ArticleName)'

	

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
	FROM #ds_VaruInventering_Details

	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'
	


	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_VaruInventering_Details a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		'


	exec sp_executesql @sql
					   ,N'@parStoreNo nvarchar(500), @parStockCountNo nvarchar(10)'
					   ,@parStoreNo = @parStoreNo
					   ,@parStockCountNo = @parStockCountNo


END

GO


/*

	exec [dbo].[usp_CBI_1033_ds_VaruInventering_Details] @parStoreNo = '3000'	--'3000'
														   ,@parStockCountNo = '936'	--'807'
														   ,@parShowNumberInDPacks  = 'N'



*/