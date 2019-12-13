go
use [VBDCM]
go


if exists(select * from sysobjects WHERE name = N'vw_PharmaHuvudgrp'  AND xtype = 'V')
drop view vw_PharmaHuvudgrp
go


CREATE VIEW [dbo].[vw_PharmaHuvudgrp]
AS
SELECT [ArticleNo]
      ,[ArticleName]
      ,[ArticleID]
      ,[ArticleReceiptText]
       ,[ArticleStatus]
      ,[ArticleTypeNo]
      ,[PrimaryEAN]
      ,[ArticleHierID]
      ,[ArticleHierName]
      ,[ArticleHierNoTop]
      ,[ArticleHierNo]
      ,[ArticleHierIDTop]
      ,[ArticleHierNameTop]
      ,[PrimarySupplierNo]
      ,[SupplierNo]
      ,[SupplierName]
      ,[SupplierArticleID]
      ,[EanNo]

,Huvudgrp =
      CASE 
         WHEN [ArticleHierIDTop]= '100' THEN 'Läkemdel RX'
         WHEN [ArticleHierIDTop]= '200' THEN 'Läkemdel OTC'
         WHEN [ArticleHierIDTop]= '300' THEN 'Livsmedel RX'
         WHEN [ArticleHierIDTop]= '400' THEN 'Hjälpmedel medicinskt'
         WHEN [ArticleHierIDTop]= '500' THEN 'Tjänster'
		 WHEN [ArticleHierIDTop]= '900' THEN 'Handelsvaror'
         ELSE 'Okänd'
      END
  
  FROM [VBDCM].[dbo].[AllArticles]
  WHERE [ArticleStatus]=1
      
GO


------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Store proc
------------------------------------------------------------------------------------------------------------------------------------------------------------

IF EXISTS(SELECT * FROM sysobjects WHERE NAME = N'usp_CBI_1099_ds_OmlopshastighetHjartatStore' AND xtype = 'P')
DROP PROCEDURE usp_CBI_1099_ds_OmlopshastighetHjartatStore
GO

CREATE PROCEDURE [dbo].[usp_CBI_1099_ds_OmlopshastighetHjartatStore] @parFromDate AS VARCHAR(40),
	@parToDate AS VARCHAR(40),
	@StoreGroupNos AS VARCHAR(8000),
	@parInclDeleted AS VARCHAR(10),
	@parInclNewArticles AS VARCHAR(10),
	@parSupplierArticleID AS VARCHAR(2000),
	@parArticleName AS VARCHAR(8000),
	@parSumAllStores AS VARCHAR(8000),
	@parGroupBy AS VARCHAR(8000)

AS

BEGIN

IF @parGroupBy = 1
	BEGIN

	DECLARE @iErrorcode AS INTEGER
	DECLARE @sErrorMessage AS VARCHAR(1000)
	DECLARE @ProcedureName  VARCHAR(100)
	DECLARE @finalSql NVARCHAR(MAX)
	DECLARE @sql AS NVARCHAR(MAX) = ''
	DECLARE @TmpSoldQtysSql AS NVARCHAR(MAX) = ''
	DECLARE @DimStoresSql AS NVARCHAR(MAX) = ''
	DECLARE @MaxDate AS DATETIME
	DECLARE @MinDate AS DATETIME
	DECLARE @FromDate AS DATETIME
	DECLARE @ToDate AS DATETIME
	DECLARE @ParamDefinition NVARCHAR(MAX)

	SET @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parFromDate nvarchar(30), @parToDate nvarchar(30), @parInclDeleted nvarchar(10), @parInclNewArticles nvarchar(10),
	@parSupplierArticleID nvarchar(2000), @parArticleName nvarchar(max), @parSumAllStores nvarchar(max), @parGroupBy nvarchar(max)
	'
	
	SET NOCOUNT ON 
	SET @ProcedureName = 'vbdsp_OmlopshastighetHjartat'
	EXEC vbdcm.dbo.vbdspSYS_Insert_VBDtrace '1', 'Oppstart prosedyre ','',  @ProcedureName, 'Stored Procedure'

	SET ANSI_WARNINGS OFF
	SET NOCOUNT ON


---------------------------------------------------------------------------------------
-- To Calculate date
---------------------------------------------------------------------------------------
	SET @MaxDate = (SELECT MAX(LogDate) FROM StoreArticleInfoLogs
					WHERE LogDate <= @parFromDate)
	
	SET @MinDate =( SELECT MIN(LogDate) FROM StoreArticleInfoLogs
					WHERE LogDate >=  @parFromDate)
	

	IF ABS(DATEDIFF(d,@parFromDate,@MaxDate)) < ABS(DATEDIFF(d,@parFromDate,@MinDate))
		SET @FromDate = @MaxDate
	ELSE
		SET @FromDate = @MinDate
	
	IF LEN(@parToDate) > 0
	BEGIN
		SET @MaxDate = (SELECT MAX(LogDate) FROM StoreArticleInfoLogs
						WHERE LogDate <= @parToDate)
		
		SET @MinDate = (SELECT MIN(LogDate) FROM StoreArticleInfoLogs
						WHERE LogDate >=  @parToDate)

		IF @MinDate IS NULL 
			BEGIN
			  SET @ToDate = GETDATE()
			  SET @parToDate = ''
			END
		ELSE
			BEGIN		
				IF ABS(DATEDIFF(d,@parToDate,@MaxDate)) < ABS(DATEDIFF(d,@parToDate,@MinDate))
	  			SET @ToDate = @MaxDate
				ELSE
	  			SET @ToDate = @MinDate
			END
		END
	ELSE
		BEGIN
			SET @ToDate = getdate() 
		END
	
	IF OBJECT_ID('vbdtmp..tmpInStockDates') IS NOT NULL DROP TABLE vbdtmp..tmpInStockDates
	
	SELECT @FromDate AS FromDate, @ToDate AS ToDate, CAST(DATEDIFF(d, @FromDate, @ToDate ) AS FLOAT) AS NumberOfDays
	INTO vbdtmp..tmpInStockDates	
	
	SET @sql = 'CREATE UNIQUE INDEX tmpInStockDates_indx ON vbdtmp..tmpInStockDates(FromDate)'
	
	EXEC (@sql)
		
---------------------------------------------------------------------------------------
-- Creating temp store filter table
---------------------------------------------------------------------------------------
	
	SET @DimStoresSql = '
	IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL  DROP TABLE #DimStores '

	IF LEN(@StoreGroupNos) > 0 
		BEGIN
			
			SET @DimStoresSql = @DimStoresSql + '
			SELECT StoreNo
			INTO #DimStores
			FROM dbo.ufn_CBI_getStoreNoForStoreGroups ( @StoreGroupNos )
			'
		END
	ELSE
		BEGIN
			SET @DimStoresSql = @DimStoresSql + '
			select null as StoreNo
			into #DimStores
			'
		END


