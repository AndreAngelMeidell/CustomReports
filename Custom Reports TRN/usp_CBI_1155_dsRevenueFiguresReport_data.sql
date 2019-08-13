USE [BI_Mart]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1155_dsRevenueFiguresReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1155_dsRevenueFiguresReport_data]
GO

USE [BI_Mart]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_CBI_1155_dsRevenueFiguresReport_data]
(   
   @StoreId AS VARCHAR(100),
	@PeriodType AS VARCHAR(1), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@YearToDate AS INTEGER, 
	@RelativePeriodType AS VARCHAR(5),
	@RelativePeriodStart AS INTEGER, 
	@RelativePeriodDuration AS INTEGER ,	
   @GtinFrom AS VARCHAR(50),
	@GtinTo AS VARCHAR(50),	
	@ArticleIdFrom AS VARCHAR(50),
	@ArticleIdTo AS VARCHAR(50),
	@BrandIdFrom AS VARCHAR(50),
	@BrandIdTo	AS VARCHAR(50),
	@ArticleHierarchyIdFrom AS VARCHAR(50),
	@ArticleHierarchyIdTo AS VARCHAR(50),
	@GroupBy AS VARCHAR(50) = 'Month', --Month, Week, WeekDay, Supplier, ArticleHierachy, Article, Brand
	@ArticleSelectionId AS VARCHAR(1000) 
	
) 
AS  
BEGIN
  
SET @GtinFrom = CASE WHEN @GtinFrom = '' THEN NULL ELSE @GtinFrom END;
SET @GtinTo = CASE WHEN @GtinTo = '' THEN NULL ELSE @GtinTo END;
SET @ArticleIdFrom = CASE WHEN @ArticleIdFrom = '' THEN NULL ELSE @ArticleIdFrom END;
SET @ArticleIdTo = CASE WHEN @ArticleIdTo = '' THEN NULL ELSE @ArticleIdTo END;

------------------------------------------------------------------------------------------------------

;WITH ArticlesInSelection AS 
(
SELECT cas.ArticleIdx
FROM RBIM.Dim_ArticleSelection das
LEFT JOIN RBIM.Cov_ArticleSelection cas ON cas.ArticleSelectionIdx = das.ArticleSelectionIdx
WHERE das.ArticleSelectionId = @ArticleSelectionId
)
,SelectedSales AS (
SELECT 

 dd.[YearMonthNumber]
,dd.[YearWeekNumber]
,dsup.[SupplierName]
,da.[Lev1ArticleHierarchyName]
,da.[Lev1ArticleHierarchyId]
,da.[BrandId]
,da.[BrandName]
,da.[ArticleName]
,da.[ArticleId]
,ISNULL(g.Gtin, '') AS Gtin
,dd.FullDate
,(f.[QuantityOfArticlesSold] - f.QuantityOfArticlesInReturn) AS Quantity -- Antall
,(f.[SalesAmount] + f.[ReturnAmount]) AS RevenueAmountInclVat -- Omsetning
,(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS Revenue --Netto Omsetning
,(f.NetPurchasePriceDerived + f.NetPurchasePrice) AS [PurchaseAmount]-- Innverdi
from BI_Mart.RBIM.Agg_SalesAndReturnPerDay f (NOLOCK) 
join rbim.Dim_Date dd (NOLOCK) ON dd.DateIdx = f.ReceiptDateIdx 
join rbim.Dim_Article da (NOLOCK)on da.ArticleIdx = f.ArticleIdx 
join rbim.Dim_Store ds (NOLOCK) on ds.storeidx = f.storeidx
JOIN rbim.Dim_Supplier dsup (NOLOCK) ON dsup.SupplierIdx = f.SupplierIdx
--LEFT JOIN rbim.Cov_ArticleGtin cag ON cag.ArticleIdx = da.ArticleIdx
LEFT JOIN RBIM.Dim_Gtin g (NOLOCK) ON g.GtinIdx = f.gtinIdx

Where 
	--ISNULL(cag.IsDefaultGtin,1) = 1
--AND ISNULL(g.isCurrent, 1) = 1
-- filter on store
@StoreId = ds.StoreId
--  filter on period
and (
	(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
	or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
	or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	)
--  filter on period
--and da.ArticleIdx > -1 			-- needs to be included if you should exclude LADs etc.
and ds.isCurrentStore = 1   	-- make sure you only get the 'current store' 
								-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
and g.Gtin
	>= CAST(CASE WHEN @GtinFrom IS NULL THEN g.Gtin ELSE @GtinFrom END AS BIGINT)				
and g.Gtin 
	<= CAST(CASE WHEN @GtinTo IS NULL THEN g.Gtin ELSE @GtinTo END AS BIGINT)	

and da.ArticleId
	>= CAST(CASE WHEN @ArticleIdFrom IS NULL THEN da.ArticleId ELSE @ArticleIdFrom END AS INT)				
and da.ArticleId 
	<= CAST(CASE WHEN @ArticleIdTo IS NULL THEN da.ArticleId ELSE @ArticleIdTo END AS INT)		

and da.BrandId
	>= CAST(CASE WHEN @BrandIdFrom IS NULL THEN da.BrandId ELSE @BrandIdFrom END AS INT)				
and da.BrandId 
	<= CAST(CASE WHEN @BrandIdTo IS NULL THEN da.BrandId ELSE @BrandIdTo END AS INT)	
			
and da.Lev2ArticleHierarchyId
	>= CAST(CASE WHEN @ArticleHierarchyIdFrom IS NULL THEN da.Lev2ArticleHierarchyId ELSE @ArticleHierarchyIdFrom END AS INT)				
and da.Lev2ArticleHierarchyId 
	<= CAST(CASE WHEN @ArticleHierarchyIdTo IS NULL THEN da.Lev2ArticleHierarchyId ELSE @ArticleHierarchyIdTo END AS INT)	
AND (@ArticleSelectionId IS NULL OR da.ArticleIdx IN (SELECT * FROM ArticlesInSelection))				
)
---------------------------------------------------------
(
SELECT 
	ArticleName AS GroupedBy
	,NULL AS GroupedBy2
	,CONVERT(VARCHAR(50),Gtin) AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	WHERE @GroupBy = 'Article'
	GROUP BY ArticleName, Gtin
) 
UNION 
(
SELECT 
	NULL AS GroupedBy
	,FullDate AS GroupedBy2
	, '' AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	WHERE @GroupBy = 'WeekDay'
	GROUP BY FullDate
)
UNION
(
SELECT 
	CASE @GroupBy 
			WHEN 'Supplier' THEN SupplierName
			WHEN 'ArticleHierarchy' THEN Lev1ArticleHierarchyName
			WHEN 'Month' THEN CONVERT(VARCHAR(10),yearMonthNumber)
			WHEN 'Week' THEN CONVERT(VARCHAR(10),yearWeekNumber)
			WHEN 'Brand' THEN BrandName
	END AS GroupedBy
	,NULL AS GroupedBy2
	,''  AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	WHERE @GroupBy IN ('Supplier', 'ArticleHierarchy','Month','Week', 'Brand')
	GROUP BY CASE @GroupBy 
			WHEN 'Supplier' THEN SupplierName
			WHEN 'ArticleHierarchy' THEN Lev1ArticleHierarchyName
			WHEN 'Month' THEN CONVERT(VARCHAR(10),yearMonthNumber)
			WHEN 'Week' THEN CONVERT(VARCHAR(10),yearWeekNumber)
			WHEN 'Brand' THEN BrandName
	END
)
ORDER BY GroupedBy, GroupedBy2






-------------------------------------------------------------------------------------------------------
END



