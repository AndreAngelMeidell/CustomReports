USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1183_dsArticlesForDestructionReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1183_dsArticlesForDestructionReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1183_dsArticlesForDestructionReport_data]
(   
    @StoreId AS VARCHAR(100),
	@DateFrom AS DATE, 
	@DateTo AS DATE,
	@ReasonCode VARCHAR(1000) 
) 
AS  
BEGIN

SET NOCOUNT ON  
------------------------------------------------------------------------------------------------------
-- DEBUG
-- DECLARE	@storeId INT = 9998, @dateFrom DATE = '2016-09-01', @dateTo DATE = '2016-12-05', @ReasonCode VARCHAR(100) = '500,501,502'

DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer)
DECLARE @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer)

--IF RTRIM(LTRIM(@ReasonCode)) = '' SET @ReasonCode = NULL

SELECT 
	da.ArticleId, 
	da.ArticleName, 
	da.UnitOfMeasureName, 
	oae.Value_AlcoholPercent AS AlcoholePercentage,
	oae.Value_CustomsTariffNo AS TariffNo,
	SUM(f.AdjustmentQuantity) AS AdjustmentQuantity,
	f.AdjustmentNetCostPrice,
	dr.ReasonName
FROM RBIM.Fact_StockAdjustment f (NOLOCK)
JOIN RBIM.Dim_Article da(NOLOCK)  ON da.articleIdx = f.ArticleIdx
JOIN RBIM.Out_ArticleExtraInfo oae(NOLOCK)  ON oae.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.StoreIdx = f.StoreIdx
JOIN RBIM.Dim_ReasonCode dr (NOLOCK) ON dr.ReasonCodeIdx = f.ReasonCodeIdx
WHERE ds.StoreId = @storeId
AND ds.IsCurrentStore = 1
AND f.AdjustmentDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND dr.ReasonNo IN (SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@ReasonCode,','''))
GROUP BY da.ArticleId, da.ArticleName, da.UnitOfMeasureName, oae.Value_AlcoholPercent, oae.Value_CustomsTariffNo, f.AdjustmentNetCostPrice, dr.ReasonName
ORDER BY dr.ReasonName, da.ArticleName

END