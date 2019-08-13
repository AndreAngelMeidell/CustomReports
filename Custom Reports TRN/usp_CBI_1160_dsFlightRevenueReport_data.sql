USE [BI_Mart]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1160_dsFlightRevenueReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1160_dsFlightRevenueReport_data]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1160_dsFlightRevenueReport_data]
(   
	@StoreId			VARCHAR(100)
	,@DateFrom			DATE 
	,@DateTo			DATE
	,@ReportType		SMALLINT		-- 0 all flights, 1 departure, 2 arrival, 3 extra
	,@AirportCodes		VARCHAR(MAX)
	,@FlightNo			VARCHAR(MAX)	-- list of flight no
	,@GroupByFlight		SMALLINT		-- 1 group by flights, 0 sum all flights
) 
AS  
BEGIN
	SET NOCOUNT ON
	  
	------------------------------------------------------------------------------------------------------
	DECLARE @stores TABLE(StoreIdx Int);
	INSERT INTO @stores
	SELECT ds.StoreIdx FROM RBIM.Dim_Store ds (NOLOCK) WHERE ds.StoreId = @StoreId; --AND ds.IsCurrent = 1

	DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer);
	DECLARE @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer);

	-- AirportCodes
	IF RTRIM(LTRIM(@AirportCodes)) = '' SET @AirportCodes = NULL;
	DECLARE @codes TABLE(AirportCode VARCHAR(MAX));
	INSERT INTO @codes
	SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@AirportCodes,',''');

	-- FlightNo
	IF RTRIM(LTRIM(@FlightNo)) = '' SET @FlightNo = NULL;
	DECLARE @flights TABLE(FlightNo VARCHAR(MAX));
	INSERT INTO @flights
	SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@FlightNo,',''');

	SELECT 
		CASE @GroupByFlight
			WHEN 1 THEN FLIGHT.FlightNo
			ELSE NULL
		END								'FlightNo'
		,CASE @GroupByFlight
			WHEN 0 THEN FLIGHT.FlightType
			ELSE NULL
		END 							'FlightType'
		,da.BrandId						'BrandId'
		,da.BrandName					'BrandName'
		,da.Lev1ArticleHierarchyId 		'ArticleHierarchyId '
		,da.Lev1ArticleHierarchyName	'ArticleHierarchyName'
		,NoOfArticlesSold				'tmpNoOfArticlesSold'
		,Revenue						'tmpRevenue'
		,RevenueInclVat					'tmpRevenueInclVat'
	INTO
		#tmpResultSet
	FROM 
		(
		SELECT 
			se.ReceiptIdx AS ReceiptHeadIdx,
			CASE se.TransTypevalueTxt4
							WHEN 'D' THEN se.TranstypeValuetxt1 + ' - ' + se.TransTypeValueTxt3 
							WHEN 'A' THEN se.TransTypeValueTxt1 + ' - ' + se.TransTypeValueTxt2	
							ELSE 	transtypevaluetxt1	
					END AS FlightNo,
			CASE se.TransTypeValueTxt4
							WHEN 'D' THEN 'Avgang' 
							WHEN 'A' THEN 'Ankomst'
							WHEN '' THEN 'Ekstra'	
							ELSE 	''	
					END  AS FlightType
		FROM
			RBIM.Cov_CustomerSalesEvent se (NOLOCK)
		JOIN RBIM.Dim_TransType (NOLOCK) tt on tt.TransTypeIdx = Se.TransTypeIdx
		JOIN @stores S ON S.StoreIdx=se.StoreIdx
		WHERE tt.TransTypeId = 90403 and 									-- bruk ID ikke IDX, mao. Dim_TransType
			se.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	-- 2% forbedring ift. (dd.FullDate BETWEEN @DateFrom AND @DateTo)
			AND (	@ReportType = 0 -- all flights
					OR (@ReportType = 1 AND se.TransTypeValueTxt4 = 'D') -- departure flights
					OR (@ReportType = 2 AND se.TransTypeValueTxt4 = 'A') -- arrival flights
					OR (@ReportType = 3 AND se.TransTypeValueTxt4 = '') -- extra flights
				)
			AND (	@AirportCodes IS NULL	--no filtering on airport codes
					OR EXISTS(SELECT TOP 1 1 FROM @codes where AirportCode=se.TransTypeValueTxt2 OR AirportCode=se.TransTypeValueTxt3) 
				)
			AND (	@FlightNo IS NULL		--no filtering on flight 
					OR EXISTS(SELECT TOP 1 1  FROM @flights where FlightNo=se.TransTypeValueTxt1) 
				)
		) FLIGHT
	INNER JOIN 
		(
		SELECT 
			FLOOR(f.ReceiptIdx/1000)*1000 as ReceiptHeadIdx,
			f.ArticleIdx,
			SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
			SUM(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
			SUM(f.SalesAmount+f.ReturnAmount) AS RevenueInclVat
		FROM
			RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
		JOIN @stores S ON S.StoreIdx=f.StoreIdx
		WHERE
			f.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	-- samme filter her - gir 2% forbedring
		GROUP BY
			FLOOR(f.ReceiptIdx/1000)
			,f.ArticleIdx
		) SALES
	ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
	INNER JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = SALES.ArticleIdx AND da.Lev1ArticleHierarchyId>0 

	IF (@GroupByFlight = 1)
		SELECT 
			FlightNo
			,BrandId
			,BrandName
			,ArticleHierarchyId
			,ArticleHierarchyName
			,SUM(tmpNoOfArticlesSold)		'NoOfArticlesSold'
			,SUM(tmpRevenue)				'Revenue'
			,SUM(tmpRevenueInclVat)			'RevenueInclVat'
		FROM
			#tmpResultSet
		GROUP BY 
			FlightNo
			,BrandId
			,BrandName
			,ArticleHierarchyId
			,ArticleHierarchyName;
	ELSE
		SELECT 
			FlightType
			,BrandId
			,BrandName
			,ArticleHierarchyId
			,ArticleHierarchyName
			,SUM(tmpNoOfArticlesSold)		'NoOfArticlesSold'
			,SUM(tmpRevenue)				'Revenue'
			,SUM(tmpRevenueInclVat)			'RevenueInclVat'
		FROM
			#tmpResultSet
		GROUP BY 
			FlightType
			,BrandId
			,BrandName
			,ArticleHierarchyId
			,ArticleHierarchyName;
			
	DROP TABLE #tmpResultSet;
END

GO
