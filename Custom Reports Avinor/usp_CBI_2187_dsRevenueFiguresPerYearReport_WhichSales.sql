USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2187_dsRevenueFiguresPerYearReport_WhichSales]    Script Date: 06.01.2020 13:56:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






/*DECLARE @StoreOrGroupNo AS VARCHAR(MAX) = 9998    
	,@DateFrom AS  DATE = '2017-01-01' 
	,@DateTo AS  DATE  = '2017-01-31'
   ,@ReportType SMALLINT =0-- 0 all flights, 1 departure, 2 arrival--, 3 extra 
	,@FlightNo VARCHAR(max) --list of flight no
	,@AirportCodes VARCHAR(max) --list of arirport codes	
	,@ArticleSelection AS  VARCHAR(MAX) 
	*/
CREATE  PROCEDURE [dbo].[usp_CBI_2187_dsRevenueFiguresPerYearReport_WhichSales] (
	 @StoreOrGroupNo AS VARCHAR(MAX)    
	,@DateFrom AS  DATE  
	,@DateTo AS  DATE  
    ,@ReportType SMALLINT -- 0 all flights, 1 departure, 2 arrival--, 3 extra 
	,@FlightNo VARCHAR(MAX) --list of flight no
	,@AirportCodes VARCHAR(MAX) --list of arirport codes	
	,@ArticleSelection AS  VARCHAR(MAX) 
	,@WhichSales SMALLINT	-- 0 all sales, 1 Pick And Collect, 2 all sales except Pick And Collect
)
AS
BEGIN

SET NOCOUNT ON;

----------------------------------------------------------------------
--Prepare input
----------------------------------------------------------------------

IF RTRIM(LTRIM(@AirportCodes)) = '' SET @AirportCodes = NULL
IF RTRIM(LTRIM(@FlightNo)) = '' SET @FlightNo = NULL
IF RTRIM(LTRIM(@ArticleSelection)) = '' SET @ArticleSelection = NULL

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

--------

DECLARE @ThisYear INT = (SELECT Year FROM RBIM.Dim_Date WHERE FullDate = @DateFrom)

DECLARE @DateFromIdx INT = cast(convert(varchar(8),@DateFrom, 112) as integer)
DECLARE @DateToIdx INT = cast(convert(varchar(8),@DateTo, 112) as integer)
DECLARE @DateFromIdxStartThisYear INT = (SELECT MIN(DateIdx) FROM RBIM.Dim_Date WHERE Year = @ThisYear)

DECLARE @DateFromIdxLastYear INT = (SELECT DateIdx FROM RBIM.Dim_Date WHERE MonthNumberOfYear = SUBSTRING(convert(varchar(10),@DateFromIdx), 5,2) AND DayNumberOfMonth = RIGHT(@DateFromIdx, 2) AND Year = @ThisYear-1)
DECLARE @DateToIdxLastYear INT = (SELECT DateIdx FROM RBIM.Dim_Date WHERE MonthNumberOfYear = SUBSTRING(convert(varchar(10),@DateToIdx), 5,2) AND DayNumberOfMonth = RIGHT(@DateToIdx, 2) AND Year = @ThisYear-1)
DECLARE @DateFromIdxStartLastYear INT = (SELECT MIN(DateIdx) FROM RBIM.Dim_Date WHERE Year = @ThisYear-1)


----------------------------------------------------------------------
--Find stores
----------------------------------------------------------------------

DECLARE @stores TABLE(
StoreIdx INT,
StoreId VARCHAR(MAX),
StoreName VARCHAR(MAX))

INSERT INTO @stores
SELECT DISTINCT ds.StoreIdx, ds.StoreId, ds.StoreName
FROM RBIM.Dim_Store ds (NOLOCK)
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL --AND ds.isCurrent=1 -- ds.IsCurrentStore=1 OLD


IF ( @WhichSales = 0 )		-- 0 = Alt salg dvs inkluder P&C orginal spøring
BEGIN


----------------------------------------------------------------------
--Select
----------------------------------------------------------------------
;WITH flightReceipts AS (
	SELECT   DISTINCT A.ReceiptHeadIdx,ReceiptDateIdx, A.FlightNo, A.FlightType, A.OriginCode FROM
		(SELECT 
			se.ReceiptHeadIdx,
			se.ReceiptDateIdx,
			se.FlightNo,
			--CASE se.OriginCode
			--				WHEN 'D' THEN se.FlightNo + ' - ' + (CASE WHEN OriginCode = 'A' THEN LocalAirport WHEN OriginCode = 'D' THEN ConnectedAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END) 
			--				WHEN 'A' THEN se.FlightNo + ' - ' + (CASE WHEN OriginCode = 'A' THEN ConnectedAirport WHEN OriginCode = 'D' THEN LocalAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END)	
			--				ELSE 	FlightNo	
			--		END AS FlightNo,
			CASE  
							WHEN TRIM(se.OriginCode)  = 'D' THEN 'Departure' 
							WHEN TRIM(se.OriginCode)  = 'A' THEN 'Arrival'
							WHEN TRIM(se.OriginCode)  = ''  THEN 'Other'	
							WHEN  se.OriginCode IS NULL     THEN 'Other'	
							ELSE 	''	
					END  AS FlightType
					,se.OriginCode
					,se.ConnectedAirport
					,se.LocalAirport
		FROM
			RBIM.Cov_CustomerFlightInfo se (NOLOCK) 
		WHERE  se.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S)
		AND se.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
			OR se.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
			OR se.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
			OR se.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear
		)A
		WHERE 

			 (	@ReportType = 0 -- all flights
					OR (@ReportType = 1 AND A.OriginCode = 'D') -- departure flights
					OR (@ReportType = 2 AND A.OriginCode = 'A') -- arrival flights
					OR (@ReportType = 3 AND (A.OriginCode = '' OR A.OriginCode IS NULL)) -- extra flights
				)
			AND (	@AirportCodes IS NULL	--no filtering on all airport codes
					OR EXISTS(SELECT AirportCode FROM @codes WHERE AirportCode = (CASE WHEN OriginCode = 'A' THEN ConnectedAirport WHEN OriginCode = 'D' THEN LocalAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END) OR AirportCode = (CASE WHEN OriginCode = 'A' THEN LocalAirport WHEN OriginCode = 'D' THEN ConnectedAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END)) 
				)
			AND (	@FlightNo IS NULL		--no filtering on all flight 
					OR EXISTS(SELECT FlightNo FROM @flights WHERE FlightNo=A.FlightNo) 
				)
),







