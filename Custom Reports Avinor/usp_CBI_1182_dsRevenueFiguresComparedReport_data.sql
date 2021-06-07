USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1182_dsRevenueFiguresComparedReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1182_dsRevenueFiguresComparedReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1182_dsRevenueFiguresComparedReport_data] 
(
	 @StoreOrGroupNo AS VARCHAR(MAX)     
	,@DateFrom                  AS  DATETIME  
	,@DateTo                    AS  DATETIME  
   ,@DateFromPeriod2           AS  DATETIME  
	,@SupplierArticleId			 AS VARCHAR(1000) 
	,@Comparing                 AS  INTEGER
	,@SumBy						 AS  VARCHAR(1000) --store, article
	,@ArticleSelection AS  VARCHAR(MAX) 
	,@CampaignIdList as varchar(MAX)
)
AS
BEGIN


IF RTRIM(LTRIM(@SupplierArticleId)) = '' SET @SupplierArticleId = NULL
IF RTRIM(LTRIM(@ArticleSelection)) = '' SET @ArticleSelection = NULL
IF RTRIM(LTRIM(@CampaignIdList)) = '' SET @CampaignIdList = NULL

DECLARE @articles TABLE(
ArticleId VARCHAR(MAX))

INSERT INTO @articles
SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@ArticleSelection,',''')

DECLARE  @DateFromIdx INTEGER  = cast(convert(char(8), @DateFrom, 112) as integer)
DECLARE  @DateToIdx INTEGER  = cast(convert(char(8), @DateTo, 112) as integer)

----------------------------------------------------------------------
--Find stores
----------------------------------------------------------------------

DECLARE @stores TABLE(
StoreIdx INT,
StoreId VARCHAR(MAX),
StoreName VARCHAR(MAX),
LastStoreName VARCHAR(MAX))

INSERT INTO @stores
SELECT DISTINCT ds.StoreIdx, ds.StoreId, ds.StoreName, (SELECT StoreName FROM RBIM.Dim_Store  WHERE StoreId = ds.storeId AND isCurrent = 1) AS LastStoreName
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
CampaignId1 VARCHAR(20), -- Dim_Campaign
CampaignId2 VARCHAR(20), -- Dim_CampaignArticlePriceReduction
CampaignId3 VARCHAR(20), -- Dim_CampaignDiscountCombination
ArticleIdx INT,
StoreIdx INT,
ReceiptdateIdx INT
)


INSERT INTO @CampaignArticleSale 
SELECT DISTINCT 
CASE c.CampaignIdx WHEN  -1 THEN  NULL  ELSE  c.CampaignId END , 
CASE  pr.CampaignArticlePriceReductionIdx WHEN  -1 THEN  NULL  ELSE  pr.CampaignId END , 
CASE  dc.CampaignDiscountCombinationIdx  WHEN  -1 THEN  NULL  ELSE  dc.CampaignId END ,
f.ArticleIdx,
ds.StoreIdx,
f.ReceiptDateIdx
FROM RBIM.Agg_CampaignSalesPerHour f
JOIN @stores ds ON  ds.storeidx = f.storeidx
JOIN rbim.Dim_Campaign c ON  c.CampaignIdx = f.CampaignIdx
JOIN rbim.Dim_CampaignArticlePriceReduction pr ON  pr.CampaignArticlePriceReductionIdx = f.CampaignArticlePriceReductionIdx
JOIN rbim.Dim_CampaignDiscountCombination dc ON  dc.CampaignDiscountCombinationIdx = f.CampaignDiscountCombinationIdx
WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx			-- inlude only sales within the selected report period
AND  (f.CampaignDiscountCombinationIdx > -1 
		OR f.CampaignArticlePriceReductionIdx > -1 
		OR f.CampaignIdx > -1)	-- include only campaign articles


----------------------------------------------------------------------
--Only Period1 selected and we do not want to compare. 
--For  Period2 messures we will have 0's and will not appear in report
----------------------------------------------------------------------
IF @Comparing = 0 
BEGIN 

SELECT 
	ds.LastStoreName AS StoreName
	,CASE @SumBy
		WHEN 'Store' THEN NULL
		WHEN 'Article' THEN supa.SupplierArticleID
		ELSE NULL
	END AS SupplierArticleID
	,CASE @SumBy
		WHEN 'Store' THEN NULL
		WHEN 'Article' THEN da.ArticleName
		ELSE NULL
	END AS ArticleName
	,SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat) AS RevenuePeriod1
	,NULL AS RevenuePeriod2
	,SUM(f.QuantityOfArticlesSold+f.QuantityOfArticlesInReturn) AS NumOfArticlesSoldPeriod1
	,NULL AS NumOfArticlesSoldPeriod2
FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
JOIN @stores ds on ds.storeidx = f.storeidx
JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
JOIN RBIM.Dim_Date dd (NOLOCK) ON dd.DateIdx = f.ReceiptDateIdx
JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
LEFT JOIN VBDCM.dbo.Articles art (NOLOCK) ON art.ArticleID = da.ArticleId
LEFT JOIN VBDCM.dbo.SupplierOrgs supo ON supo.SupplierId = sup.SupplierId AND supo.SupplierType = sup.SupplierTypeNo
LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = art.ArticleNo AND supa.SupplierNo = supo.SupplierNo AND supa.PrimarySupplierArticle = 1
LEFT JOIN @CampaignArticleSale c ON c.ArticleIdx = da.ArticleIdx AND c.StoreIdx = ds.StoreIdx AND c.ReceiptdateIdx = f.ReceiptDateIdx 
WHERE dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ((@SupplierArticleId IS NULL) 
				OR (@SupplierArticleId IS NOT NULL AND supa.SupplierArticleID = @SupplierArticleId))
AND --Filter on article selection
   (@ArticleSelection IS NULL OR da.ArticleID IN (SELECT ArticleId FROM @articles))
AND  (@CampaignIdList IS NULL 
	OR ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId1+',%'			-- Include multiple campaigns based on multi select input controller in jasper
	OR  ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId2+',%'
	OR  ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId3+',%')
GROUP BY ds.LastStoreName, 
	CASE @SumBy
		WHEN 'Store' THEN NULL
		WHEN 'Article' THEN supa.SupplierArticleID
		ELSE NULL
	END,
	CASE @SumBy
			WHEN 'Store' THEN NULL
			WHEN 'Article' THEN da.ArticleName
			ELSE NULL
	END
	HAVING SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat) <> 0
	ORDER BY ds.LastStoreName, ArticleName

RETURN  
END 

----------------------------------------------------------------------
--Both Period1 and Period2 selected and we want to compare. 
----------------------------------------------------------------------

-----------------------------------------------------------------
--Date from should be recalculated in case
--we selected period type Y or R
--because we need to know DateFrom  for that period
--to compare it with another period
----------------------------------------------------------------
SET @DateFrom = (SELECT TOP 1 FullDate 
             FROM RBIM.Dim_Date AS dd
             WHERE  dd.FullDate = @DateFrom 
			  )
----------------------------------------------------------------------
--Calculate DateToPeriod2. Period 2 should have same length as period 1.
--
DECLARE @DateToPeriod2 DATETIME
DECLARE @Datediff INT
SET @Datediff  = DATEDIFF(DAY, @DateFrom, @DateTo)
SET @DateToPeriod2 = DATEADD(DAY, @Datediff, @DateFromPeriod2)
--PRINT @DateFromPeriod2 PRINT @DateToPeriod2

SELECT 
	   sub.StoreName
	,CASE @SumBy
		WHEN 'Store' THEN NULL
		WHEN 'Article' THEN sub.SupplierArticleID
		ELSE NULL
	END AS SupplierArticleID
	,CASE @SumBy
		WHEN 'Store' THEN NULL
		WHEN 'Article' THEN sub.ArticleName
		ELSE NULL
	END AS ArticleName
		,sum(sub.RevenuePeriod1)			AS RevenuePeriod1
		,sum(sub.RevenuePeriod2)			AS RevenuePeriod2
		,sum(sub.NumOfArticlesSoldPeriod1)		AS NumOfArticlesSoldPeriod1
		,sum(sub.NumOfArticlesSoldPeriod2)		AS NumOfArticlesSoldPeriod2
