USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1188_dsCampaignProfitabilityReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1188_dsCampaignProfitabilityReport_data]
GO

CREATE  PROCEDURE [dbo].[usp_CBI_1188_dsCampaignProfitabilityReport_data] (
	 @StoreOrGroupNo AS VARCHAR(MAX)     
	,@DateFrom                  AS  DATETIME  
	,@DateTo                    AS  DATETIME  
	,@CampaignIdList as varchar(MAX)
	,@CampaignType INT --1 = CampaignArticlePriceReduction, 0 = CampaignDiscountCombination, 2 = all
)
AS
BEGIN

SET NOCOUNT ON;

IF RTRIM(LTRIM(@CampaignIdList)) = '' SET @CampaignIdList = NULL

DECLARE  @DateFromIdx INTEGER  = cast(convert(char(8), @DateFrom, 112) as integer)
DECLARE  @DateToIdx INTEGER  = cast(convert(char(8), @DateTo, 112) as integer)

----------------------------------------------------------------------
--Find stores
----------------------------------------------------------------------

DECLARE @stores TABLE(
StoreIdx INT,
StoreId VARCHAR(MAX),
StoreName VARCHAR(MAX),
CurrentStoreName VARCHAR(MAX))

INSERT INTO @stores
SELECT DISTINCT ds.StoreIdx, ds.StoreId, ds.StoreName	,(SELECT StoreName FROM RBIM.Dim_Store WHERE ds.StoreId = StoreId AND  IsCurrent = 1)	AS currentStoreName
FROM RBIM.Dim_Store ds (NOLOCK)
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL and ds.IsCurrentStore=1

----------------------------------------------------------------------
--Find campaigns
----------------------------------------------------------------------

DECLARE @CampaignArticleSale TABLE(
StoreName VARCHAR(100),
ArticleName VARCHAR(100),
SupplierArticleID VARCHAR(100),
SalesAmount DECIMAL,
NumberOfArticlesSold INTEGER,
SalesPricePerItem DECIMAL,
NetPurchasePricePerItem DECIMAL,
TypeOfCampaign VARCHAR(50))


