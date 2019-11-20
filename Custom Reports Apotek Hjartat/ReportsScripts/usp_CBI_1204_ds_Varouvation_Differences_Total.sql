GO
USE [VBDCM]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES r WHERE r.ROUTINE_NAME = 'usp_CBI_1204_ds_Varouvation_Differences_Total')
DROP PROCEDURE usp_CBI_1204_ds_Varouvation_Differences_Total
GO

SET NOCOUNT ON 
SET ANSI_WARNINGS OFF
SET ARITHABORT OFF
GO
CREATE PROCEDURE usp_CBI_1204_ds_Varouvation_Differences_Total
(
	@parStoreNo AS VARCHAR(500),
	@parDateFrom AS DATE,
	@parDateTo AS DATE,
	@MaxMonths AS INT = 15
	
)
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @sql AS NVARCHAR(MAX) = ''



	SET @sql = @sql + '
	IF datediff(MONTH, @parDateFrom, @parDateTo) > @MaxMonths'
	
	SET @sql = @sql + '
	BEGIN 
			SET @parDateFrom = dateadd(MONTH, -@MaxMonths , @parDateTo) 
	END
	'


	SET @sql = @sql + '
	SELECT 
		--CONVERT(VARCHAR(10), sc.StartDate, 20) AS StartDate,
		--CONVERT(VARCHAR(10), sc.ClosedDate, 20) AS ClosedDate,
		sc.StartDate  AS StartDate,
		sc.ClosedDate AS ClosedDate,
		sto.StoreName,
		ssl.StockCountNo,
		sc.StockCountText,    
		ROUND(SUM((ISNULL(CountedDerivedNetCostAmount, CountedNetCostAmount)) - ISNULL(saist.NetPriceDerived, ISNULL(ssl.NetpriceClosedDate,0)) 
							 * ISNULL(Instockqty,0) * ISNULL(arli.LinkQty,1)),0) AS NetCostDif,
		sto.StoreNo
	FROM StockCounts sc
	INNER JOIN StoreStockCountLines ssl ON sc.StockCountNo = ssl.StockCountNo
	LEFT OUTER JOIN ArticleLinks arli ON ssl.ArticleNo = arli.MasterArticleNo
	INNER JOIN STORES sto ON sto.StoreNo = ssl.StoreNo 
	INNER JOIN AllArticles art ON art.Articleno = ISNULL(arli.Articleno,ssl.ArticleNo)
	INNER JOIN StoreArticleInfoStockTypes saist ON saist.Articleno = ISNULL(arli.Articleno,ssl.ArticleNo)
	AND saist.StoreNo = ssl.StoreNo
	WHERE ssl.StoreStockCountLineStatus = 80  
	AND sc.StartDate between  @parDateFrom  AND  @parDateTo
	AND ssl.StoreNo IN (@parStoreNo )
	GROUP BY sc.StartDate, sc.ClosedDate, sto.StoreName, ssl.StockCountNo, sto.StoreNo, sc.StockCountText
	ORDER BY sc.StartDate, sto.StoreName
	'

	--PRINT (@sql)
	EXEC sp_executesql @sql
					   ,N'@parStoreNo nvarchar(100), @parDateFrom nvarchar(30), @parDateTo nvarchar(30), @MaxMonths int'
					   ,@parStoreNo = @parStoreNo
					   ,@parDateFrom = @parDateFrom
					   ,@parDateTo = @parDateTo
					   ,@MaxMonths = @MaxMonths

end




/*

 exec usp_CBI_1204_ds_Varouvation_Differences_Total @parStoreNo = '3000'
													,@parDateFrom = '2018-01-01'
													,@parDateTo = '2018-07-01'
													,@MaxMonths = '15'
												

*/