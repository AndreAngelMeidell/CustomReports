USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1186_dsRevenueFiguresReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1186_dsRevenueFiguresReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1186_dsRevenueFiguresReport_data] (
	 @StoreId AS VARCHAR(100)     
	,@DateFrom AS  DATE  
	,@DateTo AS  DATE  
   ,@ReportType SMALLINT -- 0 all flights, 1 departure, 2 arrival--, 3 extra 
	,@FlightNo VARCHAR(max) --list of flight no
	,@AirportCodes VARCHAR(max) --list of arirport codes
	,@Top INTEGER = 50		
	,@ZeroSale AS  INTEGER --0 show all, 1 show only articles not sold in given period 
	,@ArticleSelection AS  VARCHAR(MAX) 
)
AS
BEGIN

SET NOCOUNT ON;

----------------------------------------------------------------------
--Prepare input
----------------------------------------------------------------------

IF RTRIM(LTRIM(@AirportCodes)) = '' SET @AirportCodes = NULL
IF RTRIM(LTRIM(@FlightNo)) = '' SET @FlightNo = NULL

DECLARE @flights TABLE(
FlightNo VARCHAR(MAX))

INSERT INTO @flights
SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@FlightNo,',''')

DECLARE @codes TABLE(
AirportCode VARCHAR(MAX))

INSERT INTO @codes
SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@AirportCodes,',''')

DECLARE @articles TABLE(
ArticleId VARCHAR(MAX))

INSERT INTO @articles
SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@ArticleSelection,',''')


DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer)
DECLARE @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer)


