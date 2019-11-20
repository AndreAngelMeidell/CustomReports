go
use [VBDCM]
go

if exists(select * from sysobjects where name = N'usp_CBI_1009_ds_ItemsMissingExpiryDate' and xtype = 'P')
drop procedure usp_CBI_1009_ds_ItemsMissingExpiryDate  
go

create procedure dbo.usp_CBI_1009_ds_ItemsMissingExpiryDate (	
																@ParStoreNo As varchar(30)  = ''		-- List multiselect
																,@parHuvudGruppNo As varchar(200) = ''	-- List multiselect															
															)
as 
BEGIN
---------------------------------------------------------------------------------------------------------
-- Report 1009
--
-- If there are no selected hierachy groups when selecting all hierarchy groups (@parHuvudGruppNo).
--
--
--
---------------------------------------------------------------------------------------------------------
	set nocount on;

	DECLARE @sql As nvarchar(max) = ''
	DECLARE @colsFinal as varchar(max)
	DECLARE @colsCreateTable as varchar(max)	-- create table dynamiclly
	DECLARE @colsToInsertTbl as varchar(max)

	set @sql = @sql + '

	if LEN(ISNULL(@parHuvudGruppNo,'''')) = 0 
	BEGIN 
		SET @parHuvudGruppNo = ''RX,OTC,HV'' 
	END

	SET @parHuvudGruppNo = REPLACE ( @parHuvudGruppNo , ''RX'', ''100'')
	SET @parHuvudGruppNo = REPLACE ( @parHuvudGruppNo , ''OTC'', ''200'')
	SET @parHuvudGruppNo = REPLACE ( @parHuvudGruppNo , ''HV'', ''900'')
	IF OBJECT_ID(''tempdb..#ds_ItemsMissingExpiryDate'') IS NOT NULL DROP TABLE #ds_ItemsMissingExpiryDate
	'

	set @sql = @sql +  '
			;WITH HuvudGruppNoFltrTbl AS (
			select distinct ParameterValue as HuvudGruppNo 
			from [dbo].[ufn_RBI_SplittParameterString]( @parHuvudGruppNo, '','')
			)
			'

	set @sql = @sql + '
	select 
		  Sto.StoreName,
		  stock.Articleno,
		  alla.articleid as ArtikelID,
		  alla.supplierarticleid as Varunr,
		  alla.articlename as Varunamn,			--varu namn
		  ExDate.infovalue as RS_ExpireDate,		-- Utgångsdatum
		  isnull(SP1.Infovalue,'''') as Shelf_1,
		  isnull(SP2.infovalue,'''') as Shelf_2,
		  Stock.InStockQty As Lager_Antal, -- Sammanlagt antal på lager
		  ArticleHierNameTop as Huvudgrupp
	into #ds_ItemsMissingExpiryDate
	FROM   Stores sto 
	JOIN StoreArticleInfos AS Stock  ON  sto.storeno = Stock.STORENO AND Stock.InStockQty > 0
	LEFT OUTER JOIN StoreArticleInfoDetails AS ExDate on Sto.storeno = ExDate.STORENO AND Stock.ArticleNo = ExDate.ArticleNo AND ExDate.infoid = ''RS_ExpireDate''
	LEFT OUTER JOIN AllArticles ALLA on Stock.ArticleNo = alla.ArticleNo and alla.articlestatus=1
	INNER JOIN HuvudGruppNoFltrTbl HivGrNoFltr on ALLA.ArticleHierIdTop = HivGrNoFltr.HuvudGruppNo
	LEFT OUTER JOIN StoreArticleInfoDetails AS SP1   ON  sto.storeno = SP1.STORENO AND Stock.ArticleNo = SP1.ArticleNo AND SP1.infoid = ''RS_ShelfPosition1''
	LEFT OUTER JOIN StoreArticleInfoDetails AS SP2   ON  sto.storeno = SP2.STORENO AND Stock.ArticleNo = SP2.ArticleNo AND SP2.infoid = ''RS_ShelfPosition2''
	WHERE Sto.StoreNo =  @ParStoreNo 
		  and (exdate.articleno is null or ExDate.infovalue='''')

	'

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
	FROM #ds_ItemsMissingExpiryDate


	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'


	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_ItemsMissingExpiryDate a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo
		order by  Varunamn 
		'

	--print(@sql)
	exec sp_executesql @sql
					   ,N'@parHuvudGruppNo nvarchar(200), @ParStoreNo nvarchar(30)'
					   ,@parHuvudGruppNo = @parHuvudGruppNo
					   ,@ParStoreNo = @ParStoreNo

END


/*
exec usp_CBI_1009_ds_ItemsMissingExpiryDate @ParStoreNo = '3000'		
											  ,@parHuvudGruppNo = ''
*/