;WITH CampaignArticleSale  AS (
SELECT 
	CAMPAIGNS.*, 
	SUPPLIERARTICLE.SupplierArticleID 
FROM 
(
SELECT 
ds.CurrentStoreName AS StoreName,
da.ArticleName, 
da.ArticleId,
--ISNULL(supa.SupplierArticleID,'') AS SupplierArticleID,
CASE c.CampaignIdx WHEN  -1 THEN  NULL  ELSE  c.CampaignId END AS CampaignId, 
CASE  pr.CampaignArticlePriceReductionIdx WHEN  -1 THEN  NULL  ELSE  pr.CampaignId END AS CampaignArticlePriceReductionId , 
CASE  dc.CampaignDiscountCombinationIdx  WHEN  -1 THEN  NULL  ELSE  dc.CampaignId END AS CampaignDiscountCombinationId,
f.SalesAmount,
CASE WHEN f.NumberOfArticlesSold != 0 THEN f.SalesAmount/f.NumberOfArticlesSold ELSE 0 END AS SalesPricePerItem,
CASE WHEN f.NumberOfArticlesSold != 0 THEN f.NetPurchasePrice/f.NumberOfArticlesSold ELSE 0 END AS NetPurchasePricePerItem,
f.NumberOfArticlesSold,
dp.PriceTypeNo, dp.PriceTypeName
FROM RBIM.Agg_CampaignSalesPerHour f
JOIN @stores ds ON  ds.storeidx = f.storeidx
JOIN rbim.Dim_Campaign c ON  c.CampaignIdx = f.CampaignIdx
JOIN rbim.Dim_CampaignArticlePriceReduction pr ON  pr.CampaignArticlePriceReductionIdx = f.CampaignArticlePriceReductionIdx
JOIN rbim.Dim_CampaignDiscountCombination dc ON  dc.CampaignDiscountCombinationIdx = f.CampaignDiscountCombinationIdx
JOIN RBIM.Dim_PriceType dp ON dp.PriceTypeIdx = f.PriceTypeIdx
JOIN RBIM.Dim_Article da ON da.ArticleIdx = f.ArticleIdx
JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
--LEFT JOIN VBDCM.dbo.Articles art (NOLOCK) ON art.ArticleID = da.ArticleId
--LEFT JOIN VBDCM.dbo.SupplierOrgs supo ON supo.SupplierId = sup.SupplierId AND supo.SupplierType = sup.SupplierTypeNo
--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = art.ArticleNo AND supa.SupplierNo = supo.SupplierNo AND supa.PrimarySupplierArticle = 1
WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx			-- inlude only sales within the selected report period
AND (@CampaignIdList IS NULL 
	OR ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId+',%'			-- Include multiple campaigns based on multi select input controller in jasper
	OR  ','+@CampaignIdList+',' LIKE  '%,'+pr.CampaignId+',%'
	OR  ','+@CampaignIdList+',' LIKE  '%,'+dc.CampaignId +',%')
) CAMPAIGNS
LEFT JOIN 
(
SELECT distinct
supa.SupplierArticleID,
art.ArticleID,
supo.SupplierID
FROM VBDCM.dbo.Articles art (NOLOCK) 
LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = art.ArticleNo 
LEFT JOIN VBDCM.dbo.SupplierOrgs supo ON supo.SupplierNo = supa.SupplierNo 
WHERE supa.PrimarySupplierArticle = 1 AND supa.SupplierArtStatus = 1 AND supo.SupplierStatus = 1
) SUPPLIERARTICLE
ON SUPPLIERARTICLE.ArticleID = CAMPAIGNS.ArticleId --AND SUPPLIERARTICLE.SupplierID = SALES.SupplierId
)
INSERT INTO @CampaignArticleSale
SELECT * 
FROM (
	SELECT 
		c.StoreName,
		c.ArticleName,
		c.SupplierArticleID,
		SUM(c.SalesAmount) AS SalesAmount,
		SUM(c.NumberOfArticlesSold) AS NumberOfArticlesSold,
		c.SalesPricePerItem,
		c.NetPurchasePricePerItem,
		CASE WHEN c.PriceTypeNo = 0 
				THEN 'Single'
				ELSE 'MixMatch'
		END AS TypeOfCampaign
	FROM CampaignArticleSale c
	WHERE  @CampaignType IN (0, 2)
	AND (c.CampaignDiscountCombinationId IS NOT NULL 
			OR c.PriceTypeNo = 0)
	GROUP BY CASE WHEN c.PriceTypeNo = 0 THEN 'Single'
				ELSE 'MixMatch'
				END ,
				c.StoreName ,
				c.ArticleName ,
				c.SupplierArticleID ,
				c.NetPurchasePricePerItem,
				c.SalesPricePerItem

	UNION

	SELECT 
		c.StoreName,
		c.ArticleName,
		c.SupplierArticleID,
		SUM(c.SalesAmount) AS SalesAmount,
		SUM(c.NumberOfArticlesSold) AS NumberOfArticlesSold,
		c.SalesPricePerItem,
		c.NetPurchasePricePerItem,
		'Kampanje' AS TypeOfCampaign
	FROM CampaignArticleSale c
	WHERE  @CampaignType IN (1,2)
	AND c.CampaignArticlePriceReductionId IS NOT NULL 
	GROUP BY c.StoreName ,
				c.ArticleName ,
				c.SupplierArticleID ,
				c.NetPurchasePricePerItem,
				c.SalesPricePerItem
	) c


----------------------------------------------------------------------
-- Add a row for single/mixmatch if not exists.
-- Result in report should be SupplierArticleId - Articlename - Mixmatch
----------------------------------------------------------------------

IF @CampaignType in (0,2)
BEGIN
INSERT INTO @CampaignArticleSale
SELECT StoreName, ArticleName,SupplierArticleID , NULL, NULL, NULL, NULL, 'Single' 
FROM @CampaignArticleSale c1
WHERE NOT EXISTS (SELECT c.TypeOfCampaign FROM @CampaignArticleSale c WHERE c.SupplierArticleID = c1.SupplierArticleID AND c. ArticleName = c1.ArticleName AND c.StoreName = c1.StoreName AND c.TypeOfCampaign = 'Single')
AND TypeOfCampaign = 'MixMatch'

INSERT INTO @CampaignArticleSale
SELECT StoreName, ArticleName, SupplierArticleID, NULL, NULL, NULL, NULL, 'MixMatch' 
FROM @CampaignArticleSale c1
WHERE NOT EXISTS (SELECT c.TypeOfCampaign FROM @CampaignArticleSale c WHERE c.SupplierArticleID = c1.SupplierArticleID AND c. ArticleName = c1.ArticleName AND c.StoreName = c1.StoreName AND c.TypeOfCampaign = 'MixMatch')
AND TypeOfCampaign = 'Single'
END 

SELECT * 
FROM @CampaignArticleSale c
ORDER BY c.StoreName, c.SupplierArticleID, c.ArticleName, c.TypeOfCampaign


END

