USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1300_ArticlesDetail_subreport]    Script Date: 16.02.2021 11:12:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE     PROCEDURE [dbo].[usp_CBI_ds1300_ArticlesDetail_subreport] 
	@StoreId AS VARCHAR(50),
	@StockCountNo AS int
	

AS
BEGIN

--History	
--Follow up Jira: HKRS-1959 - New report in "Varetelling": information pr article
--NG need a report that can report on item line level which can again be exported in excel. This will simplify the work internally in the profile houses. 
--Report requirement:
--For a given stock count, create a report that will show pr article, for all the articles in the stock count: 
--•	ArticleID
--•	Article name
--•	Primary GTIN
--•	SalesUnitType (Piece/KG) missig pr 20190318
--•	Inventory Q ty

--•	Inventory value
--Also a sum in the bottom of the report, summarizing the Inventory value of all the articles in the stock count. 
--Information on batch level is not needed, only net value pr article. 
--Andre 20190318

--20190508 Endret til: ,SUT.SalesUnitTypeName AS UnitOfMeasureName
--20190508 Endret til: ,ISNULL(ISNULL(sscl.NetPriceDerivedClosedDate, sscl.NetPriceClosedDate),sscl.NetPrice) AS NetPrice
--20190508 Endret til: LEFT JOIN [NGVRSDBITEM01P].RSItemESDb.dbo.SalesUnitTypes AS SUT ON SUT.SalesUnitTypeNo = Item.SalesUnitTypeNo
SET NOCOUNT ON 

SELECT oae.* 
INTO #ArticleExtraInfo
from NGVRSDBDWHST01P.BI_Mart.RBIM.Out_ArticleExtraInfo oae

SELECT da.* 
INTO #DimArticle
from NGVRSDBDWHST01P.BI_Mart.RBIM.Dim_Article da
WHERE da.isCurrent=1

SELECT 	a.ArticleId
,da2.Lev1ArticleHierarchyId
,da2.Lev2ArticleHierarchyId
,da2.Lev3ArticleHierarchyId
,da2.Lev4ArticleHierarchyId
,da2.Lev5ArticleHierarchyId
,aei.Value_Department
,a.PrimaryEAN
,sscl1.StockCountNo
,SUT.SalesUnitTypeNo AS UnitOfMeasureNo
,sum(sscl1.CountedQty) as CountedQty
,sum(ISNULL(ISNULL(sscl1.NetPriceDerivedClosedDate, sscl1.NetPriceClosedDate),sscl1.NetPrice)) AS NetPrice
,sum(ISNULL(sscl1.CountedDerivedNetCostAmount,sscl1.CountedNetCostAmount)) AS CountedNetCostAmount
INTO #LastCount
FROM StoreStockCountLines sscl1 WITH (NOLOCK)
	INNER JOIN Articles (nolock) a ON sscl1.ArticleNo = a.ArticleNo
	INNER JOIN Stores (nolock) s ON sscl1.StoreNo = s.StoreNo AND s.StoreTypeNo=7
	INNER JOIN ArticleHierarchys (nolock) ah ON ah.ArticleHierNo = a.ArticleHierNo
	LEFT JOIN StoreArticleInfos (nolock) sai ON sai.StoreNo = s.StoreNo AND sai.ArticleNo = a.ArticleNo
	LEFT JOIN SupplierArticles (nolock) sa ON sa.ArticleNo = a.ArticleNo AND sa.supplierno = a.PrimarySupplierNo AND sa.PrimarySupplierArticle = 1 AND sa.SupplierArtStatus = 1
	LEFT JOIN StoreArticleOverrides (nolock) sao ON sao.ArticleNo = a.ArticleNo AND sao.StoreNo = s.StoreNo
	LEFT JOIN RSItemESDb.dbo.Articles (nolock) AS Item ON Item.ArticleID = a.ArticleID
	LEFT JOIN RSItemESDb.dbo.SalesUnitTypes (nolock) AS SUT ON SUT.SalesUnitTypeNo = Item.SalesUnitTypeNo
	LEFT JOIN #DimArticle (nolock) da2 ON a.ArticleID = da2.ArticleId
	left join #ArticleExtraInfo  (nolock) aei   on aei.ArticleId = da2.ArticleId   -- {RS-37338}
	WHERE 1=1
	AND sscl1.CountedQty <> 0
	AND s.StoreId = @StoreId
 AND sscl1.StockCountNo IN  (SELECT  max(sscl12.StockCountNo)  FROM StoreStockCountLines sscl12
WHERE sscl12.StockCountNo < @StockCountNo)  
	GROUP BY a.ArticleId