FROM 
(
    --------------------------------------------------------------------
	--Data for Period 1
	--------------------------------------------------------------------
	SELECT 
		ds.LastStoreName AS StoreName
		,supa.SupplierArticleID 
		,da.ArticleName 
		,SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat) AS RevenuePeriod1
		,0 AS RevenuePeriod2
		,SUM(f.QuantityOfArticlesSold+f.QuantityOfArticlesInReturn) AS NumOfArticlesSoldPeriod1
		,0 AS NumOfArticlesSoldPeriod2
	FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
	JOIN @stores ds on ds.storeidx = f.storeidx
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	JOIN RBIM.Dim_Date dd (NOLOCK) ON dd.DateIdx = f.ReceiptDateIdx
	JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
	--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
	LEFT JOIN VBDCM.dbo.Articles art (NOLOCK) ON art.ArticleID = da.ArticleId
	LEFT JOIN VBDCM.dbo.SupplierOrgs supo ON supo.SupplierId = sup.SupplierId AND supo.SupplierType = sup.SupplierTypeNo
	LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = art.ArticleNo AND supa.SupplierNo = supo.SupplierNo AND supa.PrimarySupplierArticle = 1
	LEFT JOIN @CampaignArticleSale c ON c.ArticleIdx = da.ArticleIdx AND c.StoreIdx = ds.StoreIdx AND c.ReceiptdateIdx = f.ReceiptDateIdx 
	WHERE dd.FullDate BETWEEN @DateFrom AND @DateTo
	AND ((@SupplierArticleId IS NULL) 
				OR (@SupplierArticleId IS NOT NULL AND supa.SupplierArticleID = @SupplierArticleId))
	--Filter on article selection
   AND (@ArticleSelection IS NULL OR da.ArticleID IN (SELECT ArticleId FROM @articles))
	AND  (@CampaignIdList IS NULL 
		OR ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId1+',%'			-- Include multiple campaigns based on multi select input controller in jasper
		OR  ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId2+',%'
		OR  ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId3+',%')
	GROUP BY ds.LastStoreName, supa.SupplierArticleID, da.ArticleName
    
	UNION
	
	--------------------------------------------------------------------
	--Data for Period 2
	--------------------------------------------------------------------
	SELECT 
		ds.LastStoreName AS StoreName
		,supa.SupplierArticleID 
		,da.ArticleName 		
		,0 AS RevenuePeriod1
		,SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat) AS RevenuePeriod2
		,0 AS NumOfArticlesSoldPeriod1	
		,SUM(f.QuantityOfArticlesSold+f.QuantityOfArticlesInReturn) AS NumOfArticlesSoldPeriod2
	FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
	JOIN @stores ds on ds.storeidx = f.storeidx
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	JOIN RBIM.Dim_Date dd (NOLOCK) ON dd.DateIdx = f.ReceiptDateIdx
	JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
	--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
	LEFT JOIN VBDCM.dbo.Articles art (NOLOCK) ON art.ArticleID = da.ArticleId
	LEFT JOIN VBDCM.dbo.SupplierOrgs supo ON supo.SupplierId = sup.SupplierId AND supo.SupplierType = sup.SupplierTypeNo
	LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = art.ArticleNo AND supa.SupplierNo = supo.SupplierNo AND supa.PrimarySupplierArticle = 1
	LEFT JOIN @CampaignArticleSale c ON c.ArticleIdx = da.ArticleIdx AND c.StoreIdx = ds.StoreIdx AND c.ReceiptdateIdx = f.ReceiptDateIdx 
	WHERE dd.FullDate BETWEEN @DateFromPeriod2 AND @DateToPeriod2
		AND ((@SupplierArticleId IS NULL) 
				OR (@SupplierArticleId IS NOT NULL AND supa.SupplierArticleID = @SupplierArticleId))
		--Filter on article selection
   AND (@ArticleSelection IS NULL OR da.ArticleID IN (SELECT ArticleId FROM @articles))
	AND  (@CampaignIdList IS NULL 
		OR ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId1+',%'			-- Include multiple campaigns based on multi select input controller in jasper
		OR  ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId2+',%'
		OR  ','+@CampaignIdList+',' LIKE  '%,'+c.CampaignId3+',%')
	GROUP BY ds.LastStoreName, supa.SupplierArticleID, da.ArticleName

	) AS sub
    GROUP BY  sub.StoreName, 
		CASE @SumBy
			WHEN 'Store' THEN NULL
			WHEN 'Article' THEN sub.SupplierArticleID 
			ELSE NULL
		END,
		CASE @SumBy
				WHEN 'Store' THEN NULL
				WHEN 'Article' THEN sub.ArticleName
				ELSE NULL
		END
		HAVING sum(sub.RevenuePeriod1) <> 0 OR sum(sub.RevenuePeriod2) <> 0 
		ORDER BY sub.StoreName, ArticleName
		

END

