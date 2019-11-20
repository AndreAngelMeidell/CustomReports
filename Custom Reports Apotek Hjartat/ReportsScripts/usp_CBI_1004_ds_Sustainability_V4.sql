use [VBDCM]

IF EXISTS (SELECT * FROM sysobjects WHERE name = N'usp_CBI_1004_ds_Sustainability_Report'  AND xtype = 'P')
DROP PROCEDURE usp_CBI_1004_ds_Sustainability_Report
GO



CREATE PROCEDURE  [dbo].[usp_CBI_1004_ds_Sustainability_Report](
	@parDatumFrom as varchar(30),
	@parDatumto as varchar(30),
	@ParStoreNo as varchar(30) = ''
)
AS

SET NOCOUNT ON

	declare @sql as nvarchar(max) = ''

	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)
	
	declare @ParamDefinition nvarchar(max)

	set @ParamDefinition = N'@ParStoreNo nvarchar(30), @parDatumFrom nvarchar(30), @parDatumto nvarchar(30)'


	set @sql =  '

	  IF OBJECT_ID(''tempdb..#ds_Sustainability'') IS NOT NULL  DROP TABLE #ds_Sustainability 
	  SELECT
			Sto.StoreName,
			alla.articleno as articleno,
			alla.articleid as ArticleId,
			alla.EanNo,
			alla.articlename as ArticleName, --varu namn
			alla.SupplierArticleID as NordicArticleNo, -- nordisk article number
			ExDate.infovalue as ExpireDates, -- Utgångsdatum
			isnull(zone.Infovalue,'''') as Zone,
			LTRIM(isnull(SP1.Infovalue,'''')) as SP1, -- Hyllplats 1
			LTRIM(isnull(SP2.infovalue,'''')) as SP2, -- Hyllplats 2
         	isnull(Stock.InStockQty,0)  As IsStockAvailable -- Sammanlagt antal pa lager
	  into #ds_Sustainability
	  FROM dbo.AllArticles ALLA 
	  INNER JOIN stores sto on 1=1
	  LEFT JOIN articleinfos as ArticleInfos with (nolock) on alla.articleno = ArticleInfos.articleno  and alla.articlestatus = 1 and ArticleInfos.infoid = ''RS_NordicArticleNo''
	  LEFT JOIN StoreArticleInfoDetails AS ExDate with (nolock) on STo.storeno = ExDate.STORENO AND ALLA.ArticleNo = ExDate.ArticleNo AND ExDate.infoid = ''RS_ExpireDate''
	  LEFT JOIN StoreArticleInfoDetails AS zone with (nolock)  ON  sto.storeno = zone.STORENO AND ALLA.ArticleNo = zone.ArticleNo AND zone.infoid = ''RS_DischargingZone''
	  LEFT JOIN StoreArticleInfoDetails AS SP1 with (nolock)  ON  sto.storeno = SP1.STORENO AND ALLA.ArticleNo = SP1.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
	  LEFT JOIN StoreArticleInfoDetails AS SP2 with (nolock)  ON  sto.storeno = SP2.STORENO AND ALLA.ArticleNo = SP2.ArticleNo AND SP2.infoid = ''RS_ShelfPosition2''
	  LEFT JOIN StoreArticleInfos AS Stock with (nolock) ON  sto.storeno = Stock.STORENO AND ALLA.ArticleNo = Stock.ArticleNo 
	  WHERE ISNULL(CAST(ROUND(Stock.InStockQty, 0) AS INT),0) > 0 '
		

	if(len(@ParStoreNo) > 0)
		set @sql =  @sql + ' and  sto.storeno = @ParStoreNo '

	if len(@parDatumFrom) > 0 
		set @sql = @sql + ' and dbo.fn_report_convertDateRFC(ExDate.INFOVALUE) >= @parDatumFrom '
	
	if len(@parDatumto) > 0
		set @sql = @sql + ' and dbo.fn_report_convertDateRFC(ExDate.INFOVALUE) <= @parDatumto '

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
 --7 - Creating string to filter pivot in proc. (@colsPivotFilt) e. g.: LTRIM(col_name), -||- ...
---------------------------------------------------------------------------------------------------------------------------
	
	select 	@colsCreateTable = dbo.ufn_CBI_getDynamicColsStrings (1)
	select 	@colsToInsertTbl = dbo.ufn_CBI_getDynamicColsStrings (2)
	select 	@colsFinal = dbo.ufn_CBI_getDynamicColsStrings (3)

	-- In proc CBI_vrsp_GetDynamicValues selecting from  #ArticleNos and inserting into #DynamicValues
	set @sql = @sql + '

	IF OBJECT_ID(''tempdb..#ArticleNos'') IS NOT NULL DROP TABLE #ArticleNos
	SELECT distinct ArticleNo
	into #ArticleNos 
	FROM #ds_Sustainability
	'

	-- Creating table dynamically and running proc which uses temp #articlenos table to filter out articles
	set @sql = @sql + '

	IF OBJECT_ID(''tempdb..#DynamicValues'') IS NOT NULL  DROP TABLE #DynamicValues 
	CREATE TABLE #DynamicValues ( articleNo int, articleId varchar(50),
	'+
	@colsCreateTable
	+')	

	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'


	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_Sustainability a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo '

	
	execute sp_executesql	@sql, @ParamDefinition,
								  @parStoreNo = @parStoreNo, 
								  @parDatumFrom = @parDatumFrom, 
								  @parDatumTo = @parDatumTo



GO



/*

exec usp_CBI_1004_ds_Sustainability_Report @parDatumFrom = '2011-01-01',
											 @parDatumTo = '2018-06-01',
											 @ParStoreNo = '3000'




*/


