USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1358StockCountArticlesNotCounted_report]    Script Date: 16.04.2020 10:58:40 ******/
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

	if @ToDate IS NOT NULL 
	begin
		SET @ToDate = DATEADD(HOUR, 23, CAST(CAST(@ToDate AS DATE) AS DATETIME)) 
		set @ToDate = (SELECT DATEADD(minute, 59, @ToDate));
		set @ToDate = (SELECT DATEADD(second, 59, @ToDate));
		set @ToDate = (SELECT DATEADD(millisecond, 998, @ToDate));
	end 

	SELECT 
				ar.ArticleId, 
				ar.articleName, 
				ar.PrimaryEAN, 
				ISNULL(sai.InStockQty,0) AS InStockQty,
				ar.articleStatus,
				sai.LastUpdatedSoldDate
	FROM Articles ar
			JOIN StoreArticleAssortments saa ON ar.ArticleNo = saa.ArticleNo
			JOIN Stores st ON st.StoreNo = saa.StoreNo
			JOIN StoreArticleInfos sai ON sai.articleno = ar.articleno AND sai.storeno = st.storeno	
			LEFT JOIN  StoreStockCountLines sscl ON sscl.ArticleNo = ar.ArticleNo AND sscl.StockCountNo = @StockCountNo
	WHERE st.StoreId = @StoreId AND sscl.StockCountNo IS NULL AND saa.InAssortment IN ( 1,8) 
			AND ( sai.LastUpdatedSoldDate >= @FromDate AND sai.LastUpdatedSoldDate <= @ToDate)
			AND ISNULL(sscl.StoreStockCountLineStatus,0)<>99
	ORDER BY articlename
		
END



GO

