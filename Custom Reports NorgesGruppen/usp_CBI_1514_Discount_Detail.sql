USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1514_Discount_Detail]    Script Date: 03.05.2018 13:30:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1514_Discount_Detail] (@StoreId AS VARCHAR(100),
@PeriodType AS CHAR(1) = 'D',
@DateFrom AS DATETIME ,--= '2017-01-01'
@DateTo AS DATETIME ,--= '2017-01-01'
@YearToDate AS INTEGER = NULL,
@RelativePeriodType AS CHAR(5) = NULL,
@RelativePeriodStart AS INTEGER = NULL,
@RelativePeriodDuration AS INTEGER = NULL,
@SupplierId AS VARCHAR(100) = NULL,
@ArticleGroupId AS VARCHAR(100) = NULL,
@ArticleSelectionId AS VARCHAR(1000) = NULL, 
@GtinFrom AS VARCHAR(50) = NULL,
@GtinTo AS VARCHAR(50) = NULL,
@GrossProfitPercFrom DECIMAL(19,5) = NULL,
@GrossProfitPercTo DECIMAL(19,5) = NULL,
@0163_ArticleGroup VARCHAR(MAX) = NULL,
@OrderBy AS VARCHAR(50), --'TopQuantity','TopNetSales','TopGrossProfit', 'LowGrossProfit', 'TopShrinkageQty', 'TopShrinkagePercentage', 'TopShrinkageAmount'
@Top INTEGER = NULL,
@GroupBy VARCHAR(50) = 'Lev2ArticleHierarchyId'
)
AS
BEGIN
SET NOCOUNT ON

  SET @Top = ISNULL(@Top,10000);
  SET @0163_ArticleGroup = NULLIF(@0163_ArticleGroup,'');
  SET @SupplierId = NULLIF(@SupplierId,'');

  
--IF @GroupBy = 'Lev2ArticleHierarchyId'

--BEGIN

-- Rabatt oversikt alle nedprisede varer

SELECT TOP 1000 dd.MonthName
,DS.GlobalLocationNo, DS.StoreName
,dg.Gtin, DA.ArticleName
,SUM(ASARPD.NumberOfArticlesSold) AS NumberOfArticlesSold
,SUM(ASARPD.SalesPrice) AS NormalSalesPrice
,SUM(ASARPD.SalesAmount) AS SalesAmount
,SUM(ASARPD.DiscountAmount) AS DiscountAmount
, SUM(((((ASARPD.NumberOfArticlesSold*ASARPD.SalesAmount)-(ASARPD.NumberOfArticlesSold*ASARPD.SalesPrice))/(ASARPD.NumberOfArticlesSold*ASARPD.SalesPrice))*100)*-1) AS TotalDiscountPRC
FROM  RBIM.Agg_SalesAndReturnPerDay AS ASARPD
JOIN RBIM.Dim_Date AS DD ON ASARPD.ReceiptDateIdx = dd.DateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
JOIN RBIM.Cov_ArticleGtin AS CAG ON CAG.ArticleIdx = DA.ArticleIdx AND CAG.IsDefaultGtin=1
LEFT JOIN RBIM.Dim_Gtin AS DG ON DG.GtinIdx = CAG.GtinIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_PriceType AS DPT ON DPT.PriceTypeIdx = ASARPD.PriceTypeIdx
LEFT JOIN rbim.Dim_Supplier DSUP(NOLOCK) ON DSUP.SupplierIdx = ASARPD.SupplierIdx
WHERE 1=1
AND ISNULL(ASARPD.DiscountAmount,0)>0 AND ASARPD.SalesPrice>0
AND  @StoreId = ds.StoreId
AND (ASARPD.NumberOfArticlesSold - ASARPD.NumberOfArticlesInReturn) <> 0	-- eller denne?
AND dd.FullDate BETWEEN @DateFrom AND @DateTo
--AND ((@ArticleGroupId = 'Lev2ArticleHierarchyId' AND da.Lev2ArticleHierarchyId != '') OR (@ArticleGroupId = 'Lev3ArticleHierarchyId' AND da.Lev3ArticleHierarchyId != ''))
--Filter on ArticleHierarchy
AND (@0163_ArticleGroup IS NULL OR (@0163_ArticleGroup IS NOT NULL AND ((@ArticleGroupId = 'Lev2ArticleHierarchyId' 
AND da.Lev2ArticleHierarchyId IN (SELECT ParameterValue FROM [BI_Mart].[dbo].[ufn_RBI_SplittParameterString](@0163_ArticleGroup,',')))OR(@ArticleGroupId = 'Lev3ArticleHierarchyId' AND da.Lev3ArticleHierarchyId IN (SELECT ParameterValue FROM [BI_Mart].[dbo].[ufn_RBI_SplittParameterString] (@0163_ArticleGroup,','))))))
--Filter on Supplier
AND (@SupplierId IS NULL OR (@SupplierId IS NOT NULL AND dsup.SupplierName IN (SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@SupplierId,','))))  
--Filter on GTIN
--AND (@GtinFrom IS NULL OR CAST(ISNULL(dg.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) AND (@GtinTo IS NULL OR CAST(ISNULL(dg.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))		
--Filter on ArticleSelection
AND (@ArticleSelectionId IS NULL OR da.ArticleId IN (SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@ArticleSelectionId,','))) 
GROUP BY dd.MonthName,DS.GlobalLocationNo, DS.StoreName,DA.ArticleName,dg.Gtin
ORDER BY dd.MonthName,DS.GlobalLocationNo, DS.StoreName,DA.ArticleName,dg.Gtin

--END

END 



GO


