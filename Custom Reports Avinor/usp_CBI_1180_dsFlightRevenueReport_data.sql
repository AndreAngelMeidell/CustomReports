USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1180_dsFlightRevenueReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1180_dsFlightRevenueReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1180_dsFlightRevenueReport_data]
(   
   @StoreId AS VARCHAR(100),
	@DateFrom AS DATE, 
	@DateTo AS DATE,
	@ReportType SMALLINT, -- 0 all flights, 1 departure, 2 arrival, 3 extra
	@FlightNo VARCHAR(max), --list of flight no
	@AirportCodes VARCHAR(max),
	@GroupByFlight SMALLINT -- 1 group by flights, 0 sum all flights
) 
AS  
BEGIN

SET NOCOUNT ON  
------------------------------------------------------------------------------------------------------
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

DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer)
DECLARE @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer)

select 
CASE @GroupByFlight
	WHEN 1 THEN FLIGHT.FlightNo
	ELSE NULL
END AS FlightNo, 
CASE @GroupByFlight
	WHEN 1 THEN FLIGHT.FlightType
	ELSE NULL
END AS FlightType, 
ArticleName,
SupplierArticleId,
SUM(NoOfArticlesSold) as NoOfArticlesSold,
SUM(Revenue) as Revenue,
SUM(NoOfCustomers) as NoOfCustomers

from 
(
SELECT 
	FLOOR(receiptidx/1000) AS ReceiptHeadIdx,
	ds.StoreName, 
	dd.fulldate, 
	dt.hourperiod, 
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
JOIN RBIM.Dim_time dt (NOLOCK) ON dt.timeidx = se.receipttimeidx
JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = se.storeidx
AND tt.transtypeId = 90403								
AND se.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
AND ds.StoreId = @StoreId
AND ds.IsCurrentStore = 1
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
INNER  JOIN 
(
SELECT 
	FLOOR(f.ReceiptIdx/1000) as ReceiptHeadIdx,
	da.articleName,
	da.ArticleId,
	sup.supplierId,
	--supa.SupplierArticleID AS SupplierArticleId,
	SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
	SUM(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
	SUM(f.NumberOfCustomers) AS NoOfCustomers
FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
----LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
--LEFT JOIN VBDCM.dbo.Articles art (NOLOCK) ON art.ArticleID = da.ArticleId
--LEFT JOIN VBDCM.dbo.SupplierOrgs supo ON supo.SupplierId = sup.SupplierId AND supo.SupplierType = sup.SupplierTypeNo
--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = art.ArticleNo AND supa.SupplierNo = supo.SupplierNo AND supa.PrimarySupplierArticle = 1
WHERE f.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
AND ds.StoreId = @StoreId				
AND ds.IsCurrentStore = 1	
--AND da.ArticleIdx <> -1				
GROUP BY f.ReceiptTimeIdx,FLOOR(f.ReceiptIdx/1000) ,da.ArticleName, sup.SupplierId, da.ArticleId--, supa.SupplierArticleID
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
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

GROUP BY 
CASE @GroupByFlight
	WHEN 1 THEN FLIGHT.FlightNo
	ELSE NULL
END,
CASE @GroupByFlight
	WHEN 1 THEN FLIGHT.FlightType
	ELSE NULL
END,
SALES.ArticleName, SUPPLIERARTICLE.SupplierArticleId
ORDER BY FlightType, FlightNo, SALES.ArticleName

END