USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1186_dsRevenueFiguresReport_WhichSales]    Script Date: 28.06.2018 13:36:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1186_dsRevenueFiguresReport_WhichSales]

    (
      @StoreId AS VARCHAR(100)
      ,@DateFrom AS DATE
      ,@DateTo AS DATE
      ,@ReportType SMALLINT -- 0 all flights, 1 departure, 2 arrival--, 3 extra 
      ,@FlightNo VARCHAR(MAX) --list of flight no
      ,@AirportCodes VARCHAR(MAX) --list of arirport codes
      ,@Top INTEGER = 50
      ,@ZeroSale AS INTEGER --0 show all, 1 show only articles not sold in given period 
      ,@ArticleSelection AS VARCHAR(MAX)
      ,@WhichSales SMALLINT	-- 0 all sales, 1 Pick And Collect, 2 all sales except Pick And Collect
    )
AS
    BEGIN

        SET NOCOUNT ON;

----------------------------------------------------------------------
--Prepare input
----------------------------------------------------------------------

        IF RTRIM(LTRIM(@AirportCodes)) = ''
            SET @AirportCodes = NULL
        IF RTRIM(LTRIM(@FlightNo)) = ''
            SET @FlightNo = NULL

        DECLARE @flights TABLE ( FlightNo VARCHAR(MAX) )

        INSERT  INTO @flights
                SELECT  ParameterValue
                FROM    [dbo].[ufn_RBI_SplittParameterString](@FlightNo, ',''')

        DECLARE @codes TABLE
            (
              AirportCode VARCHAR(MAX)
            )

        INSERT  INTO @codes
                SELECT  ParameterValue
                FROM    [dbo].[ufn_RBI_SplittParameterString](@AirportCodes,
                                                              ',''')

        DECLARE @articles TABLE ( ArticleId VARCHAR(MAX) )

        INSERT  INTO @articles
                SELECT  ParameterValue
                FROM    [dbo].[ufn_RBI_SplittParameterString](@ArticleSelection,
                                                              ',''')


        DECLARE @DateFromIdx INT = CAST(CONVERT(VARCHAR(8), @DateFrom, 112) AS INTEGER)
        DECLARE @DateToIdx INT = CAST(CONVERT(VARCHAR(8), @DateTo, 112) AS INTEGER)


        IF ( @WhichSales = 0 )		-- 2 = Alt salg dvs inkluder P&C hvis det er i Recipt tabellen
            BEGIN