----------------------------------------------------------------------
--Select
----------------------------------------------------------------------
;WITH Sales AS (
SELECT  
SALES.ArticleName,
SALES.ArticleId,
SUPPLIERARTICLE.SupplierArticleId,
SALES.Lev2ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold,
SUM(SALES.Revenue) AS Revenue,
SUM(SALES.GrossProfit) AS GrossProfit
FROM  
(
	SELECT 
		FLOOR(receiptidx/1000) AS ReceiptHeadIdx,
		ds.StoreName, 
		dd.fulldate,  
		CASE transtypevaluetxt4
						WHEN 'D' THEN transtypevaluetxt1 + ' - ' + se.TransTypeValueTxt3 
						WHEN 'A' THEN transtypevaluetxt1 + ' - ' + se.TransTypeValueTxt2	
						ELSE 	transtypevaluetxt1	
				END AS FlightNo,
		CASE 
					WHEN (transtypevaluetxt4 = 'D' OR transtypevaluetxt1 = 'AVN001') THEN 'Avgang' 
					WHEN (transtypevaluetxt4 = 'A' OR transtypevaluetxt1 = 'AVN000') THEN 'Ankomst'
					--WHEN '' THEN 'Ekstra'	
					ELSE 	''	
			END  AS FlightType
	FROM RBIM.Cov_customersalesevent se (NOLOCK)
	JOIN RBIM.Dim_TransType (NOLOCK) tt on tt.TransTypeIdx = Se.TransTypeIdx
	JOIN RBIM.Dim_Date dd (NOLOCK) ON dd.dateidx = se.receiptdateidx
	JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = se.storeidx
	WHERE ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1
	AND tt.transtypeId = 90403									
	AND se.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
	AND (	@ReportType = 0 -- all flights
			OR (@ReportType = 1 AND (se.TransTypeValueTxt4 = 'D' OR se.TransTypeValueTxt1 = 'AVN001')) -- departure flights
			OR (@ReportType = 2 AND (se.TransTypeValueTxt4 = 'A' OR se.TransTypeValueTxt1 = 'AVN000')) -- arrival flights
			--OR (@ReportType = 3 AND se.TransTypeValueTxt4 = '') -- extra flights
	 )
	AND (	@AirportCodes IS NULL  --no filtering on airport codes
			OR (se.TransTypeValueTxt2  IN (SELECT AirportCode FROM @codes)) 
			OR (se.TransTypeValueTxt3  IN (SELECT AirportCode FROM @codes)) 
		 )
	AND (	@FlightNo IS NULL  --no filtering on airport codes
			OR (se.TransTypeValueTxt1  IN (SELECT FlightNo FROM @flights)) 
		 )

) FLIGHT
INNER JOIN 
(
	SELECT 
		FLOOR(f.ReceiptIdx/1000) as ReceiptHeadIdx,
		da.ArticleId,
		da.ArticleName,
		da.Lev2ArticleHierarchyId,
		da.Lev2ArticleHierarchyName,
		--supa.SupplierArticleID AS SupplierArticleId,
		SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		SUM(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
		SUM(f.GrossProfit) AS GrossProfit
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
	JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
	--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
	--LEFT JOIN VBDCM.dbo.Articles art (NOLOCK) ON art.ArticleID = da.ArticleId
	--LEFT JOIN VBDCM.dbo.SupplierOrgs supo ON supo.SupplierId = sup.SupplierId AND supo.SupplierType = sup.SupplierTypeNo
	--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = art.ArticleNo AND supa.SupplierNo = supo.SupplierNo AND supa.PrimarySupplierArticle = 1
	WHERE f.ReceiptDateIdx between @DateFromIdx AND @DateToIdx
	AND ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1								
	GROUP BY FLOOR(f.ReceiptIdx/1000) ,da.Lev2ArticleHierarchyId, da.Lev2ArticleHierarchyName, da.ArticleName, da.ArticleId--, supa.SupplierArticleID
) SALES
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
ON SUPPLIERARTICLE.ArticleID = SALES.ArticleId --AND SUPPLIERARTICLE.SupplierID = SALES.SupplierId

ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
GROUP BY 
SALES.ArticleName, SALES.ArticleId, SALES.Lev2ArticleHierarchyName, SUPPLIERARTICLE.SupplierArticleId
HAVING SUM(Revenue) <> 0

),
LastSold AS (
	SELECT da.ArticleId,
	dd.FullDate,
	f.supplierIdx,
	ROW_NUMBER() OVER (PARTITION BY da.ArticleId ORDER BY f.ReceiptDateIdx DESC) AS rn
FROM RBIM.Dim_Article da  (NOLOCK)
LEFT JOIN RBIM.Agg_SalesAndReturnPerDay f (NOLOCK) ON f.ArticleIdx = da.ArticleIdx
LEFT JOIN RBIM.Dim_Date dd (NOLOCK) ON f.ReceiptDateIdx = dd.DateIdx
LEFT JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE ds.StoreId IS NULL 
	OR (ds.StoreId = @StoreId
		AND ds.IsCurrentStore = 1)	
)
SELECT *
FROM
	(
	SELECT TOP (@Top)
		s.*,
		DATEDIFF(DAY, s.FullDate, GETDATE()) AS DaysSinceLastSold 
	FROM ( 
		-- find articles that have been sold in given period (@zeroSale = 0)
		SELECT 
			s.*,
			ls.FullDate
		FROM Sales s
		LEFT JOIN LastSold ls ON ls.ArticleId = s.ArticleId 
		WHERE 
		ls.rn = 1
		AND @ZeroSale = 0
		--Filter on article selection
		AND (@ArticleSelection IS NULL OR s.ArticleID IN (SELECT ArticleId FROM @articles))

		UNION

		--find articles that have not been sold in given period (@zeroSale = 1)
		SELECT
			da.ArticleName,
			da.ArticleId,
			s.SupplierArticleId,
			da.Lev2ArticleHierarchyName,	
			NULL AS NoOfArticlesSold,
			NULL AS Revenue,
			NULL AS GrossProfit,
			ls.FullDate
		FROM LastSold ls
		LEFT JOIN Sales s ON ls.ArticleId = s.ArticleId
		JOIN RBIM.Dim_Article da ON da.ArticleId = ls.ArticleId
		--LEFT JOIN RBIM.Dim_Supplier dsup ON dsup.SupplierIdx = ls.SupplierIdx
		--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = dsup.SupplierNo   
		WHERE 
		ls.rn = 1
		AND s.ArticleId IS NULL
		AND da.isCurrent = 1
		AND da.ArticleIdx > -1
		AND @ZeroSale = 1
		--Filter on article selection
		AND (@ArticleSelection IS NULL OR ls.ArticleID IN (SELECT ArticleId FROM @articles))
		) s
		ORDER BY s.Revenue desc
	) s
ORDER BY s.Lev2ArticleHierarchyName, s.ArticleName 

END