---------------------------------------------------------------------------------------
-- To separetly calculate tmpSoldQtys from stockadjustments 
---------------------------------------------------------------------------------------
	
	IF OBJECT_ID('vbdtmp..tmpSoldQtys') IS NOT NULL drop table vbdtmp..tmpSoldQtys
	
	SET @TmpSoldQtysSql = @TmpSoldQtysSql + '
		SELECT stad.StoreNo, stad.ArticleNo, sum(stad.AdjustmentQty) AS SoldQty
		INTO vbdtmp..tmpSoldQtys
		FROM Stockadjustments stad
	  JOIN vbdtmp..tmpInStockDates issd  ON (1 = 1)
	  JOIN #DimStores dimStr ON dimStr.StoreNo = stad.StoreNo
	  '

	IF LEN(@parArticleName) > 0
		SET @TmpSoldQtysSql = @TmpSoldQtysSql + '
		JOIN vw_PharmaHuvudgrp  alar on stad.ArticleNo = alar.ArticleNo
		'
		
	SET @TmpSoldQtysSql = @TmpSoldQtysSql + '	WHERE StockAdjType = 1
			AND stad.AdjustmentDate > issd.FromDate and stad.AdjustmentDate < issd.ToDate'


	IF LEN(@parSupplierArticleID) > 0 
		SET @TmpSoldQtysSql = @TmpSoldQtysSql + ' AND stad.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')'
	  
	IF LEN(@parArticleName) > 0 
		SET @TmpSoldQtysSql = @TmpSoldQtysSql + ' AND alar.ArticleName LIKE ''%'' + @parArticleName + ''%'''
	  

	SET @TmpSoldQtysSql = @TmpSoldQtysSql + '	
		GROUP BY stad.storeno, stad.articleno'

	
	SET @TmpSoldQtysSql = @TmpSoldQtysSql + ' 
	UNION ALL
    SELECT stad.StoreNo, stad.ArticleNo, SUM(adjustmentqty * -1) AS SoldQty
	FROM stockadjustments stad
	JOIN vbdtmp..tmpInStockDates issd  ON (1= 1)
    JOIN Stores stor ON (stad.StoreNo = stor.StoreNo)
	JOIN #DimStores dimStr ON dimStr.StoreNo = stor.StoreNo
	'

	IF LEN(@parArticleName) > 0
		SET @TmpSoldQtysSql = @TmpSoldQtysSql + 'JOIN vw_PharmaHuvudgrp  alar ON stad.ArticleNo = alar.ArticleNo
		'
	
	SET @TmpSoldQtysSql = @TmpSoldQtysSql + '	WHERE Stockadjtype = 1
                        AND stor.StoreTypeNo = 8
						AND stad.AdjustmentDate > issd.FromDate AND stad.AdjustmentDate < issd.ToDate'


	IF LEN(@parSupplierArticleID) > 0 
		SET @TmpSoldQtysSql = @TmpSoldQtysSql + ' AND stad.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')'

	IF LEN(@parArticleName) > 0 
		SET @TmpSoldQtysSql = @TmpSoldQtysSql + ' AND alar.ArticleName LIKE ''%'' + @parArticleName + ''%'''
	
	SET @TmpSoldQtysSql = @TmpSoldQtysSql + ' GROUP BY stad.storeno, stad.articleno
	'
	
	SET @sql = 'CREATE UNIQUE INDEX tmpSoldQtys_indx ON  vbdtmp..tmpSoldQtys(StoreNo, ArticleNo)'
	
	SET @sql = 'select '
	
	IF @parSumAllStores = 'Y'
		SET @sql = @sql + '0 as InternalStoreID , ''Alle'' AS StoreName,'
	ELSE 
		SET @sql = @sql + 'stor.InternalStoreID, stor.StoreNo, stor.StoreName,'
	

	SET @sql = @sql +' CONVERT(VARCHAR, max(sail.Logdate), 23)  as DateFrom,
	'
	    
	IF LEN (@parToDate) > 0
		SET @sql = @sql +' CONVERT(VARCHAR, MAX(sain.Logdate), 23) AS DateTo,
		'
	ELSE
		set @sql = @sql +' CONVERT(VARCHAR, getdate(), 23) as DateTo,
		 '

	set @sql = @sql +'MAX(issd.NumberOfDays) AS NumberOfDays,
        alar.Huvudgrp AS gruppering,
	    SUM(ISNULL(sail.instockqty,0)) AS QtyStart,
	    CAST( ISNULL(sum(isnull(sail.InstockQty * sast.NetPriceDerived, sail.instockAmount)),0) AS DECIMAL(38,2)) as ValueStart,
	    SUM(ISNULL(sain.instockqty,0)) AS QtyEnd,
	    CAST( SUM(ISNULL(sain.instockqty,0) * ISNULL(sast.NetPriceDerived, ISNULL(aaap.Netprice,0))) AS DECIMAL(38,2)) AS ValueEnd,   
	    SUM(ISNULL(sqty.SoldQty,0)) * -1 AS SoldQty1,
	    CASE 
			WHEN SUM(ISNULL(sail.instockqty,0)) + SUM(ISNULL(sain.instockqty,0))  < 0.1  OR ISNULL(max(issd.NumberOfDays), 0) = 0 
		THEN 0 
	    ELSE  ( 365/MAX(issd.NumberOfDays)) * (SUM(ISNULL(sqty.SoldQty,0))) * -1 / (( ISNULL(SUM(ISNULL(sail.instockqty,0)),0) + ISNULL(SUM(ISNULL(sain.instockqty,0)),0))/ 2) 
	    END AS omlopshastighet,

		CASE 
	        WHEN SUM(ISNULL(sail.instockqty,0)) + SUM(ISNULL(sain.instockqty,0))  < 0.1 OR ISNULL(MAX(ISSD.NumberOfDays), 0) = 0 OR (SUM(ISNULL(sqty.SoldQty,0))) = 0  THEN 
				0 
	        ELSE 365/((365/MAX(issd.NumberOfDays)) * (SUM(ISNULL(sqty.SoldQty,0))) * -1 /
				 (( ISNULL(SUM(ISNULL(sail.instockqty,0)),0) + ISNULL(SUM(ISNULL(sain.instockqty,0)),0))/ 2) )
	     END AS dagilager,
	     CASE 
			WHEN SUM(ISNULL(sqty.SoldQty,0)) = 0 OR MAX(issd.NumberOfDays) = 0 THEN 
				0
			ELSE 
				SUM(ISNULL(sain.instockqty,0))	/ (SUM(ISNULL(sqty.SoldQty,0)) * -1  / MAX(issd.NumberOfDays))
		 END AS DaysInStock1,
		 MAX(2) AS GroupBy
	  FROM '
	
		if len(@parToDate) > 0
			set @sql = @sql +'storearticleinfologs sain'
		else
			set @sql = @sql +'storearticleinfos sain '

	set @sql = @sql +' 
	  JOIN vbdtmp..tmpInStockDates issd ON (1 = 1)
	  JOIN vw_PharmaHuvudgrp alar ON (sain.articleno = alar.articleno)
	  JOIN Stores stor ON (sain.StoreNo = stor.StoreNo)
	  JOIN #DimStores dimStr ON dimStr.StoreNo = stor.StoreNo
	  '

	set @sql = @sql +'--JOIN Assortment asor ON (sain.StoreNo = asor.StoreNo AND sain.articleno = asor.articleno)
	  JOIN ActiveAllArticlePrices aaap ON (sain.StoreNo = aaap.StoreNo AND sain.Articleno = aaap.ArticleNo)
	  LEFT OUTER JOIN storearticleinfologs sail ON (sail.StoreNo = sain.StoreNo AND sail.ArticleNo = sain.ArticleNo AND sail.Logdate = issd.FromDate)  
	  LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sasl ON (sasl.StoreNo = sail.StoreNo 
			AND sasl.ArticleNo = sail.ArticleNo 
			AND sasl.LogDate = sail.LogDate
			AND sasl.StockTypeNo = 1)'
						  
	if len(@parToDate) > 0
		set @sql = @sql +'
		LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sast ON (sast.StoreNo = sain.StoreNo 
			AND sast.ArticleNo = sain.ArticleNo 
			AND sast.LogDate = sain.LogDate
			AND sast.StockTypeNo = 1)' 	  
	else
		set @sql = @sql +' 
		LEFT OUTER JOIN storearticleinfoStockTypes sast ON (sast.StoreNo = sain.StoreNo AND sast.ArticleNo = sain.ArticleNo AND sast.StockTypeNo = 1)'  	
	  
	set @sql = @sql +'
	LEFT OUTER JOIN vbdtmp..tmpSoldQtys sqty ON (sain.StoreNo = sqty.StoreNo AND sain.ArticleNo = sqty.ArticleNo)
	WHERE 1 = 1
	'

	IF @parInclNewArticles != 'Y' 
		SET @sql = @sql + ' AND sail.logdate IS NOT NULL '
		
	IF LEN (@parToDate) > 0
		SET @sql = @sql +' AND sain.LogDate = issd.ToDate'

	IF LEN(@parSupplierArticleID) > 0 
		set @sql = @sql + ' AND alar.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')'

	IF LEN(@parArticleName) > 0 
		SET @sql =@sql + ' AND alar.ArticleName LIKE ''%'' + @parArticleName + ''%'''


	IF LEN(ISNULL(@StoreGroupNos,'')) = 0
		SET @sql = @sql + '  AND stor.storetypeno = 7 AND stor.storestatus < 9  '

	IF @parInclDeleted != 'Y' 
		SET @sql = @sql + ' AND alar.articlestatus < 8  '
	
	IF @parSumAllStores = 'Y' AND @parGroupBy = 1
		SET @sql = @sql + ' GROUP BY alar.Huvudgrp'
	ELSE
		SET @sql = @sql +' GROUP BY stor.StoreNo, stor.InternalStoreID, stor.StoreName, '

	IF @parGroupBy = '1' AND @parSumAllStores <> 'Y'
		SET @sql = @sql + ' stor.StoreNo, alar.Huvudgrp'

	SET @sql = @sql + ' ORDER BY 1,2,3,4'

	--print( @DimStoresSql)
	--print( @TmpSoldQtysSql)
	--print( @sql)	

	SET @finalSql = @DimStoresSql + @TmpSoldQtysSql + @sql

	EXEC sp_executesql  @finalSql,
						@ParamDefinition,
						@StoreGroupNos = @StoreGroupNos,
						@parFromDate = @parFromDate,
						@parToDate = @parToDate,
						@parInclDeleted = @parInclDeleted,
						@parInclNewArticles = @parInclNewArticles,
						@parSupplierArticleID = @parSupplierArticleID,
						@parArticleName = @parArticleName,
						@parSumAllStores = @parSumAllStores,
						@parGroupBy = @parGroupBy