SalesReceipts AS (
SELECT 
		--FLOOR(f.ReceiptIdx/1000) AS ReceiptHeadIdx,
		f.ReceiptHeadIdx,
		f.ReceiptId,
		f.ReceiptDateIdx,
		da.ArticleId,
		da.ArticleName,
		da.Lev1ArticleHierarchyId,
		da.Lev1ArticleHierarchyName,
		(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
		f.NumberOfCustomers AS NoOfCustomers
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	--JOIN @stores ds  ON ds.storeidx = f.storeidx
	WHERE f.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S) 
	AND (f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear)
	--AND (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) <> 0 
	--AND (f.SalesAmountExclVat+f.ReturnAmountExclVat) <> 0
	--AND (f.SalesRevenue<>0 OR f.ReturnAmountExclVat<>0 OR f.NumberOfCustomers<>0 OR f.QuantityOfArticlesSold<>0 OR f.QuantityOfArticlesInReturn<>0)
), 

SalesInPeriod AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold,
SUM(SALES.Revenue) AS Revenue,
SUM(SALES.NoOfCustomers) AS NoOfCustomers
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx	
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx							
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
),

salesInPeriodLastYear AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYear,
SUM(SALES.Revenue) AS Revenue_lastYear,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYear
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
) 
, salesYtd AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_ytd,
SUM(SALES.Revenue) AS Revenue_ytd,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_ytd
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
)
, SalesLastYTD AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYTD,
SUM(SALES.Revenue) AS Revenue_lastYTD,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYTD
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
)

,Totals AS (
SELECT 
NULL AS Lev1ArticleHierarchyName
, SUM(NoOfCustomers)  AS NoOfCustomers
, SUM(NoOfCustomers_YTD)  AS NoOfCustomers_YTD
, SUM(NoOfCustomers_lastYear) AS NoOfCustomers_lastYear
, SUM(NoOfCustomers_lastYTD) AS NoOfCustomers_lastYTD
, SUM(Revenue) AS Revenue
, SUM(Revenue_YTD) AS Revenue_YTD
, SUM(Revenue_lastYear) AS Revenue_lastYear
, SUM(Revenue_lastYTD) AS Revenue_lastYTD
, CAST(SUM(NoOfArticlesSold) AS DECIMAL) AS NoOfArticlesSold
, CAST(SUM(NoOfArticlesSold_YTD) AS DECIMAL) AS NoOfArticlesSold_YTD
, CAST(SUM(NoOfArticlesSold_lastYear) AS DECIMAL) AS NoOfArticlesSold_lastYear
, CAST(SUM(NoOfArticlesSold_lastYTD) AS DECIMAL) AS NoOfArticlesSold_lastYTD
FROM SalesInPeriod s
JOIN SalesYTD sytd ON sytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYear sl ON sl.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesLastYTD slytd ON slytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
), 
Total AS (
SELECT s.Lev1ArticleHierarchyName
, s.Revenue
, CAST(s.NoOfArticlesSold AS DECIMAL) AS NoOfArticlesSold
, (SELECT NoOfCustomers FROM Totals) AS NoOfCustomers
, sytd.Revenue_YTD AS Revenue_YTD
, CASE WHEN sytd.NoOfArticlesSold_YTD = 0 THEN NULL ELSE CAST(sytd.NoOfArticlesSold_YTD AS DECIMAL) END AS NoOfArticlesSold_YTD
, CASE WHEN t.NoOfCustomers_YTD = 0 THEN NULL ELSE t.NoOfCustomers_YTD END AS NoOfCustomers_YTD
, sl.Revenue_lastYear AS Revenue_lastYear
, CASE WHEN sl.NoOfArticlesSold_lastYear = 0 THEN NULL ELSE CAST(sl.NoOfArticlesSold_lastYear AS DECIMAL) END AS NoOfArticlesSold_lastYear
, CASE WHEN t.NoOfCustomers_lastYear = 0 THEN NULL ELSE t.NoOfCustomers_lastYear END AS NoOfCustomers_lastYear
, slytd.Revenue_lastYTD AS Revenue_lastYTD
, CASE WHEN slytd.NoOfArticlesSold_lastYTD = 0 THEN NULL ELSE CAST(slytd.NoOfArticlesSold_lastYTD AS DECIMAL) END AS NoOfArticlesSold_lastYTD
, CASE WHEN t.NoOfCustomers_lastYTD = 0 THEN NULL ELSE t.NoOfCustomers_lastYTD END AS NoOfCustomers_lastYTD
FROM SalesInPeriod s
JOIN SalesYTD sytd ON sytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYear sl ON sl.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesLastYTD slytd ON slytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
JOIN Totals t ON 1=1
)

SELECT
 t.Lev1ArticleHierarchyName
