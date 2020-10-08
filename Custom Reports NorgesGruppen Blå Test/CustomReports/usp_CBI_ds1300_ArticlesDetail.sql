USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1300_ArticlesDetail]    Script Date: 25.09.2020 12:43:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_ds1300_ArticlesDetail] 
	@StoreId AS VARCHAR(50),
	@StockCountNo AS Int
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
--•	Inventory Qty

--•	Inventory value
--Also a sum in the bottom of the report, summarizing the Inventory value of all the articles in the stock count. 
--Information on batch level is not needed, only net value pr article. 
--Andre 20190318

--20190508 Endret til: ,sut.SalesUnitTypeName AS UnitOfMeasureName
--20190508 Endret til: ,ISNULL(ISNULL(sscl.NetPriceDerivedClosedDate, sscl.NetPriceClosedDate),sscl.NetPrice) AS NetPrice
--20190508 Endret til: LEFT JOIN [NGVRSDBITEM01P].RSItemESDb.dbo.SalesUnitTypes AS SUT ON SUT.SalesUnitTypeNo = Item.SalesUnitTypeNo
SET NOCOUNT ON 

SELECT 	
a.ArticleID
,a.ArticleName
,a.PrimaryEAN
,sut.SalesUnitTypeName AS UnitOfMeasureName
,sscl.CountedQty
,ISNULL(ISNULL(sscl.NetPriceDerivedClosedDate, sscl.NetPriceClosedDate),sscl.NetPrice) AS NetPrice
,ISNULL(sscl.CountedDerivedNetCostAmount,sscl.CountedNetCostAmount) AS CountedNetCostAmount
FROM StoreStockCountLines sscl
	INNER JOIN Articles a ON sscl.ArticleNo = a.ArticleNo
	INNER JOIN Stores s ON sscl.StoreNo = s.StoreNo AND s.StoreTypeNo=7
	INNER JOIN ArticleHierarchys ah ON ah.ArticleHierNo = a.ArticleHierNo
	LEFT JOIN StoreArticleInfos sai ON sai.StoreNo = s.StoreNo AND sai.ArticleNo = a.ArticleNo
	LEFT JOIN SupplierArticles sa ON sa.ArticleNo = a.ArticleNo AND sa.supplierno = a.PrimarySupplierNo AND sa.PrimarySupplierArticle = 1 AND sa.SupplierArtStatus = 1
	LEFT JOIN StoreArticleOverrides sao ON sao.ArticleNo = a.ArticleNo AND sao.StoreNo = s.StoreNo
	LEFT JOIN RSItemESDb.dbo.Articles AS Item ON Item.ArticleID = a.ArticleID
	LEFT JOIN RSItemESDb.dbo.SalesUnitTypes AS SUT ON SUT.SalesUnitTypeNo = Item.SalesUnitTypeNo
	WHERE 1=1
	AND sscl.StockCountNo = @StockCountNo
	AND s.StoreId = @StoreId     
	ORDER BY a.ArticleName
END


GO