;WITH Sales AS (
SELECT  
SALES.ArticleName,
SALES.ArticleId,
SALES.SupplierArticleId,
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
	JOIN RBIM.Dim_TransType (NOLOCK) tt ON tt.TransTypeIdx = Se.TransTypeIdx
	JOIN RBIM.Dim_Date dd (NOLOCK) ON dd.dateidx = se.receiptdateidx
	JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = se.storeidx
	WHERE ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1
	AND tt.transtypeId = 90403									
	AND se.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx	
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
		FLOOR(f.ReceiptIdx/1000) AS ReceiptHeadIdx,
		da.ArticleId,
		da.ArticleName,
		da.Lev2ArticleHierarchyId,
		da.Lev2ArticleHierarchyName,
		NULL AS SupplierArticleId, --supa.SupplierArticleID AS SupplierArticleId,
		SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		SUM(f.SalesAmount+f.ReturnAmount) AS Revenue,
		SUM(f.SalesAmount+f.ReturnAmount) - SUM(f.NetPurchasePrice)  AS GrossProfit
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
	--JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
	--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
	WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
	AND ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1								
	GROUP BY FLOOR(f.ReceiptIdx/1000) ,da.Lev2ArticleHierarchyId, da.Lev2ArticleHierarchyName, da.ArticleName, da.ArticleId--, supa.SupplierArticleID
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
GROUP BY 
SALES.ArticleName, SALES.ArticleId, SALES.Lev2ArticleHierarchyName, SALES.SupplierArticleId
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
		NULL AS SupplierArticleId,--s.SupplierArticleId,
		da.Lev2ArticleHierarchyName,	
		NULL AS NoOfArticlesSold,
		NULL AS Revenue,
		NULL AS GrossProfit,
		ls.FullDate
	FROM LastSold ls
	LEFT JOIN Sales s ON ls.ArticleId = s.ArticleId
	JOIN RBIM.Dim_Article da ON da.ArticleId = ls.ArticleId
	LEFT JOIN RBIM.Dim_Supplier dsup ON dsup.SupplierIdx = ls.SupplierIdx
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
ORDER BY  s.ArticleName --s.Lev2ArticleHierarchyName,

            END						-- 2 END
														
        IF ( @WhichSales = 1 )	-- 1=PickAndCollect kun fra Agg_PickAndCollectOrders
            BEGIN

;
                WITH    Sales
                          AS ( SELECT   ArticleName ,
                                        ArticleId ,
                                        SupplierArticleId ,
                                        Lev2ArticleHierarchyName ,
                                        SUM(NoOfArticlesSold) AS NoOfArticlesSold ,
                                        SUM(Revenue) AS Revenue ,
                                        SUM( Revenue - PurchasePrice  ) AS GrossProfit
                               FROM     ( SELECT    da.ArticleName ,
                                                    da.ArticleId ,
                                                    NULL AS SupplierArticleId ,
                                                    da.Lev2ArticleHierarchyName ,
                                                    apcol.ReceivedQty AS NoOfArticlesSold ,
                                                    apcol.ArticleDeliveredPrice AS Revenue ,
                                                    PurchasePrice = (SELECT TOP 1 f.NetPurchasePrice FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
JOIN RBIM.Dim_Article da2 (NOLOCK) ON da2.ArticleIdx = f.ArticleIdx
JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
--JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND ds.StoreId = @StoreId
AND ds.IsCurrentStore = 1
AND da.ArticleIdx =  da2.ArticleIdx
ORDER BY f.ReceiptDateIdx DESC
                                                              )
                                          FROM      CBIM.Agg_PickAndCollectOrders apco
                                                    INNER JOIN CBIM.Agg_PickAndCollectOrderLines apcol ( NOLOCK ) ON apcol.OrderID = apco.OrderID
                                                    INNER JOIN RBIM.Dim_Gtin dg ( NOLOCK ) ON dg.Gtin = apcol.ArticleEan
                                                              AND dg.StatusId = 1	--1=Aktiv,9=Slettet ...
                                                    INNER JOIN RBIM.Cov_ArticleGtin ag ( NOLOCK ) ON ag.GtinIdx = dg.GtinIdx
                                                    INNER JOIN RBIM.Dim_Article da ( NOLOCK ) ON da.ArticleIdx = ag.ArticleIdx
                                                              AND da.isCurrent = 1
                                                    INNER JOIN VBDCM..AllArticles
                                                    AS AA ON AA.ArticleID = da.ArticleId
                                                    INNER JOIN RBIM.Dim_store ds ( NOLOCK ) ON ds.Storeid = apco.StoreId 
													--INNER JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = da.
													--inner JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
                                          WHERE     1 = 1
                                                    AND ds.StoreId = @StoreId
                                                    AND ds.isCurrent <> 0
                                                    AND CONVERT(DATE, apco.PaymentSuccessTimeStamp, 103) BETWEEN CONVERT(DATE, @DateFrom, 103)
                                                    AND CONVERT(DATE, @DateTo, 103)
                                                    AND ( @ReportType = 0								-- all flights
                                                          OR ( @ReportType = 1
                                                              AND apco.FlightDirection = 'D'
                                                             )	-- departure flights
                                                          OR ( @ReportType = 2
                                                              AND apco.FlightDirection = 'A'
                                                             )	-- arrival flights
                                                          OR ( @ReportType = 3
                                                              AND apco.FlightDirection = ''
                                                             )	-- extra flights
                                                        )
                                                    AND apcol.ArticleDeliveredPrice <> 0
                                        ) AS Sales
                               GROUP BY ArticleName ,
                                        ArticleId ,
                                        SupplierArticleId ,
                                        Lev2ArticleHierarchyName
                             ),
                        LastSold
                          AS ( SELECT   da.ArticleId ,
                                        dd.FullDate ,
                                        f.supplierIdx ,
                                        ROW_NUMBER() OVER ( PARTITION BY da.ArticleId ORDER BY f.ReceiptDateIdx DESC ) AS rn
                               FROM     RBIM.Dim_Article da ( NOLOCK )
                                        LEFT JOIN RBIM.Agg_SalesAndReturnPerDay f ( NOLOCK ) ON f.ArticleIdx = da.ArticleIdx
                                        LEFT JOIN RBIM.Dim_Date dd ( NOLOCK ) ON f.ReceiptDateIdx = dd.DateIdx
                                        LEFT JOIN RBIM.Dim_store ds ( NOLOCK ) ON ds.storeidx = f.storeidx
                               WHERE    ds.StoreId IS NULL
                                        OR ( ds.StoreId = @StoreId
                                             AND ds.IsCurrentStore = 1
                                           )
                             )
                    SELECT TOP ( @Top )
                            s.* ,
                            DATEDIFF(DAY, s.FullDate, GETDATE()) AS DaysSinceLastSold
                    FROM    ( 
							-- find articles that have been sold in given period (@zeroSale = 0)
                              SELECT    s.* ,
                                        ls.FullDate
                              FROM      Sales s
                                        LEFT JOIN LastSold ls ON ls.ArticleId = s.ArticleId
                              WHERE     ls.rn = 1
                                        AND @ZeroSale = 0
										--Filter on article selection
                                        AND ( @ArticleSelection IS NULL
                                              OR s.ArticleID IN ( SELECT
                                                              ArticleId
                                                              FROM
                                                              @articles )
                                            )
                              UNION

							--find articles that have not been sold in given period (@zeroSale = 1)
                              SELECT    da.ArticleName ,
                                        da.ArticleId ,
                                        s.SupplierArticleId ,
                                        da.Lev2ArticleHierarchyName ,
                                        NULL AS NoOfArticlesSold ,
                                        NULL AS Revenue ,
                                        NULL AS GrossProfit ,
                                        ls.FullDate
                              FROM      LastSold ls
                                        LEFT JOIN Sales s ON ls.ArticleId = s.ArticleId
                                        JOIN RBIM.Dim_Article da ON da.ArticleId = ls.ArticleId
                                        LEFT JOIN RBIM.Dim_Supplier dsup ON dsup.SupplierIdx = ls.SupplierIdx
                                        LEFT JOIN VBDCM.dbo.SupplierArticles supa ( NOLOCK ) ON supa.ArticleNo = da.ArticleNo
                                                              AND supa.SupplierNo = dsup.SupplierNo
                              WHERE     ls.rn = 1
                                        AND s.ArticleId IS NULL
                                        AND da.isCurrent = 1
                                        AND da.ArticleIdx > -1
                                        AND @ZeroSale = 1
										--Filter on article selection
                                        AND ( @ArticleSelection IS NULL
                                              OR ls.ArticleID IN ( SELECT
                                                              ArticleId
                                                              FROM
                                                              @articles )
                                            )
                            ) s
                    ORDER BY s.ArticleName  --s.Lev2ArticleHierarchyName ,

            END						-- 1=PickAndCollect END

        IF ( @WhichSales = 2 )		-- 2=all sales except pick and collect
            BEGIN

;WITH Sales AS (
SELECT  
SALES.ArticleName,
SALES.ArticleId,
SALES.SupplierArticleId,
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
	JOIN RBIM.Dim_TransType (NOLOCK) tt ON tt.TransTypeIdx = Se.TransTypeIdx
	JOIN RBIM.Dim_Date dd (NOLOCK) ON dd.dateidx = se.receiptdateidx
	JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = se.storeidx
	WHERE ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1
	AND tt.transtypeId = 90403									
	AND se.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx	
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
		FLOOR(f.ReceiptIdx/1000) AS ReceiptHeadIdx,
		da.ArticleId,
		da.ArticleName,
		da.Lev2ArticleHierarchyId,
		da.Lev2ArticleHierarchyName,
		NULL AS SupplierArticleId, --supa.SupplierArticleID AS SupplierArticleId,
		SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		SUM(f.SalesAmount+f.ReturnAmount) AS Revenue,
		SUM(f.SalesAmount+f.ReturnAmount) - SUM(f.NetPurchasePrice)  AS GrossProfit
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
	JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
	JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
	--JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
	--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
	WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
	AND ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1								
	GROUP BY FLOOR(f.ReceiptIdx/1000) ,da.Lev2ArticleHierarchyId, da.Lev2ArticleHierarchyName, da.ArticleName, da.ArticleId--, supa.SupplierArticleID
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
GROUP BY 
SALES.ArticleName, SALES.ArticleId, SALES.Lev2ArticleHierarchyName, SALES.SupplierArticleId
HAVING SUM(Revenue) <> 0

),
PCSales
                          AS ( SELECT   ArticleName ,
                                        ArticleId ,
                                        SupplierArticleId ,
                                        Lev2ArticleHierarchyName ,
                                        SUM(NoOfArticlesSold) AS NoOfArticlesSold ,
                                        SUM(Revenue) AS Revenue ,
                                        SUM(Revenue - PurchasePrice) AS GrossProfit
                               FROM     ( SELECT    da.ArticleName ,
                                                    da.ArticleId ,
                                                    NULL AS SupplierArticleId ,
                                                    NULL AS Lev2ArticleHierarchyName ,
                                                    apcol.ReceivedQty AS NoOfArticlesSold ,
                                                    apcol.ArticleDeliveredPrice AS Revenue ,
                                                    PurchasePrice = (
SELECT TOP 1 f.NetPurchasePrice FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
JOIN RBIM.Dim_Article da2 (NOLOCK) ON da2.ArticleIdx = f.ArticleIdx
JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
--JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = f.SupplierIdx
--LEFT JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND ds.StoreId = @StoreId
AND ds.IsCurrentStore = 1
AND da.ArticleIdx =  da2.ArticleIdx
ORDER BY f.ReceiptDateIdx DESC
													)
                                          FROM      CBIM.Agg_PickAndCollectOrders apco
                                                    INNER JOIN CBIM.Agg_PickAndCollectOrderLines apcol ( NOLOCK ) ON apcol.OrderID = apco.OrderID
                                                    INNER JOIN RBIM.Dim_Gtin dg ( NOLOCK ) ON dg.Gtin = apcol.ArticleEan
                                                              AND dg.StatusId = 1	--1=Aktiv,9=Slettet ...
                                                    INNER JOIN RBIM.Cov_ArticleGtin ag ( NOLOCK ) ON ag.GtinIdx = dg.GtinIdx
                                                    INNER JOIN RBIM.Dim_Article da ( NOLOCK ) ON da.ArticleIdx = ag.ArticleIdx
                                                              AND da.isCurrent = 1
                                                    INNER JOIN VBDCM..AllArticles
                                                    AS AA ON AA.ArticleID = da.ArticleId
                                                    INNER JOIN RBIM.Dim_store ds ( NOLOCK ) ON ds.Storeid = apco.StoreId 
													--INNER JOIN RBIM.Dim_Supplier sup (NOLOCK) ON sup.SupplierIdx = da.
													--inner JOIN VBDCM.dbo.SupplierArticles supa (NOLOCK) ON supa.ArticleNo = da.ArticleNo AND supa.SupplierNo = sup.SupplierNo
                                          WHERE     1 = 1
                                                    AND ds.StoreId = @StoreId
                                                    AND ds.isCurrent <> 0
                                                    AND CONVERT(DATE, apco.PaymentSuccessTimeStamp, 103) BETWEEN CONVERT(DATE, @DateFrom, 103)
                                                    AND CONVERT(DATE, @DateTo, 103)
                                                    AND ( @ReportType = 0								-- all flights
                                                          OR ( @ReportType = 1
                                                              AND apco.FlightDirection = 'D'
                                                             )	-- departure flights
                                                          OR ( @ReportType = 2
                                                              AND apco.FlightDirection = 'A'
                                                             )	-- arrival flights
                                                          OR ( @ReportType = 3
                                                              AND apco.FlightDirection = ''
                                                             )	-- extra flights
                                                        )
                                                    AND apcol.ArticleDeliveredPrice <> 0
                                        ) AS Sales
                               GROUP BY ArticleName ,
                                        ArticleId ,
                                        SupplierArticleId ,
                                        Lev2ArticleHierarchyName
                             )
,LastSold AS (
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
--Salg minus P&C
SELECT TOP (@Top)
	s.*,
	DATEDIFF(DAY, s.FullDate, GETDATE()) AS DaysSinceLastSold 
FROM ( 
	-- find articles that have been sold in given period (@zeroSale = 0)
	SELECT 
		s.ArticleName
		,s.ArticleId
		,s.SupplierArticleId
		,s.Lev2ArticleHierarchyName
		,s.NoOfArticlesSold - p.NoOfArticlesSold AS NoOfArticlesSold 
		,s.Revenue - p.Revenue AS Revenue 
		,s.GrossProfit - p.GrossProfit AS GrossProfit
		,ls.FullDate
	FROM Sales s
	JOIN PCSales p ON p.ArticleId = s.ArticleId
	LEFT JOIN LastSold ls ON ls.ArticleId = s.ArticleId 
	WHERE 
	ls.rn = 1
	AND @ZeroSale = 0
	--Filter on article selection
   AND (@ArticleSelection IS NULL OR s.ArticleID IN (SELECT ArticleId FROM @articles))
   AND (s.NoOfArticlesSold - p.NoOfArticlesSold) <> 0

	UNION


	--find articles that have not been sold in given period (@zeroSale = 1)
	SELECT
		da.ArticleName,
		da.ArticleId,
		NULL AS SupplierArticleId,--s.SupplierArticleId,
		da.Lev2ArticleHierarchyName,	
		NULL AS NoOfArticlesSold,
		NULL AS Revenue,
		NULL AS GrossProfit,
		ls.FullDate
	FROM LastSold ls
	LEFT JOIN Sales s ON ls.ArticleId = s.ArticleId
	JOIN RBIM.Dim_Article da ON da.ArticleId = ls.ArticleId
	LEFT JOIN RBIM.Dim_Supplier dsup ON dsup.SupplierIdx = ls.SupplierIdx
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
ORDER BY  s.ArticleName --s.Lev2ArticleHierarchyName,

            END						-- 2=all sales except pick and collect END



    END




GO