, NULL AS total
, x.Data
, CASE WHEN x.periode = 0 THEN NULL ELSE x.periode END AS periode
, CASE WHEN x.ytd = 0 THEN NULL ELSE x.ytd END AS ytd
, CASE WHEN x.periode_lastYear = 0 THEN NULL ELSE x.periode_lastYear END AS periode_lastYear
, CASE WHEN x.ytd_lastYear = 0 THEN NULL ELSE x.ytd_lastYear END AS ytd_lastYear
FROM Total t
CROSS APPLY (
	VALUES
         ('1 Revenue' , t.Revenue, t.Revenue_YTD, t.Revenue_lastYear, t.Revenue_lastYTD),
         ('2 NoOfArticles' , t.NoOfArticlesSold, t.NoOfArticlesSold_YTD, t.NoOfArticlesSold_lastYear, t.NoOfArticlesSold_lastYTD),
        -- ('3 NoOfCustomers' , t.NoOfCustomers, t.NoOfCustomers_YTD, t.NoOfCustomers_lastYear, t.NoOfCustomers_lastYTD),
			('4 RevenuePerCustomer', (t.Revenue/t.NoOfCustomers) , (t.Revenue_YTD/t.NoOfCustomers_YTD), (t.Revenue_lastYear/t.NoOfCustomers_lastYear), (t.Revenue_lastYTD/t.NoOfCustomers_lastYTD)),
			('5 ItemsPerCustomer', (t.NoOfArticlesSold/t.NoOfCustomers),(t.NoOfArticlesSold_YTD/t.NoOfCustomers_YTD),(t.NoOfArticlesSold_lastYear/t.NoOfCustomers_lastYear),(t.NoOfArticlesSold_lastYTD/t.NoOfCustomers_lastYTD)),
			('6 PricePerItem', (t.Revenue/NULLIF(t.NoOfArticlesSold,0)), (t.Revenue_YTD/t.NoOfArticlesSold_YTD),(t.Revenue_lastYear/t.NoOfArticlesSold_lastYear),(t.Revenue_lastYTD/t.NoOfArticlesSold_lastYTD) )
  ) x (Data, periode, ytd, periode_lastYear, ytd_lastYear)
WHERE t.Revenue <> 0

   UNION 

	SELECT
	'Total' AS Lev1ArticleHierarchyName
	, 'Total' AS Total
	, x.Data
	, CASE WHEN x.periode = 0 THEN NULL ELSE x.periode END AS periode
	, CASE WHEN x.ytd = 0 THEN NULL ELSE x.ytd END AS ytd
	, CASE WHEN x.periode_lastYear = 0 THEN NULL ELSE x.periode_lastYear END AS periode_lastYear
	, CASE WHEN x.ytd_lastYear = 0 THEN NULL ELSE x.ytd_lastYear END AS ytd_lastYear
	FROM Totals t
	CROSS APPLY (
			VALUES
				('1 Revenue' , t.Revenue, t.Revenue_YTD, t.Revenue_lastYear, t.Revenue_lastYTD),
				('2 NoOfArticles' , t.NoOfArticlesSold, t.NoOfArticlesSold_YTD, t.NoOfArticlesSold_lastYear, t.NoOfArticlesSold_lastYTD),
			    ('3 NoOfCustomers' , t.NoOfCustomers, t.NoOfCustomers_YTD, t.NoOfCustomers_lastYear, t.NoOfCustomers_lastYTD),
				('4 RevenuePerCustomer', (t.Revenue/t.NoOfCustomers) , (t.Revenue_YTD/t.NoOfCustomers_YTD), (t.Revenue_lastYear/t.NoOfCustomers_lastYear), (t.Revenue_lastYTD/t.NoOfCustomers_lastYTD)),
				('5 ItemsPerCustomer', (t.NoOfArticlesSold/t.NoOfCustomers),(t.NoOfArticlesSold_YTD/t.NoOfCustomers_YTD),(t.NoOfArticlesSold_lastYear/t.NoOfCustomers_lastYear),(t.NoOfArticlesSold_lastYTD/t.NoOfCustomers_lastYTD)),
				('6 PricePerItem', (t.Revenue/t.NoOfArticlesSold), (t.Revenue_YTD/t.NoOfArticlesSold_YTD),(t.Revenue_lastYear/t.NoOfArticlesSold_lastYear),(t.Revenue_lastYTD/t.NoOfArticlesSold_lastYTD) )
	  ) x (Data, periode, ytd, periode_lastYear, ytd_lastYear)

ORDER BY data, Total, t.Lev1ArticleHierarchyName ASC


END -- 0 = Alt salg dvs inkluder P&C orginal spøring

