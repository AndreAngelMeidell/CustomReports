USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1184_dsShrinkageAndRedundacyReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1184_dsShrinkageAndRedundacyReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1184_dsShrinkageAndRedundacyReport_data]
(   
 @StoreId AS VARCHAR(100),
	@DateFrom AS DATE, 
	@DateTo AS DATE,
	@ReportType VARCHAR(1000)  -- 0 begge , 1 svinn, 2 overtallighet
) 
AS  
BEGIN

SET NOCOUNT ON  
------------------------------------------------------------------------------------------------------
-- DEBUG
-- DECLARE	@storeId INT = 9998, @dateFrom DATE = '2016-09-01', @dateTo DATE = '2016-12-05', @ReasonCode VARCHAR(100) = '500,501,502'

DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer)
DECLARE @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer)


;WITH Adjustments AS (
SELECT 
	f.AdjustmentDate,
	da.ArticleName,
	da.ArticleId,
	CASE WHEN da.Lev1ArticleHierarchyId = '' THEN NULL ELSE da.Lev1ArticleHierarchyId END AS Lev1ArticleHierarchyId, 
	CASE WHEN da.Lev1ArticleHierarchyName = '' THEN NULL ELSE da.Lev1ArticleHierarchyName END AS Lev1ArticleHierarchyName, 
	CASE WHEN da.Lev2ArticleHierarchyId = '' THEN NULL ELSE da.Lev2ArticleHierarchyId END AS Lev2ArticleHierarchyId, 
	CASE WHEN da.Lev2ArticleHierarchyName = '' THEN NULL ELSE da.Lev2ArticleHierarchyName END AS Lev2ArticleHierarchyName,  
	oae.Value_AlcoholPercent AS AlcoholPercentage,
	oae.Value_CustomsTariffNo AS TariffNo,
	da.UnitOfMeasurementAmount,
	da.UnitOfMeasureName,
	CASE WHEN sat.StockAdjustmentTypeNo = 52 THEN f.AdjustmentQuantity*f.AdjustmentSign  ELSE 0 END AS DifferenceQuantity,
	CASE WHEN sat.StockAdjustmentTypeNo = 51 THEN f.AdjustmentQuantity*f.AdjustmentSign ELSE 0 END AS CountedQuantity,
	f.AdjustmentNetCostPrice
FROM RBIM.Fact_StockAdjustment f (NOLOCK)
JOIN RBIM.Dim_Article da (NOLOCK)  ON da.articleIdx = f.ArticleIdx
JOIN RBIM.Out_ArticleExtraInfo oae (NOLOCK)  ON oae.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.StoreIdx = f.StoreIdx
JOIN RBIM.Dim_StockAdjustmentType sat (NOLOCK) ON sat.StockAdjustmentTypeIdx = f.StockAdjustmentTypeIdx
WHERE ds.StoreId = @storeId
AND ds.IsCurrentStore = 1
AND f.AdjustmentDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND (sat.StockAdjustmentTypeNo = 52 --Differance between what has been counted in stock count and what is in stock
		OR sat.StockAdjustmentTypeNo = 51) --Stock quantity is overridden by this value
),
AdjustmentDate AS (
SELECT 
	ArticleId, 
	MAX(AdjustmentDate) AS MaxDate,
	min(AdjustmentDate) AS MinDate
	FROM Adjustments
	GROUP BY ArticleId
),
AdjustmentInfo AS (
SELECT
	a.ArticleName,
	a.ArticleId,
	COALESCE(a.Lev2ArticleHierarchyId, a.Lev1ArticleHierarchyId) AS ArticleHierarchyId,
	COALESCE(a.Lev2ArticleHierarchyName, a.Lev1ArticleHierarchyName) AS ArticleHierarchyName,
	a.AlcoholPercentage,
	a.TariffNo,
	a.UnitOfMeasurementAmount,
	a.UnitOfMeasureName, 
	CASE WHEN a.AdjustmentDate = ad.MaxDate THEN a.CountedQuantity ELSE 0 END AS CountedQty,
	CASE WHEN a.AdjustmentDate = ad.MinDate THEN a.CountedQuantity-a.DifferenceQuantity ELSE 0 END AS InStockQty,
	a.DifferenceQuantity,
	a.AdjustmentNetCostPrice
FROM Adjustments a
JOIN AdjustmentDate ad ON ad.ArticleId = a.ArticleId
),
AdjustmentSum AS (
SELECT
	a.ArticleName,
	a.ArticleId,
	a.ArticleHierarchyId,
	a.ArticleHierarchyName,
	CAST(a.AlcoholPercentage AS INT) AS AlcoholPercentage,
	a.TariffNo,
	a.UnitOfMeasurementAmount,
	a.UnitOfMeasureName, 
	SUM(a.CountedQty) AS CountedQty,
	SUM(a.CountedQty-a.DifferenceQuantity) AS InStockQty,
	SUM(a.DifferenceQuantity) AS DifferenceQty,
	a.AdjustmentNetCostPrice
FROM AdjustmentInfo a
GROUP BY a.ArticleName, a.ArticleId,a.ArticleHierarchyId, a.ArticleHierarchyName, 
			a.AlcoholPercentage, a.TariffNo, a.UnitOfMeasurementAmount, a.UnitOfMeasureName, a.AdjustmentNetCostPrice	
)
SELECT * 
FROM AdjustmentSum a
WHERE  
(@ReportType = 1 AND a.DifferenceQty < 0) 
OR (@ReportType = 2 AND a.DifferenceQty > 0) 
OR @ReportType = 0
ORDER BY a.ArticleName

 
END