ERRORHANDLER:

  IF (@iErrorCode <> 0)
	  BEGIN
		SET @sErrorMessage = (SELECT description FROM master..sysmessages WHERE error = @iErrorCode)
		EXEC vbdcm.dbo.vbdspSYS_insert_vbderror @iErrorCode, @sErrorMessage, 
					@ProcedureName, 'Stored Procedure', '', ''
	  END
  ELSE
	  BEGIN
		EXEC vbdcm.dbo.vbdspSYS_Insert_VBDtrace '1', 'Ferdig prosedyre', '',  @ProcedureName, 'Stored Procedure'
	  END

END

END -- if @parGroupBy = 1 end

GO


/*
exec usp_CBI_1099_ds_OmlopshastighetHjartatStore	@parFromDate = '2008-01-01',
													@parToDate = '2018-05-23',
													@StoreGroupNos  = '3000,3010', --'0,375,3009,1007,2000,2999,3002,9232,9908,9237,9190,9929,9227,9913,9223,9270,9798,9765,1047,9808,9275,1265,1286,9242,9226,9915,9942,1107,9269,9266,9259,9802,9008,9189,1136,9557,9566,1152,9868,9893,9896,9900,9546,9119,1332,9553,9562,9003,9580,9101,9527,9549,9548,9520,9559,9542,9118,9149,9157,9168,9138,9161,9139,9829,9838,9085,1231,9063,9082,1046,1351,9831,9064,9967,1630,1140,9830,9200,9219,9836,9216,9215,9203,9213,9201,9214,9489,9468,9478,1274,9417,9487,9506,9507,9470,9514,9962,9480,9418,9485,9431,1126,9413,9177,9593,9767,9766,1612,9755,9504,9685,3099,9665,9676,1288,9677,9294,9686,9678,9303,9324,9689,9674,9390,9748,9180,9399,9372,9336,9402,9740,9736,9375,9403,9335,9392,1132,1163,9647,9568,1155,1368,9040,9026,9637,1615,9031,1530,9663,9027,9019,9029,9656,9648,9043,9654,9038,9036,9360,9363,9344,9347,9348,9354,9355,9351,9457,9451,9461,9460,9462,9123,9697,9619,9127,9615,9614,1629,1626,9721,9610,9128,9621,9705,9720,9700,1321,9706,9701,1202,1531,1528,1527,1529,1562,1684,1691,1692,1693,9051,1720,1721,1722,1723,1726,1725,1724,1727,1728,1729,1730,1731,1733,1732,1734,1735,1736,1737,1738,1739,1740,1741,1744,1743,1742,1746,1748,1747,1749,1750,1751,1648,1642,9260,9288,1752,1753,1754,1761,10000,5722,5720,5721,5723,5727,5728,9659,9248,9846,9865,9803,9307,9332,9750,9398,9312,9889,3000,3010,3001,12345,3003,3005,1641,1649,1656,1657,1658,1659,1660,1661,1662,1663,1664,1667,1668,1669,1670,1671,1672,1673,1674,1675,1676,1677,1678,1680,1705,1707,1708,3004,3008',
													@parInclDeleted = 'Y',
													@parInclNewArticles = 'Y',
													@parSupplierArticleID = '',
													@parArticleName = '',
													@parSumAllStores = '',
													@parGroupBy = '1'


*/



------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Article proc
------------------------------------------------------------------------------------------------------------------------------------------------------------

if exists(select * from sysobjects WHERE name = N'usp_CBI_1099_ds_OmlopshastighetHjartatArticle'  AND xtype = 'P')
drop procedure  usp_CBI_1099_ds_OmlopshastighetHjartatArticle
go

create procedure [dbo].[usp_CBI_1099_ds_OmlopshastighetHjartatArticle]  @parFromDate as varchar(40),
	@parToDate as varchar(40),
	@StoreGroupNos As varchar(8000),
	@parInclDeleted As varchar(10),
	@parInclNewArticles As varchar(10),
	@parSupplierArticleID As varchar(2000),
	@parArticleName As varchar(8000),
	@parSumAllStores As varchar(8000),
	@parGroupBy As varchar(8000)

as

begin

