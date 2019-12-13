go
use [VBDCM]
go

if exists(select * from sysobjects where name = N'usp_CBI_1024_ds_LoginReport' and xtype = 'P')
drop procedure usp_CBI_1024_ds_LoginReport
go

create procedure usp_CBI_1024_ds_LoginReport (@StoreGroupNos as varchar(8000) = '',
												@parDateFrom as varchar(30) = '',
												@parDateTo As varchar(30) = '',
												@parInkPrisMin as varchar(100) = '',
												@parInkPrisMax as varchar(100) = '')
as

	--Rapport nr 1024
	SET NOCOUNT ON;

	--set dateformat ymd

	declare @sql As nvarchar(max) = ''
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)


	declare @ParamDefinition nvarchar(max)
	set @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parDateFrom nvarchar(30), @parDateTo nvarchar(30), @parInkPrisMin nvarchar(100), @parInkPrisMax nvarchar(100)'

------------------------------------------------------------------------------------------------------

	
	set @sql = @sql +  '
	IF OBJECT_ID(''tempdb..#ds_LoginReport'') IS NOT NULL  DROP TABLE #ds_LoginReport 

	set @parDateFrom = CONVERT(date, @parDateFrom, 121)
	set @parDateTo = CONVERT(date, @parDateTo, 121)


	'

	if len(@StoreGroupNos) > 0 
		Begin
			
			set @sql = @sql +  '
			;WITH DimStores AS (
			select StoreNo
			from dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos)
			)
			'
		End
	else
		Begin
			set @sql = @sql +  '
			;WITH DimStores AS (
			select null as StoreNo
			)
			'
		End
		
	set @sql = @sql +  '
	SELECT 
		stor.InternalStoreID as ButiksNr,
		stor.storename as Butiksnamn,
		alar.ArticleID,
		alar.ArticleNo,
		isnull(alar.supplierarticleid,'''') as Varunr, 
		alar.articlename as Namn, 
		col.OrderedQty as Antal,
		artp.NetCostPrice,
	(SELECT InfoValue from ArticleInfos AS AI with (nolock) where  COL.ArticleNo = AI.ArticleNo and  AI.InfoID = ''RS_ATCCode'' )AS ATC_Kod,
	(SELECT InfoValue from ArticleInfos AS AIN with (nolock) where  COL.ArticleNo = AIN.ArticleNo and  AIN.InfoID = ''RS_ISPreferredReplacementArticle'' )AS Periodens_Vara,
		--CONVERT(varchar,colpo.RecordCreated,23) as Datum,
		colpo.RecordCreated as Datum,
		SUM(col.OrderedQty) AS TotaltAntal
	into #ds_LoginReport
	FROM CustomerOrderLinePurchaseOrders colpo with (nolock)
	join Stores stor with (nolock) on (colpo.storeno = stor.storeno)
	join DimStores dimStor on dimStor.StoreNo = stor.StoreNo
	left outer join CustomerOrderLines col with (nolock)  on (colpo.CustomerOrderNo=col.CustomerOrderNo) 
	left outer join Allarticles alar with (nolock) on (col.articleno = alar.articleno)
	left outer JOIN activeallarticleprices artp with (nolock) on (colpo.storeno = artp.storeno and col.articleno = artp.articleno) 
	WHERE artp.NetCostPrice>0 and 
	 CONVERT(date,colpo.RecordCreated,120) between @parDateFrom and @parDateTo '

	if len(@parInkPrisMin) > ''
		set @sql = @sql + ' AND  artp.NetCostPrice >= @parInkPrisMin'

	if len(@parInkPrisMax) >''
		set @sql = @sql + ' AND artp.NetCostPrice<=  @parInkPrisMax'

	set @sql = @sql + '
	Group BY colpo.storeno,alar.articleid, alar.ArticleNo, colpo.RecordCreated,alar.articlename,
	col.OrderedQty,alar.supplierarticleid,artp.NetCostPrice,COL.ArticleNo, stor.InternalStoreID, stor.storename
	'

	set @sql = @sql + '
	IF OBJECT_ID(''tempdb..#ds_LoginReportWithTotals'') IS NOT NULL DROP TABLE #ds_LoginReportWithTotals
	select 1 as id,
			ButiksNr,
			Butiksnamn, 
			ArticleID,
			ArticleNo,
			Varunr as VarunrOrd,
			Varunr,
			Namn, 
			Antal, 
			NetCostPrice, 
			ATC_Kod, 
			Periodens_Vara, 
			Datum, 
			TotaltAntal
	into #ds_LoginReportWithTotals
	from #ds_LoginReport
	union all
	select	2 as id
			,null as ButiksNr
			,null as Butiksnamn
			,null as ArticleID
			,ArticleNo
			,Varunr as VarunrOrd
			, ''Sum Varunr '' + Varunr as Varunr
			,null as Namn
			,sum(Antal) as Antal
			,null as NetCostPrice
			,null as ATC_Kod
			,null as Periodens_Vara
			,null as Datum
			,null as TotaltAntal
	from #ds_LoginReport
	group by Varunr, ArticleNo
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
	FROM #ds_LoginReportWithTotals

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
		from #ds_LoginReportWithTotals a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		order by VarunrOrd, id 
		'

	--print(right(@sql,2000))

	exec sp_executesql  @sql,
						@ParamDefinition,
						@StoreGroupNos = @StoreGroupNos,
						@parDateFrom = @parDateFrom,
						@parDateTo = @parDateTo,
						@parInkPrisMin = @parInkPrisMin,
						@parInkPrisMax = @parInkPrisMax

go


/*
exec usp_CBI_1024_ds_LoginReport	@StoreGroupNos = N'3000,3010,1725',
									@parDateFrom = '2018-01-01',
									@parDateTo =  '2018-06-01',
									@parInkPrisMin = null,
									@parInkPrisMax = null

*/




