USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1723_Sales_csv]    Script Date: 13.11.2020 08:41:30 ******/
DROP PROCEDURE [dbo].[usp_CBI_1723_Sales_csv]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1723_Sales_csv]    Script Date: 13.11.2020 08:41:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1723_Sales_csv] 
(
@DateFrom AS DATE ,
@DateTo AS DATE 
)
AS
BEGIN
SET NOCOUNT ON

SELECT 
'Sales' AS Description, DD.FullDate, DS.StoreName, DS.StoreId
,DA.ArticleId, DA.ArticleName, DG.Gtin, DA.Lev2ArticleHierarchyId, DA.Lev2ArticleHierarchyName,DA.Lev3ArticleHierarchyId, DA.Lev3ArticleHierarchyName, 
	sum(ASARPD.[NumberOfArticlesSold]-ASARPD.[NumberOfArticlesInReturn]) AS Quantity 
				,sum(ASARPD.[SalesAmount] + ASARPD.[ReturnAmount]) AS SalesRevenueInclVat			
				,sum(ASARPD.[SalesAmountExclVat] + ASARPD.ReturnAmountExclVat ) AS SalesRevenue	
				, sum(ASARPD.[GrossProfit]) AS GrossProfit
				, isnull(nullif(sum(isnull(ASARPD.[SalesPrice],0)+isnull(ASARPD.[ReturnAmount],0)),0)/nullif(sum(isnull(ASARPD.[NumberOfArticlesSold],0)-isnull(ASARPD.[NumberOfArticlesInReturn],0)),0),0) AS [Price] 
				,sum(ASARPD.CostOfGoods) AS CostOfGoods  
				,sum(ASARPD.SalesVatAmount + ASARPD.ReturnAmount - ASARPD.ReturnAmountExclVat)  AS [SalesRevenueVat]
FROM  RBIM.Agg_SalesAndReturnPerDay AS ASARPD
JOIN RBIM.Dim_User AS du ON ASARPD.SystemUserIdx = du.UserIdx
JOIN RBIM.Dim_Date AS DD ON ASARPD.ReceiptDateIdx = dd.DateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
JOIN RBIM.Cov_ArticleGtin AS CAG ON CAG.ArticleIdx = DA.ArticleIdx AND CAG.IsDefaultGtin=1
LEFT JOIN RBIM.Dim_Gtin AS DG ON DG.GtinIdx = CAG.GtinIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_PriceType AS DPT ON DPT.PriceTypeIdx = ASARPD.PriceTypeIdx
LEFT JOIN rbim.Dim_Supplier DSUP(NOLOCK) ON DSUP.SupplierIdx = ASARPD.SupplierIdx
WHERE  dd.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY  DD.FullDate, DS.StoreName, DS.StoreId
,DA.ArticleId, DA.ArticleName, DG.Gtin, DA.Lev2ArticleHierarchyId, DA.Lev2ArticleHierarchyName,DA.Lev3ArticleHierarchyId, DA.Lev3ArticleHierarchyName 
HAVING (sum(ASARPD.[NumberOfArticlesSold]-ASARPD.[NumberOfArticlesInReturn]) >0 AND 
				sum(ASARPD.[SalesAmount] + ASARPD.[ReturnAmount]) >0		AND 	
				sum(ASARPD.[SalesAmountExclVat] + ASARPD.ReturnAmountExclVat) >0 AND 	
				sum(ASARPD.[GrossProfit])   >0 AND 
			  isnull(nullif(sum(isnull(ASARPD.[SalesPrice],0)+isnull(ASARPD.[ReturnAmount],0)),0)/nullif(sum(isnull(ASARPD.[NumberOfArticlesSold],0)-isnull(ASARPD.[NumberOfArticlesInReturn],0)),0),0) >0 AND 
				sum(ASARPD.CostOfGoods) >0 AND  
				sum(ASARPD.SalesVatAmount + ASARPD.ReturnAmount - ASARPD.ReturnAmountExclVat)  >0)
UNION ALL 

SELECT 
'RTC' AS Description, DD.FullDate, DS.StoreName, DS.StoreId
,DA.ArticleId, DA.ArticleName, DG.Gtin, DA.Lev2ArticleHierarchyId, DA.Lev2ArticleHierarchyName,DA.Lev3ArticleHierarchyId, DA.Lev3ArticleHierarchyName, 
	sum(ASARPD.[NumberOfArticlesSold]-ASARPD.[NumberOfArticlesInReturn]) AS Quantity 
				,sum(ASARPD.[SalesAmount] + ASARPD.[ReturnAmount]) AS SalesRevenueInclVat			
				,sum(ASARPD.[SalesAmountExclVat] + ASARPD.ReturnAmountExclVat ) AS SalesRevenue	
				, sum(ASARPD.[GrossProfit]) AS GrossProfit
				, isnull(nullif(sum(isnull(ASARPD.[SalesPrice],0)+isnull(ASARPD.[ReturnAmount],0)),0)/nullif(sum(isnull(ASARPD.[NumberOfArticlesSold],0)-isnull(ASARPD.[NumberOfArticlesInReturn],0)),0),0) AS [Price] 
				,sum(ASARPD.CostOfGoods) AS CostOfGoods  
				,sum(ASARPD.SalesVatAmount + ASARPD.ReturnAmount - ASARPD.ReturnAmountExclVat)  AS [SalesRevenueVat]
FROM  RBIM.Agg_SalesAndReturnPerDay AS ASARPD
JOIN RBIM.Dim_User AS du ON ASARPD.SystemUserIdx = du.UserIdx
JOIN RBIM.Dim_Date AS DD ON ASARPD.ReceiptDateIdx = dd.DateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
JOIN RBIM.Cov_ArticleGtin AS CAG ON CAG.ArticleIdx = DA.ArticleIdx AND CAG.IsDefaultGtin=1
LEFT JOIN RBIM.Dim_Gtin AS DG ON DG.GtinIdx = CAG.GtinIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_PriceType AS DPT ON DPT.PriceTypeIdx = ASARPD.PriceTypeIdx
LEFT JOIN rbim.Dim_Supplier DSUP(NOLOCK) ON DSUP.SupplierIdx = ASARPD.SupplierIdx
WHERE  ASARPD.PriceTypeIdx IN (28, 19)  AND dd.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY  DD.FullDate, DS.StoreName, DS.StoreId
,DA.ArticleId, DA.ArticleName, DG.Gtin, DA.Lev2ArticleHierarchyId, DA.Lev2ArticleHierarchyName,DA.Lev3ArticleHierarchyId, DA.Lev3ArticleHierarchyName 
HAVING (sum(ASARPD.[NumberOfArticlesSold]-ASARPD.[NumberOfArticlesInReturn]) >0 AND 
				sum(ASARPD.[SalesAmount] + ASARPD.[ReturnAmount]) >0		AND 	
				sum(ASARPD.[SalesAmountExclVat] + ASARPD.ReturnAmountExclVat) >0 AND 	
				sum(ASARPD.[GrossProfit])   >0 AND 
			  isnull(nullif(sum(isnull(ASARPD.[SalesPrice],0)+isnull(ASARPD.[ReturnAmount],0)),0)/nullif(sum(isnull(ASARPD.[NumberOfArticlesSold],0)-isnull(ASARPD.[NumberOfArticlesInReturn],0)),0),0) >0 AND 
				sum(ASARPD.CostOfGoods) >0 AND  
				sum(ASARPD.SalesVatAmount + ASARPD.ReturnAmount - ASARPD.ReturnAmountExclVat)  >0)

END 



GO