if @parGroupBy = 2
	begin

	declare @iErrorcode as integer
	declare @sErrorMessage as varchar(1000)
	declare @ProcedureName  varchar(100)
	declare @additionalColsSql nvarchar(max) = ''
	declare @finalSql nvarchar(max) = ''
	declare @sql As nvarchar(max) = ''
	declare @TmpSoldQtysSql as nvarchar(max) = ''
	declare @DimStoresSql as nvarchar(max) = ''
	declare @MaxDate as datetime
	declare @MinDate as datetime
	declare @FromDate as datetime
	declare @ToDate as datetime

	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)
	declare @ParamDefinition nvarchar(max)
	
	set @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parFromDate nvarchar(30), @parToDate nvarchar(30), @parInclDeleted nvarchar(10), @parInclNewArticles nvarchar(10),
	@parSupplierArticleID nvarchar(2000), @parArticleName nvarchar(max), @parSumAllStores nvarchar(max), @parGroupBy nvarchar(max)
	'

	set nocount on 
	set @ProcedureName = 'vbdsp_OmlopshastighetHjartat'
	exec vbdcm.dbo.vbdspSYS_Insert_VBDtrace '1', 'Oppstart prosedyre ','',  @ProcedureName, 'Stored Procedure'

	--set dateformat dmy
	set ansi_warnings off;
	set nocount on;


---------------------------------------------------------------------------------------
-- To Calculate date
---------------------------------------------------------------------------------------
  set @MaxDate = (select max(LogDate) from StoreArticleInfoLogs
	where LogDate <= @parFromDate)
	
	set @MinDate =( select min(LogDate) from StoreArticleInfoLogs
	where LogDate >=  @parFromDate)
	
	if abs(datediff(d,@parFromDate,@MaxDate)) < abs(datediff(d,@parFromDate,@MinDate))
		set @FromDate = @MaxDate
	else
		set @FromDate = @MinDate
	
	if len(@parToDate) > 0
	begin
		set @MaxDate = (select max(LogDate) from StoreArticleInfoLogs
		where LogDate <= @parToDate)
		
		set @MinDate =( select min(LogDate) from StoreArticleInfoLogs
		where LogDate >=  @parToDate)

		if @MinDate is null 
		begin
		  set @ToDate = getdate()
		  set @parToDate = ''
		end
			else
			begin		
				if abs(datediff(d,@parToDate,@MaxDate)) < abs(datediff(d,@parToDate,@MinDate))
	  			set @ToDate = @MaxDate
				else
	  			set @ToDate = @MinDate
			end
		end
	else
		begin
			set @ToDate = getdate() 
		end
	
	IF OBJECT_ID('vbdtmp..tmpInStockDates') IS NOT NULL
	drop table vbdtmp..tmpInStockDates
	
	select @FromDate as FromDate, @ToDate AS ToDate, cast(datediff(d, @FromDate, @ToDate ) as float) as NumberOfDays
	into vbdtmp..tmpInStockDates	
	
	Set @Sql = 'CREATE UNIQUE INDEX tmpInStockDates_indx ON  vbdtmp..tmpInStockDates(FromDate)'
	
	exec (@Sql)
			
---------------------------------------------------------------------------------------
-- Creating temp store filter table
---------------------------------------------------------------------------------------

	SET @DimStoresSql = '
	IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL  DROP TABLE #DimStores '

	if len(@StoreGroupNos) > 0 
		Begin
			
			set @DimStoresSql = @DimStoresSql + '
			select StoreNo
			into #DimStores
			from dbo.ufn_CBI_getStoreNoForStoreGroups ( @StoreGroupNos )
			'
		End
	else
		Begin
			set @DimStoresSql = @DimStoresSql + '
			select null as StoreNo
			into #DimStores
			'
		End

