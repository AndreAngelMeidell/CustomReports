USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1358StockCountArticlesNotCounted_report]    Script Date: 26.05.2020 11:31:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_ds1358StockCountArticlesNotCounted_report] 
	@StoreId AS VARCHAR(50),
	@StockCountNo AS INT,
	@FromDate AS DATETIME,
	@ToDate AS DATETIME 
	--,
	--@IncludeZero BIT --removed from standard
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @typeOfCount AS INT
	SET @typeOfCount = (SELECT TypeOfCount FROM StockCounts WHERE StockCountNo = @StockCountNo )

		IF @ToDate IS NULL or @ToDate=''
	BEGIN
		SET @ToDate = (SELECT ISNULL(sc.ClosedDate,GETDATE()) FROM dbo.StockCounts AS sc WHERE sc.StockCountNo=@StockCountNo)
	END 

	IF @FromDate IS NULL or @FromDate=''
	BEGIN
		--SET @FromDate = (SELECT sc.StartDate FROM dbo.StockCounts AS sc WHERE sc.StockCountNo=@StockCountNo)
		SET @FromDate = getdate()-30
	END

	
	IF @ToDate IS NOT NULL 
	BEGIN
		SET @ToDate = DATEADD(HOUR, 23, CAST(CAST(@ToDate AS DATE) AS DATETIME)) 
		SET @ToDate = (SELECT DATEADD(MINUTE, 59, @ToDate));
		SET @ToDate = (SELECT DATEADD(SECOND, 59, @ToDate));
		SET @ToDate = (SELECT DATEADD(MILLISECOND, 998, @ToDate));
	END 



	SELECT 
				ar.ArticleId, 
				ar.articleName, 
				ar.PrimaryEAN, 
				--SUM(Sold.AdjustmentQty*-1) AS InStockQty,
				0 AS InStockQty,
				ar.articleStatus,
				max(Sold.AdjustmentDate) AS LastUpdatedSoldDate 
	FROM Articles ar
			JOIN StoreArticleAssortments saa ON ar.ArticleNo = saa.ArticleNo
			JOIN Stores st ON st.StoreNo = saa.StoreNo
			JOIN dbo.StockAdjustments AS Sold ON Sold.ArticleNo = ar.ArticleNo AND Sold.ArticleNo = saa.ArticleNo AND Sold.AdjustmentDate BETWEEN @FromDate AND @ToDate AND sold.StockAdjType=1
			LEFT JOIN StoreStockCountLines sscl ON sscl.ArticleNo = ar.ArticleNo AND sscl.StockCountNo = @StockCountNo
	WHERE	st.StoreId = @StoreId 
			AND sscl.StockCountNo IS NULL 
			AND saa.InAssortment IN ( 1,8) 
			AND ISNULL(sscl.StoreStockCountLineStatus,0)<>99
	GROUP BY ar.ArticleId,ar.articleName, ar.PrimaryEAN,ar.articleStatus
	ORDER BY articlename
		
END





GO

