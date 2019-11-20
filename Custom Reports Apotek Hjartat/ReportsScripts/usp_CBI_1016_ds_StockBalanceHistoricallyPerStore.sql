if exists(select * from sysobjects where name = N'usp_CBI_1016_ds_StockBalanceHistoricallyPerStore' and xtype = 'P')
drop procedure usp_CBI_1016_ds_StockBalanceHistoricallyPerStore
go


create procedure usp_CBI_1016_ds_StockBalanceHistoricallyPerStore (@StoreGroupNos as varchar(8000) = '' --both should be mandatory
																	 ,@parNearestDate as varchar(30)= '')
as
	--Rapport nr 1016
	
	set nocount on;	-- This has to be here. In some installations jasper is not returning a resultset if this is not here

	declare @sql as nvarchar(max)
	set @sql = ''
------------------------------------------------------------------------------------------------------
	
	SET @sql = @sql +  '
	IF OBJECT_ID(''tempdb..#ds_StockBalanceHistoricallyPerStore'') IS NOT NULL  DROP TABLE #ds_StockBalanceHistoricallyPerStore '

	if len(@StoreGroupNos) > 0 
		Begin
			
			SET @sql = @sql +  '
			;WITH DimStores AS (
			select StoreNo
			from  dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) 
			)
			'
		End
	else
		Begin
			SET @sql = @sql +  '
			;WITH DimStores AS (
			select null as StoreNo
			)
			'
		End


	set @sql = @sql + '
	SELECT  
		sto.StoreNo,    
		sto.StoreName,	
		COUNT(sai.ArticleNo) as AntalVaror,
		--SUM(isnull(sai.InStockAmount,0))  as Återanskaffningskostnad,
		SUM (CASE WHEN
					 (ISNULL(sai.InStockQty,0) + isnull(sai.StockInTransitQty,0)  + ISNULL(sai.OnServiceQty,0))  > 0
				   THEN
					 (ISNULL(sai.InStockQty,0) + isnull(sai.StockInTransitQty,0)  + ISNULL(sai.OnServiceQty,0))
				   ELSE 0
			 END) as TotalQTY,

		SUM (CASE WHEN 
					   (ISNULL(sai.InStockQty,0) + isnull(sai.StockInTransitQty,0)  + ISNULL(sai.OnServiceQty,0))  > 0
				  THEN  
					   (ISNULL(sai.InStockQty,0) + isnull(sai.StockInTransitQty,0) 
					  + ISNULL(sai.OnServiceQty,0)) * ISNULL(sast.NetPriceDerived, 0) 
				  ELSE 0
			END) as Lagervärde,

		SUM(CASE WHEN
					   ISNULL(sai.BStockQty,0)>0
				   THEN 
					   (ISNULL(sai.BStockQty,0) ) 
				   ELSE 0
			 END) as TotalBQTY,
	
		SUM(CASE WHEN
					   ISNULL(sai.BStockQty,0)>0
				   THEN 
					   (ISNULL(sai.BStockQty,0) * ISNULL(sast2.NetPriceDerived, 0) ) 
				   ELSE 0
			 END) as BLagervärde
	FROM StoreArticleInfoLogs sai
	LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sast on (sast.StoreNo = sai.StoreNo 
	AND sast.ArticleNo = sai.ArticleNo AND sast.LogDate = sai.LogDate AND sast.StockTypeNo = 1) 
                 LEFT OUTER JOIN StoreArticleInfoStockTypeLogs sast2 on (sast2.StoreNo = sai.StoreNo 
	AND sast2.ArticleNo = sai.ArticleNo AND sast2.LogDate = sai.LogDate AND sast2.StockTypeNo = 2) 
	JOIN Stores sto on (sai.StoreNo = sto.StoreNo)	
	JOIN DimStores dimStr on (sto.StoreNo = dimStr.StoreNo)

	WHERE sai.logdate = (select max(logdate) from storearticleinfologs where logdate < cast( @parNearestDate + '' 23:59:59'' as datetime) )'
	
	set @sql = @sql + '
	GROUP BY sto.StoreNo,sto.StoreName' 

	set @sql = @sql + ' 
	ORDER BY sto.StoreNo'


	exec sp_executesql @sql,
					   N'@StoreGroupNos nvarchar(max), @parNearestDate nvarchar(30)',
					   @StoreGroupNos = @StoreGroupNos,
					   @parNearestDate = @parNearestDate


go




