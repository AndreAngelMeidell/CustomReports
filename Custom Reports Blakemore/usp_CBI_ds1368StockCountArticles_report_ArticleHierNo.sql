USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1368StockCountArticles_report_ArticleHierNo]    Script Date: 21.09.2020 09:36:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_ds1368StockCountArticles_report_ArticleHierNo]
	@StoreId AS VARCHAR(50),
	@StockCountNo AS INT,
	@ExcludeNoChanges BIT
AS
BEGIN
    SET NOCOUNT ON 

	-- Chaged by Andre Meidell 201901101 due to issue VD-2579
	--[AFBS-VRSSQL-DWH] for UAT
	--[AFB-VRSSQL-DWH0] for Prod
	--[AFBS-VRSSQL-DWH] new for UAT 20200921
	--[AFBS-VRSSQL-R2] for Stage (Retail Ops) 20200921

	SELECT
		Lev3ArticleHierarchyDisplayId AS ArticleHierNo,
		Lev3ArticleHierarchyName AS ArticleHierName,
		InStockQty,
		CountedQty,
		CountedQty - InStockQty AS DiffQty,
		InStockNetCostAmount,
		CountedNetCostAmount,
		CountedNetCostAmount - InStockNetCostAmount AS DiffNetCostAmount
	FROM
	(
		SELECT	
			da.Lev3ArticleHierarchyDisplayId,
			da.Lev3ArticleHierarchyName,
			ROUND(SUM(ISNULL(sscl.InStockQty, 0) * ISNULL(al.LinkQty, 1)),3) AS InStockQty,
			ROUND(SUM(ISNULL(sscl.CountedQty, 0) * ISNULL(al.LinkQty, 1)),3) AS CountedQty,			
			ROUND(SUM(COALESCE(saist.NetPriceDerived, sscl.NetpriceClosedDate, 0) * ISNULL(sscl.InStockQty, 0) * ISNULL(al.LinkQty, 1)),2) AS InStockNetCostAmount,
			ROUND(SUM(ISNULL(sscl.CountedDerivedNetCostAmount, sscl.CountedNetCostAmount)),2) AS CountedNetCostAmount
		FROM StoreStockCountLines sscl
		LEFT JOIN ArticleLinks al ON al.MasterArticleNo = sscl.ArticleNo
		LEFT JOIN StoreArticleInfoStockTypes saist ON saist.ArticleNo = ISNULL(al.ArticleNo, sscl.ArticleNo) AND saist.StoreNo = sscl.StoreNo AND saist.StockTypeNo = 1
		INNER JOIN Stores s ON sscl.StoreNo = s.StoreNo
		INNER JOIN AllArticles aa ON aa.ArticleNo = ISNULL(al.ArticleNo, sscl.ArticleNo)
				INNER JOIN [AFBS-VRSSQL-R2].BI_Mart.RBIM.Dim_Article AS da ON da.ArticleId = aa.ArticleID AND da.isCurrent=1
		WHERE			
			sscl.StockCountNo = @StockCountNo AND
			aa.ArticleTypeNo <> 120 AND
			sscl.StoreStockCountLineStatus = 80 AND
			s.StoreId = @StoreId
		GROUP BY  da.Lev3ArticleHierarchyDisplayId,da.Lev3ArticleHierarchyName
	) t
	WHERE (@ExcludeNoChanges = 1 AND (InStockQty <> CountedQty)) OR @ExcludeNoChanges = 0 --RS-37499 Skip lines with 0 in stock or count
END




GO

