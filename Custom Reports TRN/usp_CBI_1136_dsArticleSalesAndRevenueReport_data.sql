USE [BI_Mart]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1136_dsArticleSalesAndRevenueReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueReport_data]
GO

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
--and da.ArticleIdx > -1 			-- needs to be included if you should exclude LADs etc.
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1   
GROUP BY ds.StoreId, da.ArticleId, da.ArticleName, da.Lev1ArticleHierarchyId, da.Lev1ArticleHierarchyName 
HAVING SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	<> 0 					
  
END
