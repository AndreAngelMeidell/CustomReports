go
use [VBDCM]
go


if exists(select * from sysobjects WHERE name = N'usp_CBI_1205_ds_VarouvationDifferenceDetail'  AND xtype = 'P' )
drop procedure usp_CBI_1205_ds_VarouvationDifferenceDetail
GO

create procedure [dbo].[usp_CBI_1205_ds_VarouvationDifferenceDetail] (
		@parStoreNo As nvarchar(500),
		@parStockCountNo As varchar(10)
)
as

 -- VBDCM
 --Rapport nr 1205
	SET NOCOUNT ON 
	SET ANSI_WARNINGS OFF
	SET ARITHABORT OFF

	declare @sql as nvarchar(max)
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)

	SET @sql = '
	IF OBJECT_ID(''tempdb..#ds_VarouvationDifferenceDetail'') IS NOT NULL  DROP TABLE #ds_VarouvationDifferenceDetail
	SELECT  
		ISNULL(art.SupplierName,'''') AS SupplierName,
		ISNULL(art.ArticleHierID, art.ArticleHierNo) AS ArticleHierNo,
		art.ArticleHierName AS ArticleHierName,
		ISNULL(art.ArticleHierIDTop,art.ArticleHierNoTop) AS ArticleHierNoTop,
		art.ArticleHierNameTop AS ArticleHierNameTop,
		art.EANNo AS EANNo,
		art.ArticleID AS ArticleID,
		art.ArticleNo AS ArticleNo,
		art.ArticleName AS ArticleName,
		ISNULL(art.SupplierArticleID,'''') as SupplierArticleID,
		ssl.StockCountNo,
		SUM(ISNULL(ssl.InStockQty,0) * ISNULL(arli.LinkQty,1)) InStockQtyPreC,
		SUM(ISNULL(ssl.CountedQty,0) * ISNULL(arli.LinkQty,1)) CountedQtys,
 		SUM(ISNULL(ssl.CountedQty,0) * ISNULL(arli.LinkQty,1) - ISNULL(ssl.InStockQty,0) * ISNULL(arli.LinkQty,1)) as CountDiff,
		SUM(ISNULL(ssl.CountedDerivedNetCostAmount,CountedNetCostAmount)) as NetCostAmountPostC,
		SUM(ISNULL(ssl.InStockQty,0) * ISNULL(arli.LinkQty,1)) * ISNULL(saist.NetPriceDerived,ISNULL(ssl.NetpriceClosedDate,0))  as NetCostAmountPreC,
		SUM((ISNULL(CountedDerivedNetCostAmount, CountedNetCostAmount)) - ISNULL(saist.NetPriceDerived,ISNULL(ssl.NetpriceClosedDate,0)) 
							 * ISNULL(Instockqty,0) * ISNULL(arli.LinkQty,1)) as NetCostDif,  
		case SUM(ISNULL(ssl.countedqty,0) *ISNULL(arli.LinkQty,1))
		   when 0 then 0
		else        
		   SUM(((ISNULL(ssl.countedqty,0) * ISNULL(arli.LinkQty,1) -ISNULL(ssl.instockQty,0)* ISNULL(arli.LinkQty,1))*100)/
				(ISNULL(ssl.countedqty,0) * ISNULL(arli.LinkQty,1))) 
		end  as Percent_Dif,
	    sto.StoreNo
	INTO #ds_VarouvationDifferenceDetail
	FROM StoreStockCountLines ssl
	LEFT OUTER JOIN articleLinks arli ON ssl.ArticleNo = arli.MasterArticleNo
	INNER JOIN STORES sto ON sto.StoreNo = ssl.StoreNo 
	INNER JOIN AllArticles art ON art.Articleno = isnull(arli.Articleno,ssl.ArticleNo)
	LEFT JOIN StoreArticleInfoStockTypes saist ON saist.ArticleNo=isnull(arli.ArticleNo,ssl.ArticleNo) AND saist.StoreNo=ssl.StoreNo          
	WHERE '
	
	IF LEN(@parStockCountNo) > 0
		SET @sql = @sql + ' ssl.StockCountNo =  @parStockCountNo '
	ELSE
		SET @sql = @sql + ' ssl.StockCountNo is null '


	SET @sql = @sql + '
	AND StoreStockCountLineStatus = 80  
	AND ssl.StoreNo = @parStoreNo 
	GROUP BY art.SupplierName, art.ArticleHierID, art.ArticleHierNo, art.ArticleHierName, art.ArticleHierIDTop, art.ArticleHierNoTop,
			art.ArticleHierNameTop, art.EANNo, art.ArticleID, art.ArticleName, art.SupplierArticleID, sto.StoreName,
			 ssl.StockCountNo, ssl.StoreNo, ISNULL(arli.Articleno,ssl.ArticleNo),saist.NetPriceDerived, ssl.NetpriceClosedDate, sto.StoreNo, art.ArticleNo
	HAVING SUM(ISNULL(Instockqty,0)) <> SUM(ISNULL(CountedQty,0))
	ORDER BY sto.StoreName, art.ArticleName'


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
	FROM #ds_VarouvationDifferenceDetail


	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'


	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_VarouvationDifferenceDetail a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		'


	exec sp_executesql @sql
					   ,N'@parStoreNo as nvarchar(100), @parStockCountNo as nvarchar(10) '
					   ,@parStoreNo = @parStoreNo
					   ,@parStockCountNo = @parStockCountNo


go


/*

exec [dbo].[usp_CBI_1205_ds_VarouvationDifferenceDetail] '3000','961'

*/