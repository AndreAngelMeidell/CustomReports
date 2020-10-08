USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1514_Discount_Main]    Script Date: 25.09.2020 12:23:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 
 
 
 
CREATE PROCEDURE [dbo].[usp_CBI_1514_Discount_Main] (@StoreId AS VARCHAR(100),
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
 
-- Nøkkeltall med Avgitte rabatter
 
SELECT TOP 10000
dd.MonthName, DS.StoreName, ASARPD.CashRegisterNo, DCR.CashRegisterName
,SUM(ASARPD.SalesAmount) AS SalesAmount
,SUM(ASARPD.ReturnAmount) AS ReturnAmount
,SUM(ASARPD.NumberOfCustomers) AS NumberOfCustomers
,SUM(ASARPD.NumberOfCustomersPerSelectedArticle)AS NumberOfCustomersPerSelectedArticle
,SUM(ASARPD.SalesAmount) / SUM(ASARPD.NumberOfCustomersPerSelectedArticle) AS AvgSoldPrCustomer
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('15') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS LineDiscount
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('26') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS TenderDiscount
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('27') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS StackedCampaignDiscount
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('24') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS Mixmatch
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('19') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS Downpricing
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('25') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS WinsuperCampaign
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('16') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS ReceiptDiscount
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('20') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS TypicalNorwegianDiscount
,SUM(CASE WHEN DPT.PriceTypeIdx IN ('20','16','25','19','24','27','26','15') THEN ASARPD.DiscountAmount ELSE 0.00 END) AS TotalDiscount
FROM  RBIM.Agg_SalesAndReturnPerDay AS ASARPD(NOLOCK)
JOIN RBIM.Dim_CashRegister AS DCR(NOLOCK) ON dcr.CashRegisterIdx = ASARPD.CashRegisterNo
JOIN RBIM.Dim_Date AS DD(NOLOCK) ON ASARPD.ReceiptDateIdx = dd.DateIdx
JOIN RBIM.Dim_Article AS DA(NOLOCK) ON DA.ArticleIdx = ASARPD.ArticleIdx
JOIN RBIM.Dim_Store AS DS(NOLOCK) ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_PriceType AS DPT(NOLOCK) ON DPT.PriceTypeIdx = ASARPD.PriceTypeIdx
LEFT JOIN rbim.Dim_Supplier DSUP(NOLOCK) ON DSUP.SupplierIdx = ASARPD.SupplierIdx
WHERE 1=1
AND  @StoreId = ds.StoreId AND ds.isCurrentStore = 1
--AND ISNULL(ASARPD.DiscountAmount,0)>0 AND ASARPD.SalesPrice>0               -- denne
AND (ASARPD.NumberOfArticlesSold - ASARPD.NumberOfArticlesInReturn) <> 0  -- eller denne?
AND dd.FullDate BETWEEN @DateFrom AND @DateTo
--AND DD.MonthName='desember' AND DS.StoreName='Meny Tolvsrød'
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
GROUP BY dd.MonthName,DS.StoreName, ASARPD.CashRegisterNo, DCR.CashRegisterName
ORDER BY dd.MonthName,DS.StoreName, ASARPD.CashRegisterNo, DCR.CashRegisterName
   
--END
 
END
 
 
 

GO

