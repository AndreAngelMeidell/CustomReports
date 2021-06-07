USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1368StockCountArticles_report]    Script Date: 05.11.2020 19:25:20 ******/
DROP PROCEDURE [dbo].[usp_CBI_ds1368StockCountArticles_report]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1368StockCountArticles_report]    Script Date: 05.11.2020 19:25:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[usp_CBI_ds1368StockCountArticles_report]
	@StoreId AS VARCHAR(50),
	@StockCountNo AS INT,
	@ExcludeNoChanges BIT
AS
BEGIN
    SET NOCOUNT ON 

	-- Chaged by Andre Meidell 201901101 due to issue VD-2579
	--[AFBS-VRSSQL-DWH] for UAT
	--[AFB-VRSSQL-DWH0] for Prod

	--[AFB-VRSSQL-DWH0] changed to AFBS-VRSSQL-DWH

	SELECT
		Lev3ArticleHierarchyDisplayId AS ArticleHierNo,
		Lev3ArticleHierarchyName AS ArticleHierName,
		ArticleId,
		ArticleName,
		Ean,
		UnitCost,
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
			aa.ArticleId,
			aa.ArticleName,
			aa.EANNo AS Ean,
			MAX(ISNULL(sscl.NetPrice,aap.PurchasePrice)) AS UnitCost,
			ROUND(SUM(ISNULL(sscl.InStockQty, 0) * ISNULL(al.LinkQty, 1)),3) AS InStockQty,
			ROUND(SUM(ISNULL(sscl.CountedQty, 0) * ISNULL(al.LinkQty, 1)),3) AS CountedQty,			
			ROUND(SUM(COALESCE(aap.PurchasePrice,saist.NetPriceDerived, sscl.NetpriceClosedDate, 0) * ISNULL(sscl.InStockQty, 0) * ISNULL(al.LinkQty, 1)),2) AS InStockNetCostAmount,
			ROUND(SUM(ISNULL(ISNULL(sscl.CountedDerivedNetCostAmount,aap.PurchasePrice), sscl.CountedNetCostAmount)),2) AS CountedNetCostAmount
		FROM StoreStockCountLines sscl
		LEFT JOIN ArticleLinks al ON al.MasterArticleNo = sscl.ArticleNo
		LEFT JOIN StoreArticleInfoStockTypes saist ON saist.ArticleNo = ISNULL(al.ArticleNo, sscl.ArticleNo) AND saist.StoreNo = sscl.StoreNo AND saist.StockTypeNo = 1
		LEFT JOIN ActivePurchasePrices AAP ON AAP.ArticleNo = sscl.ArticleNo AND AAP.StoreNo = sscl.StoreNo
		INNER JOIN Stores s ON sscl.StoreNo = s.StoreNo
		INNER JOIN AllArticles aa ON aa.ArticleNo = ISNULL(al.ArticleNo, sscl.ArticleNo)
		INNER JOIN [AFBS-VRSSQL-DWH].BI_Mart.RBIM.Dim_Article AS da ON da.ArticleId = aa.ArticleID AND da.isCurrent=1
		WHERE			
			sscl.StockCountNo = @StockCountNo AND
			aa.ArticleTypeNo <> 120 AND
			sscl.StoreStockCountLineStatus = 80 AND
			s.StoreId = @StoreId
		GROUP BY  da.Lev3ArticleHierarchyDisplayId,da.Lev3ArticleHierarchyName,aa.ArticleId, aa.ArticleName, aa.EANNo
	) t
	WHERE (@ExcludeNoChanges = 1 AND (InStockQty <> CountedQty)) OR @ExcludeNoChanges = 0 --RS-37499 Skip lines with 0 in stock or count
END



GO