/*
exec usp_CBI_1016_ds_StockBalanceHistoricallyPerStore @StoreGroupNos = N'3000,3004,9865,9157,1742,9485,1725,9740,9403,9019,1612,1751,9372,9354,1657,9798,9478,9831,9838,1126,9648,9697,9686,9568,9177,9351,1649,1733,1746,1155,9829,1754,1047,1667,9363,9431,9915,9654,1739,1747,1735,1721,1752,1720,1668,1728,9223,9360,9830,1750,1332,1732,9288,1658,1749,1738,1648,1669,9390,1152,1642,1659,9085,1730,9460,1670,9063,9836,1671,9720,1661,1707,9201,9566,1531,1744,1660,9392,9119,1321,1740,1662,9038,9043,9487,9398,9705,9678,9461,9348,1368,1132,9417,9336,9665,9748,9418,9967,9803,1274,9190,9399,9674,9375,1672,1529,9559,9546,1107,1674,1673,9676,1748,9082,9659,9507,1562,9200,1675,9232,9226,1626,9324,1734,9802,1722,1705,9270,1140,9750,9553,9332,1676,9868,9260,1288,9580,9700,1737,1753,9008,9900,9685,1136,9846,9227,9562,9203,1265,9101,9027,9040,9896,9402,9312,9514,9413,9677,1677,1630,9189,1351,1629,9259,1726,9506,9766,9457,1663,9128,9242,9237,1692,1163,1761,9548,1530,9335,9942,9180,9470,9344,9026,9701,9138,9269,9808,1664,1678,9303,9031,9036,9029,1724,9248,1691,1680,9355,9929,9619,9064,9765,9127,9614,9275,9621,9656,9214,9542,1727,9893,1202,9663,1528,1615,9462,1731,1693,9161,9767,9755,9504,9118,9266,1743,1286,1527,1723,9913,3008,1684,9908,9520,9294,1708,9123,9549,9527,9557,9003,9615,9647,1046,9451,9213,9610,9215,9706,9489,9480,9468,9216,9962,9139,9219,9637,9149,9721,9168,9307,1641,9689,1729,9347,9736,9593,1231,1741,1736,9051,3099,5720,10000,3002,2000,12345,3003,5728,5721,3005,5727,5722,9889,3001,3009,0375,2999,1007,3010,5723', --'5122,9227,9403,3000,3010', 
														@parNearestDate= '2018-07-01'


exec usp_CBI_1016_ds_StockBalanceHistoricallyPerStore	@StoreGroupNos = N'3004,9865,9157,1742,9485,1725,9740,9403,9019,1612,1751,9372,9354,1657,9798,9478,9831,9838,1126,9648,9697,9686,9568,9177,9351,1649,1733,1746,1155,9829,1754,1047,1667,9363,9431,9915,9654,1739,1747,1735,1721,1752,1720,1668,1728,9223,9360,9830,1750,1332,1732,9288,1658,1749,1738,1648,1669,9390,1152,1642,1659,9085,1730,9460,1670,9063,9836,1671,9720,1661,1707,9201,9566,1531,1744,1660,9392,9119,1321,1740,1662,9038,9043,9487,9398,9705,9678,9461,9348,1368,1132,9417,9336,9665,9748,9418,9967,9803,1274,9190,9399,9674,9375,1672,1529,9559,9546,1107,1674,1673,9676,1748,9082,9659,9507,1562,9200,1675,9232,9226,1626,9324,1734,9802,1722,1705,9270,1140,9750,9553,9332,1676,9868,9260,1288,9580,9700,1737,1753,9008,9900,9685,1136,9846,9227,9562,9203,1265,9101,9027,9040,9896,9402,9312,9514,9413,9677,1677,1630,9189,1351,1629,9259,1726,9506,9766,9457,1663,9128,9242,9237,1692,1163,1761,9548,1530,9335,9942,9180,9470,9344,9026,9701,9138,9269,9808,1664,1678,9303,9031,9036,9029,1724,9248,1691,1680,9355,9929,9619,9064,9765,9127,9614,9275,9621,9656,9214,9542,1727,9893,1202,9663,1528,1615,9462,1731,1693,9161,9767,9755,9504,9118,9266,1743,1286,1527,1723,9913,3008,1684,9908,9520,9294,1708,9123,9549,9527,9557,9003,9615,9647,1046,9451,9213,9610,9215,9706,9489,9480,9468,9216,9962,9139,9219,9637,9149,9721,9168,9307,1641,9689,1729,9347,9736,9593,1231,1741,1736,9051,3099,5720,10000,3002,2000,12345,3003,5728,5721,3005,5727,5722,9889,3001,3009,0375,2999,1007,3010,5723', --'5122,9227,9403,3000,3010', 
														@parNearestDate= '2018-10-30'

*/