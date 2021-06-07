USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1181_dsQuantityFiguresReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1181_dsQuantityFiguresReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1181_dsQuantityFiguresReport_data]
(   
   @StoreId AS VARCHAR(100),
	@DateFrom AS DATE, 
	@DateTo AS DATE,
	@ReportType SMALLINT -- 0 all flights, 1 departure, 2 arrival--, 3 extra
) 
AS  
BEGIN
  
------------------------------------------------------------------------------------------------------
DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer)
DECLARE @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer)

select 
--FLIGHT.FlightType, 
CASE WHEN NumOfHierarchyLevels >= 2 THEN  SALES.Lev2ArticleHierarchyId
		ELSE CASE WHEN	NumOfHierarchyLevels = 1 THEN SALES.ArticleHierarchyId 
				ELSE 'Ukjent' END 
		END AS ArticleHierarchyId, 
CASE WHEN NumOfHierarchyLevels >= 2 THEN  SALES.Lev2ArticleHierarchyName
		ELSE CASE WHEN	NumOfHierarchyLevels = 1 THEN SALES.ArticleHierarchyName
				ELSE 'Ukjent' END 
		END AS ArticleHierarchyName,
SUM(NoOfArticlesSold) as NoOfArticlesSold,
SUM(UnitsSold) AS UnitsSold,
SUM(Revenue) as Revenue,
SUM(RevenueInclVat) as RevenueInclVat

from 
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
AND tt.transtypeId = 90403									
AND se.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
AND ds.StoreId = @StoreId
AND (	@ReportType = 0 -- all flights
			OR (@ReportType = 1 AND (se.TransTypeValueTxt4 = 'D' OR se.TransTypeValueTxt1 = 'AVN001')) -- departure flights
			OR (@ReportType = 2 AND (se.TransTypeValueTxt4 = 'A' OR se.TransTypeValueTxt1 = 'AVN000')) -- arrival flights
			--OR (@ReportType = 3 AND se.TransTypeValueTxt4 = '') -- extra flights
	 )

) FLIGHT
INNER JOIN 
(
SELECT 
	FLOOR(f.ReceiptIdx/1000) as ReceiptHeadIdx,
	da.Lev1ArticleHierarchyId   AS ArticleHierarchyId, 
	da.Lev1ArticleHierarchyName AS ArticleHierarchyName,
	da.Lev2ArticleHierarchyId AS Lev2ArticleHierarchyId, 
	da.Lev2ArticleHierarchyName AS Lev2ArticleHierarchyName,
	da.NumOfHierarchyLevels,
	SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
	SUM((f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)*da.UnitOfMeasurementAmount) AS UnitsSold,
	SUM(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS Revenue,
	SUM(f.SalesAmount+f.ReturnAmount) AS RevenueInclVat

FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE f.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
AND ds.StoreId = @StoreId								
GROUP BY FLOOR(f.ReceiptIdx/1000) ,da.Lev1ArticleHierarchyId, da.Lev1ArticleHierarchyName, da.Lev2ArticleHierarchyId, da.Lev2ArticleHierarchyName, da.NumOfHierarchyLevels
) SALES
ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx 
GROUP BY 
--FLIGHT.FlightType,  
CASE WHEN NumOfHierarchyLevels >= 2 THEN  SALES.Lev2ArticleHierarchyId
		ELSE CASE WHEN	NumOfHierarchyLevels = 1 THEN SALES.ArticleHierarchyId 
				ELSE 'Ukjent' END 
		END,
CASE WHEN NumOfHierarchyLevels >= 2 THEN  SALES.Lev2ArticleHierarchyName
		ELSE CASE WHEN	NumOfHierarchyLevels = 1 THEN SALES.ArticleHierarchyName
				ELSE 'Ukjent' END 
		END
HAVING SUM(RevenueInclVat) <> 0
ORDER BY ArticleHierarchyId 
END