---------------------------------------------------------------------------------------
	
	IF OBJECT_ID('vbdtmp..tmpSoldQtys') IS NOT NULL drop table vbdtmp..tmpSoldQtys
	
	set @TmpSoldQtysSql =  @TmpSoldQtysSql +'
		select stad.StoreNo, stad.ArticleNo, sum(stad.AdjustmentQty) as SoldQty
		into vbdtmp..tmpSoldQtys
		from Stockadjustments stad
	  JOIN vbdtmp..tmpInStockDates issd  on (1= 1)
	  JOIN #DimStores dimStr on dimStr.StoreNo = stad.StoreNo
	  '

	if len(@parArticleName) > 0
		set @TmpSoldQtysSql = @TmpSoldQtysSql + '
		JOIN vw_PharmaHuvudgrp  alar on stad.ArticleNo = alar.ArticleNo'
	
	set @sql = @sql + '	where StockAdjType = 1 
	AND stad.AdjustmentDate > issd.FromDate and stad.AdjustmentDate < issd.ToDate'
	
	if len(@parSupplierArticleID) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and stad.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')'
	  
	if len(@parArticleName) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and alar.ArticleName LIKE ''%'' + @parArticleName + ''%'''
	  
	set @TmpSoldQtysSql = @TmpSoldQtysSql + '	
	group by stad.storeno, stad.articleno'

	
	set @TmpSoldQtysSql = @TmpSoldQtysSql + ' Union All 

    select stad.StoreNo, stad.ArticleNo, sum(adjustmentqty * -1) as SoldQty
	from stockadjustments stad
	JOIN vbdtmp..tmpInStockDates issd  on (1= 1)
    JOIN Stores stor on (stad.StoreNo = stor.StoreNo)
	JOIN #DimStores dimStr on dimStr.StoreNo = stad.StoreNo
	'

	if len(@parArticleName) > 0
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' JOIN vw_PharmaHuvudgrp  alar on stad.ArticleNo = alar.ArticleNo'
	
	set @TmpSoldQtysSql = @TmpSoldQtysSql + '	WHERE Stockadjtype = 1
                        AND stor.StoreTypeNo = 8 
						AND stad.AdjustmentDate > issd.FromDate and stad.AdjustmentDate < issd.ToDate'


	if len(@parSupplierArticleID) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and stad.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')'

	if len(@parArticleName) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and alar.ArticleName LIKE ''%'' + @parArticleName + ''%'''

	
	set @TmpSoldQtysSql = @TmpSoldQtysSql + '	group by stad.storeno, stad.articleno 
	'
	
	set @Sql = 'CREATE UNIQUE INDEX tmpSoldQtys_indx ON  vbdtmp..tmpSoldQtys(StoreNo, ArticleNo)'
	
	set @sql = '
	IF OBJECT_ID(''tempdb..#ds_OmlopshastighetHjartatArticle'') IS NOT NULL  DROP TABLE #ds_OmlopshastighetHjartatArticle 
	select '
	
	if @parSumAllStores = 'Y'
		set @sql = @sql + '0 as InternalStoreID , ''Alle'' as StoreName,'
	else 
		set @sql = @sql + 'stor.InternalStoreID, stor.StoreNo, stor.StoreName,'
	
	if @parGroupBy= '2'
		set @sql = @sql + ' 
		alar.ArticleName, 
		max(alar.ArticleID) as ArticleID,
		alar.SupplierName, 
		alar.SupplierNo, 
		sain.articleno, 
		alar.huvudgrp,
		Isnull(max(alar.ArticleHierID), max(alar.ArticleHierNo)) as ArticleHierID, 
		alar.EanNo, 
		alar.supplierarticleid, 
		aaap.netprice,'


	set @sql = @sql +' CONVERT(VARCHAR, max(sail.Logdate), 23)  as DateFrom,
	'
	    
	if len (@parToDate) > 0
		set @sql = @sql +' CONVERT(VARCHAR, max(sain.Logdate), 23) as DateTo,
		'
	else
		set @sql = @sql +' CONVERT(VARCHAR, getdate(), 23) as DateTo,
		 '

	set @sql = @sql +'max(issd.NumberOfDays) as NumberOfDays,
        alar.Huvudgrp as gruppering,
	    sum(ISNULL(sail.instockqty,0)) as QtyStart,
	    ISNULL(sum(isnull(sail.InstockQty * sast.NetPriceDerived, 
		sail.instockAmount)),0) as ValueStart,
	    sum(ISNULL(sain.instockqty,0)) as QtyEnd,
	    sum(ISNULL(sain.instockqty,0) * ISNULL(sast.NetPriceDerived, 
		isnull(aaap.Netprice,0))) as ValueEnd,   
	    sum(ISNULL(sqty.SoldQty,0)) * -1 as SoldQty1,
	    CASE 
			WHEN sum(Isnull(sail.instockqty,0)) + sum(isnull(sain.instockqty,0))  < 0.1  OR ISNULL(max(issd.NumberOfDays), 0) = 0 
		THEN 0 
	    ELSE  ( 365/max(issd.NumberOfDays)) * (sum(isnull(sqty.SoldQty,0))) * -1 / (( ISNULL(sum(isnull(sail.instockqty,0)),0) + ISNULL(sum(isnull(sain.instockqty,0)),0))/ 2) 
	    END as omlopshastighet,

		CASE 
	        WHEN sum(Isnull(sail.instockqty,0)) + sum(isnull(sain.instockqty,0))  < 0.1 OR ISNULL(max(issd.NumberOfDays), 0) = 0 OR (sum(isnull(sqty.SoldQty,0))) = 0  THEN 
				0 
	        ELSE 365/((365/max(issd.NumberOfDays)) * (sum(isnull(sqty.SoldQty,0))) * -1 /
				 (( ISNULL(sum(isnull(sail.instockqty,0)),0) + ISNULL(sum(isnull(sain.instockqty,0)),0))/ 2) )
	     END as dagilager,
	     CASE 
			WHEN sum(isnull(sqty.SoldQty,0)) = 0 OR max(issd.NumberOfDays) = 0 THEN 
				0
			ELSE 
				sum(isnull(sain.instockqty,0))	/ (sum(isnull(sqty.SoldQty,0)) * -1  / max(issd.NumberOfDays))
		 END AS DaysInStock1,
		 MAX(2) AS GroupBy
	  into #ds_OmlopshastighetHjartatArticle
	  from '
	

	
	if len(@parToDate) > 0
		set @sql = @sql +'	storearticleinfologs sain'
	else
		set @sql = @sql +' storearticleinfos sain '

	set @sql = @sql +' JOIN vbdtmp..tmpInStockDates issd on (1 = 1)
	JOIN vw_PharmaHuvudgrp alar on (sain.articleno = alar.articleno)
	JOIN Stores stor on (sain.StoreNo = stor.StoreNo)
	JOIN #DimStores dimStr on dimStr.StoreNo = stor.StoreNo
	--JOIN Assortment asor on (sain.StoreNo = asor.StoreNo and sain.articleno = asor.articleno)
	JOIN ActiveAllArticlePrices aaap on (sain.StoreNo = aaap.StoreNo and sain.Articleno = aaap.ArticleNo)
	LEFT OUTER JOIN storearticleinfologs sail on (sail.StoreNo = sain.StoreNo and sail.ArticleNo = sain.ArticleNo and sail.Logdate = issd.FromDate)  
	LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sasl on (sasl.StoreNo = sail.StoreNo 
		AND sasl.ArticleNo = sail.ArticleNo 
		AND sasl.LogDate = sail.LogDate
		AND sasl.StockTypeNo = 1) '
						  
	if len(@parToDate) > 0
		set @sql = @sql +'
		LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sast on (sast.StoreNo = sain.StoreNo 
			AND sast.ArticleNo = sain.ArticleNo 
			AND sast.LogDate = sain.LogDate
			AND sast.StockTypeNo = 1) ' 	  
	else
		set @sql = @sql +' 
		  LEFT OUTER JOIN storearticleinfoStockTypes sast on (sast.StoreNo = sain.StoreNo and sast.ArticleNo = sain.ArticleNo and sast.StockTypeNo = 1) '  	
	  
	set @sql = @sql +'
	LEFT OUTER JOIN vbdtmp..tmpSoldQtys sqty on (sain.StoreNo = sqty.StoreNo and sain.ArticleNo = sqty.ArticleNo) '
	set @sql = @sql + ' where 1 = 1 '  
	
	if @parInclNewArticles != 'Y' 
		set @sql = @sql + ' and sail.logdate is not null '
		
	if len (@parToDate) > 0
		set @sql = @sql +' And sain.LogDate = issd.ToDate '

	if len(@parSupplierArticleID) > 0 
		set @sql = @sql + ' and alar.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')'

	if len(@parArticleName) > 0 
		set @sql = @sql + ' and alar.ArticleName LIKE ''%'' + @parArticleName + ''%'''

	if len(isnull(@StoreGroupNos,'')) = 0
		set @sql = @sql + '  and stor.storetypeno = 7 and stor.storestatus < 9  '
	
	if @parInclDeleted != 'Y' 
		set @sql = @sql + ' and alar.articlestatus < 8  '
	

	if @parSumAllStores = 'Y'
		set @sql = @sql + ' group by '
	else
		set @sql = @sql +' group by stor.StoreNo, stor.InternalStoreID, stor.StoreName, '
	
	if @parGroupBy = '2'  
		set @sql = @sql + ' alar.SupplierName, alar.SupplierNo, sain.ArticleNo, alar.huvudgrp,alar.ArticleName, 	  	
		ArticleHierNameTop,alar.EanNo, alar.supplierarticleid, aaap.netprice '


	--set @sql = @sql + ' Order by 1,2,3,4'


	--print (@DimStoresSql)
	--print (@TmpSoldQtysSql)
	--print (@sql)

