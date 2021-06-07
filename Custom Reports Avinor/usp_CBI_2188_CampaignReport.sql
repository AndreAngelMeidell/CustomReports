USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2188_CampaignReport]    Script Date: 06.09.2019 13:39:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE  PROCEDURE [dbo].[usp_CBI_2188_CampaignReport] (
	 @DateFrom                  AS  DATETIME  
	,@DateTo                    AS  DATETIME  
	,@CampaignIdList AS VARCHAR(MAX)
	,@CampaignType INT			-- 1 = CampaignArticlePriceReduction, 0 = CampaignDiscountCombination, 2 = all
	,@ReportType AS SMALLINT	-- 0 all flights, 1 departure, 2 arrival, 3 extra
)
AS
BEGIN

SET NOCOUNT ON;

IF RTRIM(LTRIM(@CampaignIdList)) = '' SET @CampaignIdList = NULL

DECLARE  @DateFromIdx INTEGER  = cast(convert(char(8), @DateFrom, 112) as integer)
DECLARE  @DateToIdx INTEGER  = CAST(CONVERT(CHAR(8), @DateTo, 112) AS INTEGER)


-- 20190220 legger til LEFT JOIN RBIM.Out_ArticleExtraInfo AS OAEI ON OAEI.ArticleId = da.ArticleId AND OAEI.Name_ArticleReceiptText2='Bongtekst 2'
-- 20190731 legger til dc.CampaignDiscountCombinationName for å se type discoutCamp comb.
-- 20190906 This proc is no longer in use, report 1288 uses proc 1288
----------------------------------------------------------------------
--Find campaigns
----------------------------------------------------------------------


SELECT 
isnull(OAEI.Value_ArticleReceiptText2,'missing info') AS ArticleId,
dc.CampaignDiscountCombinationName,
da.ArticleName, 
SUM(CASE WHEN ds.StoreId='1100' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Haugesund',
SUM(CASE WHEN ds.StoreId='1200' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Alesund_Avgang', 
SUM(CASE WHEN ds.StoreId='1210' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Alesund_Ankomst', 
SUM(CASE WHEN ds.StoreId='1250' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Alesund_TVS',
SUM(CASE WHEN ds.StoreId='1300' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Molde',
SUM(CASE WHEN ds.StoreId='1400' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Bodo_Duty_Free',
SUM(CASE WHEN ds.StoreId='1450' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Bodo_Travel_Value',
SUM(CASE WHEN ds.StoreId='1500' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Evenes_Harstad_Narvik',
SUM(CASE WHEN ds.StoreId='1600' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Tromso_Duty_Free',
SUM(CASE WHEN ds.StoreId='1650' THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Tromso_Travel_Value',
SUM(CASE WHEN ds.StoreId IN ('1100','1200','1210','1250','1300','1400','1450','1500','1600','1650') THEN f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn ELSE 0 END) AS 'Totalt'
FROM RBIM.Fact_ReceiptRowSalesAndReturn f
JOIN RBIM.Dim_Date AS DD ON f.ReceiptDateIdx=dd.DateIdx
JOIN RBIM.Dim_Store ds ON  ds.storeidx = f.storeidx
LEFT JOIN rbim.Dim_CampaignArticlePriceReduction pr ON  pr.CampaignArticlePriceReductionIdx = f.CampaignArticlePriceReductionIdx
LEFT JOIN rbim.Dim_CampaignDiscountCombination dc ON  dc.CampaignDiscountCombinationIdx = f.CampaignDiscountCombinationIdx
LEFT JOIN rbim.Dim_Campaign c ON  c.CampaignIdx = f.CampaignIdx
JOIN RBIM.Dim_PriceType dp ON dp.PriceTypeIdx = f.PriceTypeIdx
JOIN RBIM.Dim_Article da ON da.ArticleIdx = f.ArticleIdx
LEFT JOIN RBIM.Out_ArticleExtraInfo AS OAEI ON OAEI.ArticleId = da.ArticleId AND OAEI.Name_ArticleReceiptText2='Bongtekst 2'
JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
LEFT JOIN RBIM.Cov_CustomerFlightInfo AS SE ON SE.ReceiptHeadIdx = f.ReceiptHeadIdx 
WHERE 1=1
--AND dc.CampaignDiscountCombinationName<>'N/A'
AND f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx			-- inlude only sales within the selected report period
--AND dc.CampaignDiscountCombinationIdx>0
--new for FlightType
AND		(	@ReportType = 0														-- all flights
		OR (@ReportType = 1 AND se.OriginCode = 'D' )							-- departure flights
		OR (@ReportType = 2 AND se.OriginCode = 'A')							-- arrival flights
		OR (@ReportType = 3 AND (se.OriginCode = '' OR se.OriginCode IS NULL))	-- extra flights
		)
AND (@CampaignIdList IS NULL 
	OR ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId+',%'			-- Include multiple campaigns based on multi select input controller in jasper
	OR  ','+@CampaignIdList+',' LIKE  '%,'+pr.CampaignId+',%'
	OR  ','+@CampaignIdList+',' LIKE  '%,'+dc.CampaignId +',%')
GROUP BY OAEI.Value_ArticleReceiptText2, da.ArticleName, dc.CampaignDiscountCombinationName
HAVING SUM(f.QuantityOfArticlesSold)>0
ORDER BY dc.CampaignDiscountCombinationName, da.ArticleName



END




GO