,da2.Lev1ArticleHierarchyId
,da2.Lev2ArticleHierarchyId
,da2.Lev3ArticleHierarchyId
,da2.Lev4ArticleHierarchyId
,da2.Lev5ArticleHierarchyId
,aei.Value_Department , SUT.SalesUnitTypeNo, a.PrimaryEAN ,sscl1.StockCountNo



SELECT 	
a.ArticleId, a.ArticleName
,da2.Lev1ArticleHierarchyId, da2.Lev1ArticleHierarchyName
,da2.Lev2ArticleHierarchyId, da2.Lev2ArticleHierarchyName
,da2.Lev3ArticleHierarchyId, da2.Lev3ArticleHierarchyName
,da2.Lev4ArticleHierarchyId, da2.Lev4ArticleHierarchyName
,da2.Lev5ArticleHierarchyId, da2.Lev5ArticleHierarchyName
,aei.Value_Department, aei.Value_DepartmentName
,a.PrimaryEAN
,SUT.SalesUnitTypeName AS UnitOfMeasureName
,isnull(sum(sscl.CountedQty),0) as CountedQty
,sum(ISNULL(ISNULL(sscl.NetPriceDerivedClosedDate, sscl.NetPriceClosedDate),sscl.NetPrice)) AS NetPrice
,sum(ISNULL(sscl.CountedDerivedNetCostAmount,sscl.CountedNetCostAmount)) AS CountedNetCostAmount
,round(isnull(isnull(sum(sscl.CountedQty),0)/nullif(isnull(sum(lc.CountedQty),0),0),0),2) as CountedQtyPercentage
,round(isnull(sum(ISNULL(ISNULL(sscl.NetPriceDerivedClosedDate, sscl.NetPriceClosedDate),sscl.NetPrice))/nullif(isnull(sum(lc.NetPrice),0),0),0),2) AS NetPricePercentage
,round(isnull(sum(ISNULL(sscl.CountedDerivedNetCostAmount,sscl.CountedNetCostAmount))/nullif(isnull(sum(lc.CountedNetCostAmount),0),0),0),2) AS  CountedNetCostAmountPercentage
FROM StoreStockCountLines sscl WITH (NOLOCK)
	INNER JOIN Articles (nolock) a ON sscl.ArticleNo = a.ArticleNo
	INNER JOIN Stores (nolock) s ON sscl.StoreNo = s.StoreNo AND s.StoreTypeNo=7
	INNER JOIN ArticleHierarchys (nolock) ah ON ah.ArticleHierNo = a.ArticleHierNo
	LEFT JOIN StoreArticleInfos (nolock) sai ON sai.StoreNo = s.StoreNo AND sai.ArticleNo = a.ArticleNo
	LEFT JOIN SupplierArticles (nolock) sa ON sa.ArticleNo = a.ArticleNo AND sa.supplierno = a.PrimarySupplierNo AND sa.PrimarySupplierArticle = 1 AND sa.SupplierArtStatus = 1
	LEFT JOIN StoreArticleOverrides (nolock) sao ON sao.ArticleNo = a.ArticleNo AND sao.StoreNo = s.StoreNo
	LEFT JOIN RSItemESDb.dbo.Articles (nolock) AS Item ON Item.ArticleID = a.ArticleID
	LEFT JOIN RSItemESDb.dbo.SalesUnitTypes (nolock) AS SUT ON SUT.SalesUnitTypeNo = Item.SalesUnitTypeNo
	LEFT JOIN #DimArticle (nolock) da2 ON a.ArticleID = da2.ArticleId
	left join #ArticleExtraInfo  (nolock) aei   on aei.ArticleId = da2.ArticleId   -- {RS-37338}
	LEFT join #LastCount (nolock) lc on a.ArticleId = lc.ArticleId and a.PrimaryEAN = lc.PrimaryEAN and SUT.SalesUnitTypeNo =lc.UnitOfMeasureNo 
	WHERE 1=1
	AND sscl.StockCountNo = @StockCountNo
  AND s.StoreId = @StoreId
  AND sscl.CountedQty <>0
	GROUP BY  a.ArticleId, a.ArticleName
,da2.Lev1ArticleHierarchyId, da2.Lev1ArticleHierarchyName
,da2.Lev2ArticleHierarchyId, da2.Lev2ArticleHierarchyName
,da2.Lev3ArticleHierarchyId, da2.Lev3ArticleHierarchyName
,da2.Lev4ArticleHierarchyId, da2.Lev4ArticleHierarchyName
,da2.Lev5ArticleHierarchyId, da2.Lev5ArticleHierarchyName
,aei.Value_Department, aei.Value_DepartmentName, SUT.SalesUnitTypeName, a.PrimaryEAN 



	DROP TABLE IF EXISTS #ArticleExtraInfo
		DROP TABLE IF EXISTS #DimArticle
		DROP TABLE IF EXISTS #LastCount

END


GO