IF ( @WhichSales = 1 )		-- 1 Pick And Collect
BEGIN
----------------------------------------------------------------------
--Select
----------------------------------------------------------------------
;WITH flightReceipts AS (
SELECT   DISTINCT A.ReceiptHeadIdx,ReceiptDateIdx, A.FlightNo, A.FlightType, A.OriginCode FROM
		(SELECT 
			 se.ReceiptHeadIdx
			,se.ReceiptDateIdx			
			,se.FlightNo							--FlightNo
			,se.OriginCode AS FlightType			--FlightType
			,se.OriginCode
			,se.ConnectedAirport					--Airport
			,se.LocalAirport
			,se.Airline
			,cse.TransTypeValueTxt1	--P&C Ordreid
		FROM
			RBIM.Cov_CustomerFlightInfo se (NOLOCK)
			JOIN RBIM.Cov_CustomerSalesEvent CSE (NOLOCK) ON se.ReceiptHeadIdx = CSE.ReceiptHeadIdx AND CSE.TransTypeIdx=90404 --AND CSE.ReceiptStatusIdx=1
			WHERE se.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S)
			AND (	    @ReportType = 0 -- all flights
					OR (@ReportType = 1 AND se.OriginCode = 'D') -- departure flights
					OR (@ReportType = 2 AND se.OriginCode = 'A') -- arrival flights
					OR (@ReportType = 3 AND (se.OriginCode = '' OR se.OriginCode IS NULL)) -- extra flights
				)
			AND (	   @AirportCodes IS NULL	--no filtering on airport codes
					OR EXISTS(SELECT AirportCode FROM @codes WHERE AirportCode = (CASE WHEN OriginCode = 'A' THEN ConnectedAirport WHEN OriginCode = 'D' THEN LocalAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END) OR AirportCode = (CASE WHEN OriginCode = 'A' THEN LocalAirport WHEN OriginCode = 'D' THEN ConnectedAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END)) 
				)
			AND (	   @FlightNo IS NULL		--no filtering on flight 
					OR EXISTS(SELECT FlightNo FROM @flights WHERE FlightNo=se.FlightNo) )

			AND (	   CSE.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
					OR CSE.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
					OR CSE.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
					OR CSE.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear)
		)A
		
),
SalesReceipts AS (
SELECT 
		f.ReceiptHeadIdx,
		f.ReceiptId,
		f.ReceiptDateIdx,
		da.ArticleId,
		da.ArticleName,
		da.Lev1ArticleHierarchyId,
		da.Lev1ArticleHierarchyName,
		(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
		f.NumberOfCustomers AS NoOfCustomers
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	--JOIN @stores ds  ON ds.storeidx = f.storeidx
	WHERE f.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S) 
	AND (f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear)
	--AND (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) <> 0 
	--AND (f.SalesAmountExclVat+f.ReturnAmountExclVat) <> 0
), 

SalesInPeriod AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold,
SUM(SALES.Revenue) AS Revenue,
SUM(SALES.NoOfCustomers) AS NoOfCustomers
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx	
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx							
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
),

salesInPeriodLastYear AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYear,
SUM(SALES.Revenue) AS Revenue_lastYear,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYear
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
) 
, salesYtd AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_ytd,
SUM(SALES.Revenue) AS Revenue_ytd,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_ytd
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
)
, SalesLastYTD AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYTD,
SUM(SALES.Revenue) AS Revenue_lastYTD,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYTD
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
)/*
SELECT * FROM SalesInPeriod s
JOIN SalesYTD sytd ON sytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYear sl ON sl.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesLastYTD slytd ON slytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
*/
,Totals AS (
SELECT 
NULL AS Lev1ArticleHierarchyName
, SUM(NoOfCustomers)  AS NoOfCustomers
, SUM(NoOfCustomers_YTD)  AS NoOfCustomers_YTD
, SUM(NoOfCustomers_lastYear) AS NoOfCustomers_lastYear
, SUM(NoOfCustomers_lastYTD) AS NoOfCustomers_lastYTD
, SUM(Revenue) AS Revenue
, SUM(Revenue_YTD) AS Revenue_YTD
, SUM(Revenue_lastYear) AS Revenue_lastYear
, SUM(Revenue_lastYTD) AS Revenue_lastYTD
, CAST(SUM(NoOfArticlesSold) AS DECIMAL) AS NoOfArticlesSold
, CAST(SUM(NoOfArticlesSold_YTD) AS DECIMAL) AS NoOfArticlesSold_YTD
, CAST(SUM(NoOfArticlesSold_lastYear) AS DECIMAL) AS NoOfArticlesSold_lastYear
, CAST(SUM(NoOfArticlesSold_lastYTD) AS DECIMAL) AS NoOfArticlesSold_lastYTD
FROM SalesInPeriod s
JOIN SalesYTD sytd ON sytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYear sl ON sl.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesLastYTD slytd ON slytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
), 
Total AS (
SELECT s.Lev1ArticleHierarchyName
, s.Revenue
, CAST(s.NoOfArticlesSold AS DECIMAL) AS NoOfArticlesSold
, (SELECT NoOfCustomers FROM Totals) AS NoOfCustomers
, sytd.Revenue_YTD AS Revenue_YTD
, CASE WHEN sytd.NoOfArticlesSold_YTD = 0 THEN NULL ELSE CAST(sytd.NoOfArticlesSold_YTD AS DECIMAL) END AS NoOfArticlesSold_YTD
, CASE WHEN t.NoOfCustomers_YTD = 0 THEN NULL ELSE t.NoOfCustomers_YTD END AS NoOfCustomers_YTD
, sl.Revenue_lastYear AS Revenue_lastYear
, CASE WHEN sl.NoOfArticlesSold_lastYear = 0 THEN NULL ELSE CAST(sl.NoOfArticlesSold_lastYear AS DECIMAL) END AS NoOfArticlesSold_lastYear
, CASE WHEN t.NoOfCustomers_lastYear = 0 THEN NULL ELSE t.NoOfCustomers_lastYear END AS NoOfCustomers_lastYear
, slytd.Revenue_lastYTD AS Revenue_lastYTD
, CASE WHEN slytd.NoOfArticlesSold_lastYTD = 0 THEN NULL ELSE CAST(slytd.NoOfArticlesSold_lastYTD AS DECIMAL) END AS NoOfArticlesSold_lastYTD
, CASE WHEN t.NoOfCustomers_lastYTD = 0 THEN NULL ELSE t.NoOfCustomers_lastYTD END AS NoOfCustomers_lastYTD
FROM SalesInPeriod s
JOIN SalesYTD sytd ON sytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYear sl ON sl.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesLastYTD slytd ON slytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
JOIN Totals t ON 1=1
)

