USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueReport_data]    Script Date: 11.05.2021 09:00:32 ******/
DROP PROCEDURE [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueReport_data]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueReport_data]    Script Date: 11.05.2021 09:00:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueReport_data]
(   
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@StoreId VARCHAR(100) 
) 
AS  
BEGIN
  
------------------------------------------------------------------------------------------------------

SELECT 
ds.StoreId
,da.ArticleName
,da.ArticleId
,da.Lev1ArticleHierarchyId
,da.Lev1ArticleHierarchyName
,SUM(f.[SalesAmount] + f.[ReturnAmount]) AS RevenueInclVat -- Omsetning
,SUM(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS Revenue --Netto Omsetning
,SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NumberOfArticlesSold -- Antall solgt
FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
JOIN RBIM.Dim_Date dd  (NOLOCK) ON dd.DateIdx = f.ReceiptDateIdx 
JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx 
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE  																																		
dd.FullDate BETWEEN @DateFrom AND @DateTo
AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)
--and da.ArticleIdx > -1 			-- needs to be included if you should exclude LADs etc.
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1   
GROUP BY ds.StoreId, da.ArticleId, da.ArticleName, da.Lev1ArticleHierarchyId, da.Lev1ArticleHierarchyName 
HAVING SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	<> 0 					
  
END

GO

