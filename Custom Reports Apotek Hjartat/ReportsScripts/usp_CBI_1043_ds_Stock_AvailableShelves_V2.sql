go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1043_ds_Stock_AvailableShelves')
drop procedure usp_CBI_1043_ds_Stock_AvailableShelves
go

CREATE Procedure dbo.usp_CBI_1043_ds_Stock_AvailableShelves
														(
															@parStoreNo As varchar(30) =''
														)
AS
BEGIN 
--Rapport nr 1043
	SET NOCOUNT ON;

	DECLARE @sql AS NVARCHAR(MAX)
	DECLARE @colsFinal AS VARCHAR(MAX)
	DECLARE @colsCreateTable AS VARCHAR(MAX)	-- create table dynamiclly
	DECLARE @colsToInsertTbl AS VARCHAR(MAX)
	
	SET @sql = ''

	SET @sql = @sql + '
	IF OBJECT_ID(''tempdb..#ds_Stock_AvailableShelves'') IS NOT NULL  DROP TABLE #ds_Stock_AvailableShelves
	SELECT 
		alla.articleno as ArticleNo,
		alla.articleid as ArticleId,
		alla.articlename as ArticleName, 
		ISNULL(arti.Infovalue,'''') AS NordicArticleNo,
		alla.Suppliername,
		CONVERT(CHAR(10),ExDate.infovalue,120) AS ExpireDates, 
		--ExDate.infovalue AS ExpireDates, 
		ISNULL(SP1.Infovalue,'''') AS Hyllplats1, 
		ISNULL(SP2.infovalue,'''') AS Hyllplats2,
		ISNULL(SartInfo.MinimumStockQty,'''') AS MinStock,
		ISNULL(SartInfo.MaximumStockQty,'''') AS MaxStock,
		ISNULL(Stock.Infovalue,0) AS IsStockAvailable
	INTO #ds_Stock_AvailableShelves
	FROM dbo.AllArticles ALLA 
	INNER JOIN stores STO ON 1=1
	LEFT JOIN articleinfos AS arti WITH (NOLOCK) ON alla.articleno = arti.articleno AND alla.articlestatus = 1 AND arti.infoid = ''RS_NordicArticleNo''
	LEFT JOIN StoreArticleInfoDetails AS ExDate WITH (NOLOCK) ON STo.storeno = ExDate.STORENO AND ALLA.ArticleNo = ExDate.ArticleNo AND ExDate.infoid = ''RS_ExpireDate''
	LEFT JOIN StoreArticleInfoDetails AS SP1 WITH (NOLOCK) ON sto.storeno = SP1.STORENO AND ALLA.ArticleNo = SP1.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
	LEFT JOIN StoreArticleInfoDetails AS SP2  WITH (NOLOCK) ON sto.storeno = SP2.STORENO AND ALLA.ArticleNo = SP2.ArticleNo AND SP2.infoid = ''RS_ShelfPosition2''
	LEFT JOIN StoreArticleInfoDetails AS Stock WITH (NOLOCK) ON sto.storeno = Stock.STORENO AND ALLA.ArticleNo = Stock.ArticleNo AND Stock.infoid = ''RS_IsStockAvailable''
	LEFT JOIN StoreArticleInfos AS SartInfo WITH (NOLOCK) ON alla.articleno = SartInfo.articleno AND SartInfo.storeno = sto.storeno'

	set @sql = @sql + ' 
	WHERE sto.storeno =  @parStoreNo '

	SET @sql = @sql + ' AND SartInfo.MaximumStockQty = 0 AND SartInfo.MinimumStockQty  = 0  AND sartinfo.instockqty<1 AND SP1.infovalue <> '''''

	

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
	FROM #ds_Stock_AvailableShelves

	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'

	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_Stock_AvailableShelves a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		'

	--print(@sql)

	execute sp_executesql @sql,  
						  N'@ParStoreNo nvarchar(30)',
						  @parStoreNo = @parStoreNo

END


/*
	exec [dbo].usp_CBI_1043_ds_Stock_AvailableShelves @parStoreNo = '3000'
*/