SELECT
 t.Lev1ArticleHierarchyName
, NULL AS total
, x.Data
, CASE WHEN x.periode = 0 THEN NULL ELSE x.periode END AS periode
, CASE WHEN x.ytd = 0 THEN NULL ELSE x.ytd END AS ytd
, CASE WHEN x.periode_lastYear = 0 THEN NULL ELSE x.periode_lastYear END AS periode_lastYear
, CASE WHEN x.ytd_lastYear = 0 THEN NULL ELSE x.ytd_lastYear END AS ytd_lastYear
FROM Total t
CROSS APPLY (
	VALUES
         ('1 Revenue' , t.Revenue, t.Revenue_YTD, t.Revenue_lastYear, t.Revenue_lastYTD),
         ('2 NoOfArticles' , t.NoOfArticlesSold, t.NoOfArticlesSold_YTD, t.NoOfArticlesSold_lastYear, t.NoOfArticlesSold_lastYTD),
        -- ('3 NoOfCustomers' , t.NoOfCustomers, t.NoOfCustomers_YTD, t.NoOfCustomers_lastYear, t.NoOfCustomers_lastYTD),
			('4 RevenuePerCustomer', (t.Revenue/t.NoOfCustomers) , (t.Revenue_YTD/t.NoOfCustomers_YTD), (t.Revenue_lastYear/t.NoOfCustomers_lastYear), (t.Revenue_lastYTD/t.NoOfCustomers_lastYTD)),
			('5 ItemsPerCustomer', (t.NoOfArticlesSold/t.NoOfCustomers),(t.NoOfArticlesSold_YTD/t.NoOfCustomers_YTD),(t.NoOfArticlesSold_lastYear/t.NoOfCustomers_lastYear),(t.NoOfArticlesSold_lastYTD/t.NoOfCustomers_lastYTD)),
			('6 PricePerItem', (t.Revenue/NULLIF(t.NoOfArticlesSold,0)), (t.Revenue_YTD/t.NoOfArticlesSold_YTD),(t.Revenue_lastYear/t.NoOfArticlesSold_lastYear),(t.Revenue_lastYTD/t.NoOfArticlesSold_lastYTD) )
  ) x (Data, periode, ytd, periode_lastYear, ytd_lastYear)
WHERE t.Revenue <> 0

   UNION 

	SELECT
	'Total' AS Lev1ArticleHierarchyName
	, 'Total' AS Total
	, x.Data
	, CASE WHEN x.periode = 0 THEN NULL ELSE x.periode END AS periode
	, CASE WHEN x.ytd = 0 THEN NULL ELSE x.ytd END AS ytd
	, CASE WHEN x.periode_lastYear = 0 THEN NULL ELSE x.periode_lastYear END AS periode_lastYear
	, CASE WHEN x.ytd_lastYear = 0 THEN NULL ELSE x.ytd_lastYear END AS ytd_lastYear
	FROM Totals t
	CROSS APPLY (
			VALUES
				('1 Revenue' , t.Revenue, t.Revenue_YTD, t.Revenue_lastYear, t.Revenue_lastYTD),
				('2 NoOfArticles' , t.NoOfArticlesSold, t.NoOfArticlesSold_YTD, t.NoOfArticlesSold_lastYear, t.NoOfArticlesSold_lastYTD),
			    ('3 NoOfCustomers' , t.NoOfCustomers, t.NoOfCustomers_YTD, t.NoOfCustomers_lastYear, t.NoOfCustomers_lastYTD),
				('4 RevenuePerCustomer', (t.Revenue/t.NoOfCustomers) , (t.Revenue_YTD/t.NoOfCustomers_YTD), (t.Revenue_lastYear/t.NoOfCustomers_lastYear), (t.Revenue_lastYTD/t.NoOfCustomers_lastYTD)),
				('5 ItemsPerCustomer', (t.NoOfArticlesSold/t.NoOfCustomers),(t.NoOfArticlesSold_YTD/t.NoOfCustomers_YTD),(t.NoOfArticlesSold_lastYear/t.NoOfCustomers_lastYear),(t.NoOfArticlesSold_lastYTD/t.NoOfCustomers_lastYTD)),
				('6 PricePerItem', (t.Revenue/t.NoOfArticlesSold), (t.Revenue_YTD/t.NoOfArticlesSold_YTD),(t.Revenue_lastYear/t.NoOfArticlesSold_lastYear),(t.Revenue_lastYTD/t.NoOfArticlesSold_lastYTD) )
	  ) x (Data, periode, ytd, periode_lastYear, ytd_lastYear)

ORDER BY data, Total, t.Lev1ArticleHierarchyName ASC

END -- 1 Pick And Collect

IF ( @WhichSales = 2 )		-- 2 all sales except Pick And Collect
BEGIN