--	exec (@sql)

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
	set @additionalColsSql = @additionalColsSql + '

	IF OBJECT_ID(''tempdb..#DynamicValues'') IS NOT NULL  DROP TABLE #DynamicValues 
	CREATE TABLE #DynamicValues ( articleNo int, articleId varchar(50),
	'+
	@colsCreateTable
	+')
	
	'

	-- In proc selecting from  #ArticleNos and inserting into #DynamicValues
	set @additionalColsSql = @additionalColsSql + '

	IF OBJECT_ID(''tempdb..#ArticleNos'') IS NOT NULL DROP TABLE #ArticleNos
	SELECT distinct ArticleNo
	into #ArticleNos 
	FROM #ds_OmlopshastighetHjartatArticle
	'

	if len(@StoreGroupNos ) > 0 and (select charindex(',', @StoreGroupNos ) ) > 0
	begin
		set @additionalColsSql = @additionalColsSql + ' 	
		insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
		exec CBI_vrsp_GetDynamicValues @StoreNo = 0, @GetStoreArticleValues = 1 '
	end

	if len(@StoreGroupNos ) > 0 and (select charindex(',', @StoreGroupNos ) ) = 0 
	begin
		set @additionalColsSql = @additionalColsSql + ' 
		insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
		exec CBI_vrsp_GetDynamicValues @StoreNo = ' + @StoreGroupNos + ', @GetStoreArticleValues = 1
		'
	end


	set @additionalColsSql = @additionalColsSql + '
		(
		select a.*,
		'+ @colsFinal
		+'
		from #ds_OmlopshastighetHjartatArticle a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		) Order by 1,2,3,4
		'
	
	print(@additionalColsSql)

	set @finalSql = @DimStoresSql + @TmpSoldQtysSql + @sql + @additionalColsSql

	exec sp_executesql  @finalSql
						,@ParamDefinition
						,@StoreGroupNos = @StoreGroupNos
						,@parFromDate = @parFromDate
						,@parToDate = @parToDate
						,@parInclDeleted = @parInclDeleted
						,@parInclNewArticles = @parInclNewArticles
						,@parSupplierArticleID = @parSupplierArticleID
						,@parArticleName = @parArticleName
						,@parSumAllStores = @parSumAllStores
						,@parGroupBy = @parGroupBy


ErrorHandler:

  IF (@iErrorCode <> 0)
	  begin
		set @sErrorMessage = (select description from master..sysmessages where error = @iErrorCode)
		exec vbdcm.dbo.vbdspSYS_insert_vbderror @iErrorCode, @sErrorMessage, 
				@ProcedureName, 'Stored Procedure', '', ''
	  end
  else
	  begin
		EXEC vbdcm.dbo.vbdspSYS_Insert_VBDtrace '1', 'Ferdig prosedyre', '',  @ProcedureName, 'Stored Procedure'
	  end

end

end -- if @parGroupBy = 2 end


GO

/*

exec usp_CBI_1099_ds_OmlopshastighetHjartatArticle	@parFromDate = '2008-01-01',
														@parToDate = '2018-05-23',
														@StoreGroupNos  = '3000',--,375,3009,1007,2000,2999,3002,9232,9908,9237,9190,9929,9227,9913,9223,9270,9798,9765,1047,9808,9275,1265,1286,9242,9226,9915,9942,1107,9269,9266,9259,9802,9008,9189,1136,9557,9566,1152,9868,9893,9896,9900,9546,9119,1332,9553,9562,9003,9580,9101,9527,9549,9548,9520,9559,9542,9118,9149,9157,9168,9138,9161,9139,9829,9838,9085,1231,9063,9082,1046,1351,9831,9064,9967,1630,1140,9830,9200,9219,9836,9216,9215,9203,9213,9201,9214,9489,9468,9478,1274,9417,9487,9506,9507,9470,9514,9962,9480,9418,9485,9431,1126,9413,9177,9593,9767,9766,1612,9755,9504,9685,3099,9665,9676,1288,9677,9294,9686,9678,9303,9324,9689,9674,9390,9748,9180,9399,9372,9336,9402,9740,9736,9375,9403,9335,9392,1132,1163,9647,9568,1155,1368,9040,9026,9637,1615,9031,1530,9663,9027,9019,9029,9656,9648,9043,9654,9038,9036,9360,9363,9344,9347,9348,9354,9355,9351,9457,9451,9461,9460,9462,9123,9697,9619,9127,9615,9614,1629,1626,9721,9610,9128,9621,9705,9720,9700,1321,9706,9701,1202,1531,1528,1527,1529,1562,1684,1691,1692,1693,9051,1720,1721,1722,1723,1726,1725,1724,1727,1728,1729,1730,1731,1733,1732,1734,1735,1736,1737,1738,1739,1740,1741,1744,1743,1742,1746,1748,1747,1749,1750,1751,1648,1642,9260,9288,1752,1753,1754,1761,10000,5722,5720,5721,5723,5727,5728,9659,9248,9846,9865,9803,9307,9332,9750,9398,9312,9889,3000,3010,3001,12345,3003,3005,1641,1649,1656,1657,1658,1659,1660,1661,1662,1663,1664,1667,1668,1669,1670,1671,1672,1673,1674,1675,1676,1677,1678,1680,1705,1707,1708,3004,3008',
														@parInclDeleted = 'Y',
														@parInclNewArticles = 'Y',
														@parSupplierArticleID = '',
														@parArticleName = '',
														@parSumAllStores = '',
														@parGroupBy = '2'

*/





------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main Group No
------------------------------------------------------------------------------------------------------------------------------------------------------------

if exists(select * from sysobjects WHERE name = N'usp_CBI_1099_ds_OmlopshastighetHjartatMainGroupNo'  AND xtype = 'P')
drop procedure  usp_CBI_1099_ds_OmlopshastighetHjartatMainGroupNo
go

create procedure [dbo].[usp_CBI_1099_ds_OmlopshastighetHjartatMainGroupNo] 		@parFromDate as varchar(40),
	@parToDate as varchar(40),
	@StoreGroupNos As varchar(8000),
	@parInclDeleted As varchar(10),
	@parInclNewArticles As varchar(10),
	@parSupplierArticleID As varchar(2000),
	@parArticleName As varchar(8000),
	@parSumAllStores As varchar(8000),
	@parGroupBy As varchar(8000)
as

begin

if @parGroupBy = 4
	begin

	declare @iErrorcode as integer
	declare @sErrorMessage as varchar(1000)
	declare @ProcedureName  varchar(100)
	declare @additionalColsSql nvarchar(max) = ''
	declare @finalSql nvarchar(max) = ''
	declare @sql As nvarchar(max) = ''
	declare @TmpSoldQtysSql as nvarchar(max) = ''
	declare @DimStoresSql as nvarchar(max) = ''
	declare @MaxDate as datetime
	declare @MinDate as datetime
	declare @FromDate as datetime
	declare @ToDate as datetime

	declare @colsPivot as varchar(max)
	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsPivotFilt as varchar(max)
	declare @colsToInsertTbl as varchar(max)
	declare @ParamDefinition nvarchar(max)
	
	set @ParamDefinition = N'@StoreGroupNos nvarchar(max), @parFromDate nvarchar(30), @parToDate nvarchar(30), @parInclDeleted nvarchar(10), @parInclNewArticles nvarchar(10),
	@parSupplierArticleID nvarchar(2000), @parArticleName nvarchar(max), @parSumAllStores nvarchar(max), @parGroupBy nvarchar(max)
	'


	set nocount on 
	set @ProcedureName = 'vbdsp_OmlopshastighetHjartat'
	exec vbdcm.dbo.vbdspSYS_Insert_VBDtrace '1', 'Oppstart prosedyre ','',  @ProcedureName, 'Stored Procedure'

	set dateformat dmy
	set ansi_warnings off
	set nocount on

---------------------------------------------------------------------------------------
-- To Calculate date
---------------------------------------------------------------------------------------
	set @MaxDate = (select max(LogDate) from StoreArticleInfoLogs
	where LogDate <= @parFromDate)
	
	set @MinDate =( select min(LogDate) from StoreArticleInfoLogs
	where LogDate >=  @parFromDate)
	
	if abs(datediff(d,@parFromDate,@MaxDate)) < abs(datediff(d,@parFromDate,@MinDate))
		set @FromDate = @MaxDate
	else
		set @FromDate = @MinDate
	
	if len(@parToDate) > 0
	begin
		set @MaxDate = (select max(LogDate) from StoreArticleInfoLogs
		where LogDate <= @parToDate)
		
		set @MinDate =( select min(LogDate) from StoreArticleInfoLogs
		where LogDate >=  @parToDate)

		if @MinDate is null 
		begin
			set @ToDate = getdate()
			set @parToDate = ''
		end
		else
		begin		
			if abs(datediff(d,@parToDate,@MaxDate)) < abs(datediff(d,@parToDate,@MinDate))
	  		set @ToDate = @MaxDate
			else
	  		set @ToDate = @MinDate
		end
	end
	else
	begin
		set @ToDate = getdate() 
	end
	
	IF OBJECT_ID('vbdtmp..tmpInStockDates') IS NOT NULL
	drop table vbdtmp..tmpInStockDates
	
	select @FromDate as FromDate, @ToDate AS ToDate, cast(datediff(d, @FromDate, @ToDate ) as float) as NumberOfDays
	into vbdtmp..tmpInStockDates	
	
	Set @Sql = 'CREATE UNIQUE INDEX tmpInStockDates_indx ON  vbdtmp..tmpInStockDates(FromDate)'
	
	exec (@Sql)
			
---------------------------------------------------------------------------------------
-- Creating temp store filter table
---------------------------------------------------------------------------------------

	SET @DimStoresSql = '
	IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL  DROP TABLE #DimStores '

	if len(@StoreGroupNos) > 0 
		Begin
			
			set @DimStoresSql = @DimStoresSql + '
			select StoreNo
			into #DimStores
			from dbo.ufn_CBI_getStoreNoForStoreGroups ( @StoreGroupNos )
			'
		End
	else
		Begin
			set @DimStoresSql = @DimStoresSql + '
			select null as StoreNo
			into #DimStores
			'
		End

---------------------------------------------------------------------------------------
	
	IF OBJECT_ID('vbdtmp..tmpSoldQtys') IS NOT NULL drop table vbdtmp..tmpSoldQtys
	
	set @TmpSoldQtysSql = '
	select stad.StoreNo, 
		   stad.ArticleNo, 
		   sum(stad.AdjustmentQty) as SoldQty
	into vbdtmp..tmpSoldQtys
	from Stockadjustments stad
	JOIN vbdtmp..tmpInStockDates issd  on (1= 1)
	JOIN #DimStores dimStr on dimStr.StoreNo = stad.StoreNo
	'

	if len(@parArticleName) > 0
		set @TmpSoldQtysSql = @TmpSoldQtysSql + '
		JOIN vw_PharmaHuvudgrp  alar on stad.ArticleNo = alar.ArticleNo
		'
	
	set @TmpSoldQtysSql = @TmpSoldQtysSql + '	where StockAdjType = 1
	AND stad.AdjustmentDate > issd.FromDate and stad.AdjustmentDate < issd.ToDate '
	  

	if len(@parSupplierArticleID) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and stad.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')
		'
	  
	if len(@parArticleName) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and alar.ArticleName LIKE ''%'' + @parArticleName + ''%''
		'
	  

	set @TmpSoldQtysSql = @TmpSoldQtysSql + '	
	group by stad.storeno, stad.articleno'

	
	set @TmpSoldQtysSql = @TmpSoldQtysSql + ' Union All 

	select	stad.StoreNo, 
			stad.ArticleNo, 
			sum(adjustmentqty * -1) as SoldQty
	from stockadjustments stad
	JOIN vbdtmp..tmpInStockDates issd  on (1= 1)
	JOIN Stores stor on (stad.StoreNo = stor.StoreNo)
	JOIN #DimStores dimStr on dimStr.StoreNo = stad.StoreNo
	'
	  
	if len(@parArticleName) > 0
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' JOIN vw_PharmaHuvudgrp  alar on stad.ArticleNo = alar.ArticleNo
		'
	
	
	set @TmpSoldQtysSql = @TmpSoldQtysSql + '	WHERE Stockadjtype = 1
                        AND stor.StoreTypeNo = 8
              AND stad.AdjustmentDate > issd.FromDate and stad.AdjustmentDate < issd.ToDate
			  '

	if len(@parSupplierArticleID) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and stad.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')
		'

	if len(@parArticleName) > 0 
		set @TmpSoldQtysSql = @TmpSoldQtysSql + ' and alar.ArticleName LIKE ''%'' + @parArticleName + ''%''
		'

	set @TmpSoldQtysSql = @TmpSoldQtysSql + '	group by stad.storeno, stad.articleno
	'
	
	set @Sql = 'CREATE UNIQUE INDEX tmpSoldQtys_indx ON  vbdtmp..tmpSoldQtys(StoreNo, ArticleNo)
	'
	
	set @sql = ' 
	SELECT '
	
	if @parSumAllStores = 'Y'
		set @sql = @sql + '0 as InternalStoreID , ''Alle'' as StoreName,'
	else 
		set @sql = @sql + 'stor.InternalStoreID, stor.StoreNo, stor.StoreName,'

	if @parGroupBy= '4'
		set @sql = @sql + ' alar.huvudgrp,
		'
	
	set @sql = @sql +' CONVERT(VARCHAR, max(sail.Logdate), 23)  as DateFrom,
	'
	    
	if len (@parToDate) > 0
		set @sql = @sql +' CONVERT(VARCHAR, max(sain.Logdate), 23) as DateTo,
		'
	else
		set @sql = @sql +' CONVERT(VARCHAR, getdate(), 23) as DateTo,
		 '

	set @sql = @sql +'max(issd.NumberOfDays) as NumberOfDays,
        alar.Huvudgrp as gruppering,
	    sum(ISNULL(sail.instockqty,0)) as QtyStart,
	    ISNULL(sum(isnull(sail.InstockQty * sast.NetPriceDerived, 
		sail.instockAmount)),0) as ValueStart,
	    sum(ISNULL(sain.instockqty,0)) as QtyEnd,
	    sum(ISNULL(sain.instockqty,0) * ISNULL(sast.NetPriceDerived, 
		isnull(aaap.Netprice,0))) as ValueEnd,   
	    sum(ISNULL(sqty.SoldQty,0)) * -1 as SoldQty1,
	    CASE 
			WHEN sum(Isnull(sail.instockqty,0)) + sum(isnull(sain.instockqty,0))  < 0.1  OR ISNULL(max(issd.NumberOfDays), 0) = 0 
		THEN 0 
	    ELSE  ( 365/max(issd.NumberOfDays)) * (sum(isnull(sqty.SoldQty,0))) * -1 / (( ISNULL(sum(isnull(sail.instockqty,0)),0) + ISNULL(sum(isnull(sain.instockqty,0)),0))/ 2) 
	    END as omlopshastighet,

		CASE 
	        WHEN sum(Isnull(sail.instockqty,0)) + sum(isnull(sain.instockqty,0))  < 0.1 OR ISNULL(max(issd.NumberOfDays), 0) = 0 OR (sum(isnull(sqty.SoldQty,0))) = 0  THEN 
				0 
	        ELSE 365/((365/max(issd.NumberOfDays)) * (sum(isnull(sqty.SoldQty,0))) * -1 /
				 (( ISNULL(sum(isnull(sail.instockqty,0)),0) + ISNULL(sum(isnull(sain.instockqty,0)),0))/ 2) )
	     END as dagilager,
	     CASE 
			WHEN sum(isnull(sqty.SoldQty,0)) = 0 OR max(issd.NumberOfDays) = 0 THEN 
				0
			ELSE 
				sum(isnull(sain.instockqty,0))	/ (sum(isnull(sqty.SoldQty,0)) * -1  / max(issd.NumberOfDays))
		 END AS DaysInStock1,
		 MAX(2) AS GroupBy
	  FROM '
	

	
	if len(@parToDate) > 0
		set @sql = @sql +'	storearticleinfologs sain'
	else
		set @sql = @sql +'storearticleinfos sain '

	set @sql = @sql +' JOIN vbdtmp..tmpInStockDates issd on (1 = 1)
	JOIN vw_PharmaHuvudgrp alar on (sain.articleno = alar.articleno)
	JOIN Stores stor on (sain.StoreNo = stor.StoreNo)
	JOIN #DimStores dimStr on dimStr.StoreNo = stor.StoreNo
	--JOIN Assortment asor on (sain.StoreNo = asor.StoreNo and sain.articleno = asor.articleno)
	JOIN ActiveAllArticlePrices aaap on (sain.StoreNo = aaap.StoreNo and sain.Articleno = aaap.ArticleNo)
	LEFT OUTER JOIN storearticleinfologs sail on (sail.StoreNo = sain.StoreNo and sail.ArticleNo = sain.ArticleNo and sail.Logdate = issd.FromDate)  
	LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sasl on (sasl.StoreNo = sail.StoreNo 
					AND sasl.ArticleNo = sail.ArticleNo 
					AND sasl.LogDate = sail.LogDate
					AND sasl.StockTypeNo = 1)'
						  
	if len(@parToDate) > 0
		set @sql = @sql +'
			LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sast on (sast.StoreNo = sain.StoreNo 
							AND sast.ArticleNo = sain.ArticleNo 
							AND sast.LogDate = sain.LogDate
							AND sast.StockTypeNo = 1)' 	  
	else
		set @sql = @sql +' 
			LEFT OUTER JOIN storearticleinfoStockTypes sast on (sast.StoreNo = sain.StoreNo and sast.ArticleNo = sain.ArticleNo and sast.StockTypeNo = 1)'  	
	  
	set @sql = @sql +'
		LEFT OUTER JOIN vbdtmp..tmpSoldQtys sqty on (sain.StoreNo = sqty.StoreNo and sain.ArticleNo = sqty.ArticleNo)'
	set @sql = @sql + ' where 1 = 1 '  
	
	if @parInclNewArticles != 'Y' 
		set @sql = @sql + ' and sail.logdate is not null '
		
	if len (@parToDate) > 0
		set @sql = @sql +' And sain.LogDate = issd.ToDate'
	
	if len(@parSupplierArticleID) > 0 
		set @sql =@sql + ' and alar.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%'' + @parSupplierArticleID + ''%'')'

	if len(@parArticleName) > 0 
		set @sql =@sql + ' and alar.ArticleName LIKE ''%'' + @parArticleName + ''%'''

	if len(isnull(@StoreGroupNos, '')) > 0
		set @sql = @sql + '  and stor.storetypeno = 7 and stor.storestatus < 9  '
	
	if @parInclDeleted != 'Y' 
		set @sql = @sql + ' and alar.articlestatus < 8  '
	

	if @parSumAllStores = 'Y'
		set @sql = @sql + ' group by'
	else
		set @sql = @sql +' group by stor.StoreNo, stor.InternalStoreID, stor.StoreName,'

	if @parGroupBy = '4'  
		set @sql = @sql + ' alar.huvudgrp'
	

	--print (@DimStoresSql)
	--print (@TmpSoldQtysSql)
	--print (@sql)

	set @finalSql  = @DimStoresSql + @TmpSoldQtysSql + @sql
	
	exec sp_executesql  @finalSql
						,@ParamDefinition
						,@StoreGroupNos = @StoreGroupNos
						,@parFromDate = @parFromDate
						,@parToDate = @parToDate
						,@parInclDeleted = @parInclDeleted
						,@parInclNewArticles = @parInclNewArticles
						,@parSupplierArticleID = @parSupplierArticleID
						,@parArticleName = @parArticleName
						,@parSumAllStores = @parSumAllStores
						,@parGroupBy = @parGroupBy



ErrorHandler:

  IF (@iErrorCode <> 0)
	  begin
		set @sErrorMessage = (select description from master..sysmessages where error = @iErrorCode)
		exec vbdcm.dbo.vbdspSYS_insert_vbderror @iErrorCode, @sErrorMessage, 
				@ProcedureName, 'Stored Procedure', '', ''
	  end
  else
	  begin
		EXEC vbdcm.dbo.vbdspSYS_Insert_VBDtrace '1', 'Ferdig prosedyre', '',  @ProcedureName, 'Stored Procedure'
	  end

end

end -- if @parGroupBy = 4 end


GO


/*

exec usp_CBI_1099_ds_OmlopshastighetHjartatMainGroupNo	@parFromDate = '2018-01-01',
															@parToDate = '2018-07-01',
															@StoreGroupNos  = '0,375,3009,1007,2000,2999,3002,9232,9908,9237,9190,9929,9227,9913,9223,9270,9798,9765,1047,9808,9275,1265,1286,9242,9226,9915,9942,1107,9269,9266,9259,9802,9008,9189,1136,9557,9566,1152,9868,9893,9896,9900,9546,9119,1332,9553,9562,9003,9580,9101,9527,9549,9548,9520,9559,9542,9118,9149,9157,9168,9138,9161,9139,9829,9838,9085,1231,9063,9082,1046,1351,9831,9064,9967,1630,1140,9830,9200,9219,9836,9216,9215,9203,9213,9201,9214,9489,9468,9478,1274,9417,9487,9506,9507,9470,9514,9962,9480,9418,9485,9431,1126,9413,9177,9593,9767,9766,1612,9755,9504,9685,3099,9665,9676,1288,9677,9294,9686,9678,9303,9324,9689,9674,9390,9748,9180,9399,9372,9336,9402,9740,9736,9375,9403,9335,9392,1132,1163,9647,9568,1155,1368,9040,9026,9637,1615,9031,1530,9663,9027,9019,9029,9656,9648,9043,9654,9038,9036,9360,9363,9344,9347,9348,9354,9355,9351,9457,9451,9461,9460,9462,9123,9697,9619,9127,9615,9614,1629,1626,9721,9610,9128,9621,9705,9720,9700,1321,9706,9701,1202,1531,1528,1527,1529,1562,1684,1691,1692,1693,9051,1720,1721,1722,1723,1726,1725,1724,1727,1728,1729,1730,1731,1733,1732,1734,1735,1736,1737,1738,1739,1740,1741,1744,1743,1742,1746,1748,1747,1749,1750,1751,1648,1642,9260,9288,1752,1753,1754,1761,10000,5722,5720,5721,5723,5727,5728,9659,9248,9846,9865,9803,9307,9332,9750,9398,9312,9889,3000,3010,3001,12345,3003,3005,1641,1649,1656,1657,1658,1659,1660,1661,1662,1663,1664,1667,1668,1669,1670,1671,1672,1673,1674,1675,1676,1677,1678,1680,1705,1707,1708,3004,3008',
															@parInclDeleted = 'Y',
															@parInclNewArticles = 'Y',
															@parSupplierArticleID = '',
															@parArticleName = '',
															@parSumAllStores = '',
															@parGroupBy = '4'

*/