----------------------------------------------------------------------
--Select
----------------------------------------------------------------------
;WITH flightReceipts AS (
	SELECT   DISTINCT A.ReceiptHeadIdx,ReceiptDateIdx, A.FlightNo, A.FlightType, A.OriginCode FROM
		(SELECT 
			se.ReceiptHeadIdx,
			se.ReceiptDateIdx,
			se.FlightNo,
			CASE  
							WHEN TRIM(se.OriginCode)  = 'D' THEN 'Departure' 
							WHEN TRIM(se.OriginCode)  = 'A' THEN 'Arrival'
							WHEN TRIM(se.OriginCode)  = ''  THEN 'Other'	
							WHEN  se.OriginCode IS NULL     THEN 'Other'	
							ELSE 	''	
					END  AS FlightType
					,se.OriginCode
					,se.ConnectedAirport
					,se.LocalAirport
		FROM
			RBIM.Cov_CustomerFlightInfo se (NOLOCK) 
		WHERE  se.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S)
		AND se.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
			OR se.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
			OR se.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
			OR se.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear
		)A
		WHERE 

			 (	@ReportType = 0 -- all flights
					OR (@ReportType = 1 AND A.OriginCode = 'D') -- departure flights
					OR (@ReportType = 2 AND A.OriginCode = 'A') -- arrival flights
					OR (@ReportType = 3 AND (A.OriginCode = '' OR A.OriginCode IS NULL)) -- extra flights
				)
			AND (	@AirportCodes IS NULL	--no filtering on all airport codes
					OR EXISTS(SELECT AirportCode FROM @codes WHERE AirportCode = (CASE WHEN OriginCode = 'A' THEN ConnectedAirport WHEN OriginCode = 'D' THEN LocalAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END) OR AirportCode = (CASE WHEN OriginCode = 'A' THEN LocalAirport WHEN OriginCode = 'D' THEN ConnectedAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END)) 
				)
			AND (	@FlightNo IS NULL		--no filtering on all flight 
					OR EXISTS(SELECT FlightNo FROM @flights WHERE FlightNo=A.FlightNo) 
				)
),
SalesReceipts AS (
SELECT 
		f.ReceiptHeadIdx,
		f.ReceiptId,
		f.ReceiptDateIdx,
		da.ArticleId,
		da.ArticleName,
		da.Lev1ArticleHierarchyId,
		da.Lev1ArticleHierarchyName,
		(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
		f.NumberOfCustomers AS NoOfCustomers
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	WHERE  f.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S)
		AND (f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear)

), 

SalesInPeriod AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold,
SUM(SALES.Revenue) AS Revenue,
SUM(SALES.NoOfCustomers) AS NoOfCustomers
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx	
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx							
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
),

salesInPeriodLastYear AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYear,
SUM(SALES.Revenue) AS Revenue_lastYear,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYear
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
) 
, salesYtd AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_ytd,
SUM(SALES.Revenue) AS Revenue_ytd,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_ytd
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
)
, SalesLastYTD AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYTD,
SUM(SALES.Revenue) AS Revenue_lastYTD,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYTD
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM flightReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
)


--PC Salg Start
,FlightPC AS (
	SELECT   DISTINCT A.ReceiptHeadIdx,ReceiptDateIdx, A.FlightNo, A.FlightType, A.OriginCode FROM
		(SELECT 
			 se.ReceiptHeadIdx
			,se.ReceiptDateIdx			
			,se.FlightNo							--FlightNo
			,se.OriginCode AS FlightType			--FlightType
			,se.OriginCode
			,se.ConnectedAirport					--Airport
			,se.LocalAirport
			,se.Airline
			,cse.TransTypeValueTxt1	--P&C Ordreid
		FROM
			RBIM.Cov_CustomerFlightInfo se (NOLOCK)
			JOIN RBIM.Cov_CustomerSalesEvent CSE (NOLOCK) ON se.ReceiptHeadIdx = CSE.ReceiptHeadIdx AND CSE.TransTypeIdx=90404 AND CSE.StoreIdx = se.StoreIdx --Only P&C
			WHERE se.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S)
			AND (	    @ReportType = 0 -- all flights
					OR (@ReportType = 1 AND se.OriginCode = 'D') -- departure flights
					OR (@ReportType = 2 AND se.OriginCode = 'A') -- arrival flights
					OR (@ReportType = 3 AND (se.OriginCode = '' OR se.OriginCode IS NULL)) -- extra flights
				)
			AND (	   @AirportCodes IS NULL	--no filtering on airport codes
					OR EXISTS(SELECT AirportCode FROM @codes WHERE AirportCode = (CASE WHEN OriginCode = 'A' THEN ConnectedAirport WHEN OriginCode = 'D' THEN LocalAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END) OR AirportCode = (CASE WHEN OriginCode = 'A' THEN LocalAirport WHEN OriginCode = 'D' THEN ConnectedAirport WHEN OriginCode = 'X' AND SUBSTRING(FlightNo, 1, 1) = '.' THEN ConnectedAirport END)) 
				)
			AND (	   @FlightNo IS NULL		--no filtering on flight 
					OR EXISTS(SELECT FlightNo FROM @flights WHERE FlightNo=se.FlightNo) )

			AND (	   CSE.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
					OR CSE.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
					OR CSE.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
					OR CSE.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear)
		)A
)

,SalesPC AS (
SELECT 
		f.ReceiptHeadIdx,
		f.ReceiptId,
		f.ReceiptDateIdx,
		da.ArticleId,
		da.ArticleName,
		da.Lev1ArticleHierarchyId,
		da.Lev1ArticleHierarchyName,
		(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
		f.NumberOfCustomers AS NoOfCustomers
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	WHERE f.StoreIdx IN (SELECT s.StoreIdx FROM @stores AS S) 
	AND (f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
			OR f.ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear)
	--AND ((f.SalesAmountExclVat+f.ReturnAmountExclVat)<>0 OR NumberOfCustomers<>0) 	

)

,SalesInPeriodPC AS (

SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold,
SUM(SALES.Revenue) AS Revenue,
SUM(SALES.NoOfCustomers) AS NoOfCustomers
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM FlightPC
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx	
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesPC --SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx												
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
)

,salesInPeriodLastYearPC AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYear,
SUM(SALES.Revenue) AS Revenue_lastYear,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYear
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM FlightPC
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesPC --SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
) 

,salesYtdPC AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_ytd,
SUM(SALES.Revenue) AS Revenue_ytd,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_ytd
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM FlightPC
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesPC--SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartThisYear AND @DateToIdx						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
--HAVING SUM(Revenue) <> 0
), 

SalesLastYTDPC AS (
SELECT  
SALES.Lev1ArticleHierarchyName,
SUM(SALES.NoOfArticlesSold) AS NoOfArticlesSold_lastYTD,
SUM(SALES.Revenue) AS Revenue_lastYTD,
SUM(SALES.NoOfCustomers) AS NoOfCustomers_lastYTD
FROM  
(
	SELECT 
		ReceiptHeadIdx
	FROM FlightPC
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear
) FLIGHT
INNER JOIN 
(
	SELECT 
		ReceiptHeadIdx,
		ReceiptId,
		ArticleId,
		Lev1ArticleHierarchyName,
		NoOfArticlesSold,
		Revenue,
		NoOfCustomers
	FROM SalesPC--SalesReceipts
	WHERE ReceiptDateIdx BETWEEN @DateFromIdxStartLastYear AND @DateToIdxLastYear						
	
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
WHERE --Filter on article selection
   (@ArticleSelection IS NULL OR SALES.ArticleID IN (SELECT ArticleId FROM @articles))
GROUP BY 
SALES.Lev1ArticleHierarchyName
)

,Totals AS (
SELECT 
NULL AS Lev1ArticleHierarchyName
, SUM(s.NoOfCustomers) - MAX(ISNULL(sPC.NoOfCustomers,0)) AS NoOfCustomers 
, SUM(sytd.NoOfCustomers_YTD) - MAX(ISNULL(sytdPC.NoOfCustomers_YTD,0)) AS NoOfCustomers_YTD
, SUM(sl.NoOfCustomers_lastYear) - MAX(ISNULL(slPC.NoOfCustomers_lastYear,0)) AS NoOfCustomers_lastYear
, SUM(slytd.NoOfCustomers_lastYTD) - MAX(ISNULL(slytdPC.NoOfCustomers_lastYTD,0)) AS NoOfCustomers_lastYTD
, SUM(s.Revenue) - SUM(ISNULL(sPC.Revenue,0)) AS Revenue
, SUM(sytd.Revenue_YTD) - SUM(ISNULL(sytdPC.Revenue_YTD,0)) AS Revenue_YTD
, SUM(sl.Revenue_lastYear) - SUM(ISNULL(slPC.Revenue_lastYear,0)) AS Revenue_lastYear
, SUM(slytd.Revenue_lastYTD) - SUM(ISNULL(slytdPC.Revenue_lastYTD,0)) AS Revenue_lastYTD
, CAST(SUM(s.NoOfArticlesSold) - SUM(ISNULL(sPC.NoOfArticlesSold,0)) AS DECIMAL) AS NoOfArticlesSold
, CAST(SUM(sytd.NoOfArticlesSold_YTD) - SUM(ISNULL(sytdPC.NoOfArticlesSold_YTD,0)) AS DECIMAL) AS NoOfArticlesSold_YTD
, CAST(SUM(sl.NoOfArticlesSold_lastYear) - SUM(ISNULL(slPC.NoOfArticlesSold_lastYear,0)) AS DECIMAL) AS NoOfArticlesSold_lastYear
, CAST(SUM(slytd.NoOfArticlesSold_lastYTD) - SUM(ISNULL(slytdPC.NoOfArticlesSold_lastYTD,0)) AS DECIMAL) AS NoOfArticlesSold_lastYTD
FROM SalesInPeriod s
LEFT JOIN SalesYTD sytd ON sytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYear sl ON sl.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesLastYTD slytd ON slytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodPC sPC ON sPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesYtdPC sytdPC ON sytdPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYearPC slPC ON slPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName  
LEFT JOIN SalesLastYTDPC slytdPC ON slytdPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
), 
Total AS (
SELECT s.Lev1ArticleHierarchyName
, s.Revenue - sPC.Revenue AS Revenue
, CAST(s.NoOfArticlesSold-ISNULL(sPC.NoOfArticlesSold,0) AS DECIMAL) AS NoOfArticlesSold
, (SELECT NoOfCustomers FROM Totals)  AS NoOfCustomers
, sytd.Revenue_YTD-ISNULL(sytdPC.Revenue_YTD,0) AS Revenue_YTD
, CASE WHEN sytd.NoOfArticlesSold_YTD = 0 THEN NULL ELSE CAST(sytd.NoOfArticlesSold_YTD-ISNULL(sytdPC.NoOfArticlesSold_YTD,0) AS DECIMAL) END AS NoOfArticlesSold_YTD
, CASE WHEN t.NoOfCustomers_YTD = 0 THEN NULL ELSE t.NoOfCustomers_YTD END AS NoOfCustomers_YTD
, sl.Revenue_lastYear-ISNULL(slPC.Revenue_lastYear,0) AS Revenue_lastYear
, CASE WHEN sl.NoOfArticlesSold_lastYear = 0 THEN NULL ELSE CAST(sl.NoOfArticlesSold_lastYear-ISNULL(slPC.NoOfArticlesSold_lastYear,0) AS DECIMAL) END AS NoOfArticlesSold_lastYear
, CASE WHEN t.NoOfCustomers_lastYear = 0 THEN NULL ELSE t.NoOfCustomers_lastYear END AS NoOfCustomers_lastYear
, slytd.Revenue_lastYTD-ISNULL(slytdPC.Revenue_lastYTD,0) AS Revenue_lastYTD
, CASE WHEN slytd.NoOfArticlesSold_lastYTD = 0 THEN NULL ELSE CAST(slytd.NoOfArticlesSold_lastYTD-ISNULL(slytdPC.NoOfArticlesSold_lastYTD,0) AS DECIMAL) END AS NoOfArticlesSold_lastYTD
, CASE WHEN t.NoOfCustomers_lastYTD = 0 THEN NULL ELSE t.NoOfCustomers_lastYTD END AS NoOfCustomers_lastYTD
FROM SalesInPeriod s
LEFT JOIN SalesYTD sytd ON sytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYear sl ON sl.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesLastYTD slytd ON slytd.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodPC sPC ON sPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesYtdPC sytdPC ON sytdPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
LEFT JOIN SalesInPeriodLastYearPC slPC ON slPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName  
LEFT JOIN SalesLastYTDPC slytdPC ON slytdPC.Lev1ArticleHierarchyName = s.Lev1ArticleHierarchyName
JOIN Totals t ON 1=1
)
-- PC Salg slutt

--SELECT * FROM SalesPC
--SELECT * FROM Total

SELECT
	 t.Lev1ArticleHierarchyName
	, NULL AS total
	, x.Data
	, CASE WHEN x.periode = 0 THEN NULL ELSE x.periode END AS periode
	, CASE WHEN x.ytd = 0 THEN NULL ELSE x.ytd END AS ytd
	, CASE WHEN x.periode_lastYear = 0 THEN NULL ELSE x.periode_lastYear END AS periode_lastYear
	, CASE WHEN x.ytd_lastYear = 0 THEN NULL ELSE x.ytd_lastYear END AS ytd_lastYear
FROM Total t
CROSS APPLY (
	VALUES
        ('1 Revenue' , t.Revenue, t.Revenue_YTD, t.Revenue_lastYear, t.Revenue_lastYTD),
        ('2 NoOfArticles' , t.NoOfArticlesSold, t.NoOfArticlesSold_YTD, t.NoOfArticlesSold_lastYear, t.NoOfArticlesSold_lastYTD),
        -- ('3 NoOfCustomers' , t.NoOfCustomers, t.NoOfCustomers_YTD, t.NoOfCustomers_lastYear, t.NoOfCustomers_lastYTD),
		('4 RevenuePerCustomer', (t.Revenue/t.NoOfCustomers) , (t.Revenue_YTD/t.NoOfCustomers_YTD), (t.Revenue_lastYear/t.NoOfCustomers_lastYear), (t.Revenue_lastYTD/t.NoOfCustomers_lastYTD)),
		('5 ItemsPerCustomer', (t.NoOfArticlesSold/t.NoOfCustomers),(t.NoOfArticlesSold_YTD/t.NoOfCustomers_YTD),(t.NoOfArticlesSold_lastYear/t.NoOfCustomers_lastYear),(t.NoOfArticlesSold_lastYTD/t.NoOfCustomers_lastYTD)),
		('6 PricePerItem', (t.Revenue/NULLIF(t.NoOfArticlesSold,0)), (t.Revenue_YTD/t.NoOfArticlesSold_YTD),(t.Revenue_lastYear/t.NoOfArticlesSold_lastYear),(t.Revenue_lastYTD/t.NoOfArticlesSold_lastYTD) )
  ) x (Data, periode, ytd, periode_lastYear, ytd_lastYear)
WHERE t.Revenue <> 0

UNION 

SELECT
	'Total' AS Lev1ArticleHierarchyName
	, 'Total' AS Total
	, x.Data
	, CASE WHEN x.periode = 0 THEN NULL ELSE x.periode END AS periode
	, CASE WHEN x.ytd = 0 THEN NULL ELSE x.ytd END AS ytd
	, CASE WHEN x.periode_lastYear = 0 THEN NULL ELSE x.periode_lastYear END AS periode_lastYear
	, CASE WHEN x.ytd_lastYear = 0 THEN NULL ELSE x.ytd_lastYear END AS ytd_lastYear
FROM Totals t
CROSS APPLY (
		VALUES
				('1 Revenue' , t.Revenue, t.Revenue_YTD, t.Revenue_lastYear, t.Revenue_lastYTD),
				('2 NoOfArticles' , t.NoOfArticlesSold, t.NoOfArticlesSold_YTD, t.NoOfArticlesSold_lastYear, t.NoOfArticlesSold_lastYTD),
			    ('3 NoOfCustomers' , t.NoOfCustomers, t.NoOfCustomers_YTD, t.NoOfCustomers_lastYear, t.NoOfCustomers_lastYTD),
				('4 RevenuePerCustomer', (t.Revenue/t.NoOfCustomers) , (t.Revenue_YTD/t.NoOfCustomers_YTD), (t.Revenue_lastYear/t.NoOfCustomers_lastYear), (t.Revenue_lastYTD/t.NoOfCustomers_lastYTD)),
				('5 ItemsPerCustomer', (t.NoOfArticlesSold/t.NoOfCustomers),(t.NoOfArticlesSold_YTD/t.NoOfCustomers_YTD),(t.NoOfArticlesSold_lastYear/t.NoOfCustomers_lastYear),(t.NoOfArticlesSold_lastYTD/t.NoOfCustomers_lastYTD)),
				('6 PricePerItem', (t.Revenue/NULLIF(t.NoOfArticlesSold,0)), (t.Revenue_YTD/t.NoOfArticlesSold_YTD),(t.Revenue_lastYear/t.NoOfArticlesSold_lastYear),(t.Revenue_lastYTD/t.NoOfArticlesSold_lastYTD) )
	  ) x (Data, periode, ytd, periode_lastYear, ytd_lastYear)

ORDER BY data, Total, t.Lev1ArticleHierarchyName ASC




END -- 2 all sales except Pick And Collect

END -- Siste END



GO

