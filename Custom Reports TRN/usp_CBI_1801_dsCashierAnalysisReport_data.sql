USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1801_dsCashierAnalysisReport_data]    Script Date: 19.02.2020 10:42:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1801_dsCashierAnalysisReport_data]
(   
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@StoreId VARCHAR(100) 
) 
AS  
BEGIN
  
------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#ReceiptAnalysisPerCashier') IS NOT NULL DROP TABLE #ReceiptAnalysisPerCashier
IF OBJECT_ID('tempdb..#SalesFiguresPerCashier') IS NOT NULL DROP TABLE #SalesFiguresPerCashier
IF OBJECT_ID('tempdb..#TenderPerCashier') IS NOT NULL DROP TABLE #TenderPerCashier
IF OBJECT_ID('tempdb..#Calculations1') IS NOT NULL DROP TABLE #Calculations1
IF OBJECT_ID('tempdb..#Calculations2') IS NOT NULL DROP TABLE #Calculations2
IF OBJECT_ID('tempdb..#Calculations3') IS NOT NULL DROP TABLE #Calculations3
IF OBJECT_ID('tempdb..#Calculations4') IS NOT NULL DROP TABLE #Calculations4
IF OBJECT_ID('tempdb..#Calculations5') IS NOT NULL DROP TABLE #Calculations5

-- ReceiptAnalysisPerCashier
SELECT
	ds.StoreId
	,f.CashierUserIdx
	,SUM(f.SalesAmount + f.ReturnAmount) AS RevenueInclVat
	,ABS(SUM(f.ReturnAmount)) AS ReturnAmount
	,SUM(f.NumberOfSelectedCorrections + f.NumberOfLastCorrections) AS NumberOfCorrections
	,SUM(f.NumberOfReceiptsParked) AS NumberOfReceiptsParked
	,SUM(f.NumberOfReceiptsCanceled) AS NumberOfReceiptsCanceled
	,SUM(CASE WHEN f.CanceledReceiptsAmount IS NULL THEN 0 ELSE CanceledReceiptsAmount END) AS CanceledReceiptsAmount
	,SUM(f.NumberOfPriceInquiries) AS NumberOfPriceInquiries
INTO #ReceiptAnalysisPerCashier
FROM RBIM.Agg_CashierSalesAndReturnPerHour f (NOLOCK)
JOIN RBIM.Dim_Date dd (NOLOCK) on dd.DateIdx = f.ReceiptDateIdx 
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE  																																		
dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1  
GROUP BY ds.StoreId, f.CashierUserIdx 

-- SalesFiguresPerCashier
SELECT 
	ds.StoreId
	,f.CashierUserIdx
	,SUM(f.SalesAmount + f.ReturnAmount) AS RevenueInclVat
	,SUM(f.QuantityOfArticlesInReturn)  AS QuantityOfArticlesInReturn
	,ABS(SUM(f.ReturnAmount)) AS ReturnAmount
	,SUM(f.DiscountAmount) AS DiscountAmount
	,SUM(f.NumberOfCustomers) AS NumberOfCustomers
INTO #SalesFiguresPerCashier
FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
JOIN RBIM.Dim_Date dd (NOLOCK) on dd.DateIdx = f.ReceiptDateIdx 
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE  																																		
dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1   
GROUP BY ds.StoreId, f.CashierUserIdx 

-- TenderPerCashier
SELECT 
	ds.StoreId
	,f.CashierUserIdx
	,SUM(CASE WHEN t.TenderId = 1 THEN f.Amount ELSE 0 END) AS CashAmount
	,SUM(CASE WHEN t.TenderId = 3 THEN f.Amount ELSE 0 END) AS PaymentcardAmount
	,SUM(f.Amount) AS amount
INTO #TenderPerCashier
FROM RBIM.Fact_ReceiptTender f (NOLOCK)
JOIN RBIM.Dim_Tender t (NOLOCK) ON t.TenderIdx = f.TenderIdx
JOIN RBIM.Dim_Date dd (NOLOCK) on dd.DateIdx = f.ReceiptDateIdx 
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE  																																		
dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1   
GROUP BY ds.StoreId, f.CashierUserIdx
 
--Calculations for avg/min/max values are in the procedure. This is because jasper cannot know the avg/min/max value for the dataset at evaluation time now.

SELECT 
	r.StoreId
	,r.CashierUserIdx
	,CASE WHEN r.RevenueInclVat = 0.0 THEN 0.0 ELSE (t.CashAmount/CAST(r.RevenueInclVat AS DECIMAL)) END AS CashAmountPercentageShare
INTO #Calculations1
FROM #ReceiptAnalysisPerCashier r
JOIN #TenderPerCashier t ON t.StoreId = r.StoreId AND t.CashierUserIdx = r.CashierUserIdx 

SELECT 
	c.StoreId
	,SUM(s.NumberOfCustomers) AS NumberOfCustomers_sum
	,MIN(s.NumberOfCustomers) AS NumberOfCustomers_min
	,MAX(s.NumberOfCustomers) AS NumberOfCustomers_max
	,SUM(c.CashAmountPercentageShare)/COUNT(c.CashierUserIdx) AS CashAmountPercentageShare_avg
	,MIN(c.CashAmountPercentageShare) AS CashAmountPercentageShare_min
	,MAX(c.CashAmountPercentageShare) AS CashAmountPercentageShare_max
	,SUM(r.RevenueInclVat) AS RevenueInclVat_sum
	,SUM(s.QuantityOfArticlesInReturn) AS QuantityOfArticlesInReturn_sum
	,MIN(s.QuantityOfArticlesInReturn) AS QuantityOfArticlesInReturn_min
	,MAX(s.QuantityOfArticlesInReturn) AS QuantityOfArticlesInReturn_max
	,SUM(r.ReturnAmount) AS ReturnAmount_sum
	,MIN(r.ReturnAmount) AS ReturnAmount_min
	,MAX(r.ReturnAmount) AS ReturnAmount_max
	,SUM(s.DiscountAmount) AS DiscountAmount_sum
	,MIN(s.DiscountAmount) AS DiscountAmount_min
	,MAX(s.DiscountAmount) AS DiscountAmount_max
	,SUM(r.NumberOfCorrections) AS NumberOfCorrections_sum
	,MIN(r.NumberOfCorrections) AS NumberOfCorrections_min
	,MAX(r.NumberOfCorrections) AS NumberOfCorrections_max
	,SUM(r.NumberOfReceiptsParked) AS NumberOfReceiptsParked_sum
	,MIN(r.NumberOfReceiptsParked) AS NumberOfReceiptsParked_min
	,MAX(r.NumberOfReceiptsParked) AS NumberOfReceiptsParked_max
	,SUM(r.NumberOfReceiptsCanceled) AS NumberOfReceiptsCanceled_sum
	,MIN(r.NumberOfReceiptsCanceled) AS NumberOfReceiptsCanceled_min
	,MAX(r.NumberOfReceiptsCanceled) AS NumberOfReceiptsCanceled_max
	,SUM(r.CanceledReceiptsAmount) AS CanceledReceiptsAmount_sum
	,MIN(r.CanceledReceiptsAmount) AS CanceledReceiptsAmount_min
	,MAX(r.CanceledReceiptsAmount) AS CanceledReceiptsAmount_max
	,SUM(r.NumberOfPriceInquiries) AS NumberOfPriceInquiries_sum -- Missing measure added
	,MIN(r.NumberOfPriceInquiries) AS NumberOfPriceInquiries_min -- Missing measure added
	,MAX(r.NumberOfPriceInquiries) AS NumberOfPriceInquiries_max -- Missing measure added
INTO #Calculations2
FROM #ReceiptAnalysisPerCashier r
JOIN #SalesFiguresPerCashier s ON s.StoreId = r.StoreId AND s.CashierUserIdx = r.CashierUserIdx
JOIN #TenderPerCashier t ON t.StoreId = r.StoreId AND t.CashierUserIdx = r.CashierUserIdx 
JOIN #Calculations1 c ON c.StoreId = r.StoreId AND c.CashierUserIdx = r.CashierUserIdx
GROUP BY c.StoreId

SELECT 
	r.StoreId
	,r.CashierUserIdx
	,CASE WHEN c2.RevenueInclVat_sum = 0.0 THEN 0.0 ELSE (r.RevenueInclVat/CAST(c2.RevenueInclVat_sum AS DECIMAL)) END AS RevenueInclVat_share
	,r.RevenueInclVat*c2.CashAmountPercentageShare_avg AS TheoreticalCashAmount
INTO #Calculations3
FROM #ReceiptAnalysisPerCashier r
JOIN #Calculations1 c1 ON c1.CashierUserIdx = r.CashierUserIdx AND c1.StoreId = r.StoreId
JOIN #Calculations2 c2 ON c2.StoreId = r.StoreId

SELECT 
	c2.StoreId
	,c3.CashierUserIdx
	,t.CashAmount - c3.TheoreticalCashAmount AS CashAmount_EstimatedDeviation
	,CASE WHEN c2.QuantityOfArticlesInReturn_sum = 0 THEN 0 ELSE (s.QuantityOfArticlesInReturn/CAST(c2.QuantityOfArticlesInReturn_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS QuantityOfArticlesInReturn_deviation
	,CASE WHEN c2.ReturnAmount_sum = 0.0 THEN 0.0 ELSE (s.ReturnAmount/CAST(c2.ReturnAmount_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS ReturnAmount_deviation
	,CASE WHEN c2.DiscountAmount_sum = 0.0 THEN 0.0 ELSE (s.DiscountAmount/CAST(c2.DiscountAmount_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS DiscountAmount_deviation
	,CASE WHEN c2.NumberOfCorrections_sum = 0 THEN 0 ELSE (r.NumberOfCorrections/CAST(c2.NumberOfCorrections_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS NumberOfCorrections_deviation
	,CASE WHEN c2.NumberOfReceiptsParked_sum = 0 THEN 0 ELSE (r.NumberOfReceiptsParked/CAST(c2.NumberOfReceiptsParked_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS NumberOfReceiptsParked_deviation
	,CASE WHEN c2.NumberOfReceiptsCanceled_sum = 0 THEN 0 ELSE (r.NumberOfReceiptsCanceled/CAST(c2.NumberOfReceiptsCanceled_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS NumberOfReceiptsCanceled_deviation
	,CASE WHEN c2.CanceledReceiptsAmount_sum = 0.0 THEN 0.0 ELSE (r.CanceledReceiptsAmount/CAST(c2.CanceledReceiptsAmount_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS CanceledReceiptsAmount_deviation
	,CASE WHEN c2.NumberOfPriceInquiries_sum = 0 THEN 0 ELSE (r.NumberOfPriceInquiries/CAST(c2.NumberOfPriceInquiries_sum AS DECIMAL)) - c3.RevenueInclVat_share END AS NumberOfPriceInquiries_deviation
INTO #Calculations4
FROM #Calculations2 c2
JOIN #Calculations3 c3 ON c3.StoreId = c2.StoreId
JOIN #SalesFiguresPerCashier s ON s.StoreId = c3.StoreId AND s.CashierUserIdx = c3.CashierUserIdx
JOIN #TenderPerCashier t ON t.StoreId = s.StoreId AND t.CashierUserIdx = s.CashierUserIdx
JOIN #ReceiptAnalysisPerCashier r ON r.StoreId = s.StoreId AND r.CashierUserIdx = s.CashierUserIdx

SELECT 
	c4.StoreId
	,MIN(c4.CashAmount_EstimatedDeviation) AS CashAmount_EstimatedDeviation_min
	,MAX(c4.CashAmount_EstimatedDeviation) AS CashAmount_EstimatedDeviation_max
	,MIN(c4.QuantityOfArticlesInReturn_deviation) AS	QuantityOfArticlesInReturn_deviation_min
	,MAX(c4.QuantityOfArticlesInReturn_deviation) AS	QuantityOfArticlesInReturn_deviation_max
	,MIN(c4.ReturnAmount_deviation) AS ReturnAmount_deviation_min
	,MAX(c4.ReturnAmount_deviation) AS ReturnAmount_deviation_max
	,MIN(c4.DiscountAmount_deviation) AS DiscountAmount_deviation_min
	,MAX(c4.DiscountAmount_deviation) AS DiscountAmount_deviation_max
	,MIN(c4.NumberOfCorrections_deviation) AS NumberOfCorrections_deviation_min
	,MAX(c4.NumberOfCorrections_deviation) AS NumberOfCorrections_deviation_max
	,MIN(c4.NumberOfReceiptsParked_deviation) AS NumberOfReceiptsParked_deviation_min
	,MAX(c4.NumberOfReceiptsParked_deviation) AS NumberOfReceiptsParked_deviation_max
	,MIN(c4.NumberOfReceiptsCanceled_deviation) AS NumberOfReceiptsCanceled_deviation_min
	,MAX(c4.NumberOfReceiptsCanceled_deviation) AS NumberOfReceiptsCanceled_deviation_max
	,MIN(c4.CanceledReceiptsAmount_deviation) AS CanceledReceiptsAmount_deviation_min
	,MAX(c4.CanceledReceiptsAmount_deviation) AS CanceledReceiptsAmount_deviation_max
	,MIN(c4.NumberOfPriceInquiries_deviation) AS NumberOfPriceInquiries_deviation_min
	,MAX(c4.NumberOfPriceInquiries_deviation) AS NumberOfPriceInquiries_deviation_max
INTO #Calculations5
FROM #Calculations4 c4
GROUP BY c4.StoreId
---------------------------------------------------------------------------------------------------------------------------------------------
-- SELECT EVERYTHING
SELECT 
	r.StoreId
	,r.CashierUserIdx
	,u.LoginName
	,s.RevenueInclVat
	--,r.RevenueInclVat AS rev2
	,t.CashAmount
	,t.PaymentcardAmount
	,s.QuantityOfArticlesInReturn
	,s.ReturnAmount
	--,r.ReturnAmount AS ret2
	,s.DiscountAmount
	, 0 AS NumberOfPriceOverrides -- Missing measure
	, 0.0 AS PriceOverrideDiscountAmount -- Missing measure
	,r.NumberOfCorrections
	,r.NumberOfReceiptsParked
	, 0.0 AS ParkedReceiptsAmount -- Missing measure
	,r.NumberOfReceiptsCanceled
	,r.CanceledReceiptsAmount
	, 0 AS NumberOfDrawerOpenings -- Missing measure
	, 0 AS NumberOfReceiptsWithZeroSales -- Missing measure
	,r.NumberOfPriceInquiries  --0 AS NumberOfPriceInquiries -- Missing measure 01022019 A. added
	,s.NumberOfCustomers
	,c2.RevenueInclVat_sum
	,c2.NumberOfCustomers_sum
	,c2.NumberOfCustomers_min
	,c2.NumberOfCustomers_max
	,c.CashAmountPercentageShare
	,c2.CashAmountPercentageShare_avg
	,c2.CashAmountPercentageShare_min
	,c2.CashAmountPercentageShare_max
	,c3.TheoreticalCashAmount
	,c3.RevenueInclVat_share
	,c4.CashAmount_EstimatedDeviation
	,c5.CashAmount_EstimatedDeviation_min
	,c5.CashAmount_EstimatedDeviation_max
	,c2.QuantityOfArticlesInReturn_sum
	,c2.QuantityOfArticlesInReturn_min
	,c2.QuantityOfArticlesInReturn_max
	,c4.QuantityOfArticlesInReturn_deviation
	,c5.QuantityOfArticlesInReturn_deviation_min
	,c5.QuantityOfArticlesInReturn_deviation_max
	,c2.ReturnAmount_sum
	,c2.ReturnAmount_min
	,c2.ReturnAmount_max
	,c4.ReturnAmount_deviation
	,c5.ReturnAmount_deviation_min
	,c5.ReturnAmount_deviation_max
	,c2.DiscountAmount_sum
	,c2.DiscountAmount_min
	,c2.DiscountAmount_max
	,c4.DiscountAmount_deviation
	,c5.DiscountAmount_deviation_min
	,c5.DiscountAmount_deviation_max
	, 0 AS NumberOfPriceOverrides_sum -- Missing measure
	, 0 AS NumberOfPriceOverrides_min -- Missing measure
	, 0 AS NumberOfPriceOverrides_max -- Missing measure
	, 0.0 AS NumberOfPriceOverrides_deviation -- Missing measure
	, 0.0 AS NumberOfPriceOverrides_deviation_min -- Missing measure
	, 0.0 AS NumberOfPriceOverrides_deviation_max -- Missing measure
	, 0.0 AS PriceOverrideDiscountAmount_sum -- Missing measure
	, 0.0 AS PriceOverrideDiscountAmount_min -- Missing measure
	, 0.0 AS PriceOverrideDiscountAmount_max -- Missing measure
	, 0.0 AS PriceOverrideDiscountAmount_deviation -- Missing measure
	, 0.0 AS PriceOverrideDiscountAmount_deviation_min -- Missing measure
	, 0.0 AS PriceOverrideDiscountAmount_deviation_max -- Missing measure
	,c2.NumberOfCorrections_sum
	,c2.NumberOfCorrections_min
	,c2.NumberOfCorrections_max
	,c4.NumberOfCorrections_deviation
	,c5.NumberOfCorrections_deviation_min
	,c5.NumberOfCorrections_deviation_max
	,c2.NumberOfReceiptsParked_sum
	,c2.NumberOfReceiptsParked_min
	,c2.NumberOfReceiptsParked_max
	,c4.NumberOfReceiptsParked_deviation
	,c5.NumberOfReceiptsParked_deviation_min
	,c5.NumberOfReceiptsParked_deviation_max
	, 0.0 AS ParkedReceiptsAmount_sum -- Missing measure
	, 0.0 AS ParkedReceiptsAmount_min -- Missing measure
	, 0.0 AS ParkedReceiptsAmount_max -- Missing measure
	, 0.0 AS ParkedReceiptsAmount_deviation -- Missing measure
	, 0.0 AS ParkedReceiptsAmount_deviation_min -- Missing measure
	, 0.0 AS ParkedReceiptsAmount_deviation_max -- Missing measure
	,c2.NumberOfReceiptsCanceled_sum
	,c2.NumberOfReceiptsCanceled_min
	,c2.NumberOfReceiptsCanceled_max
	,c4.NumberOfReceiptsCanceled_deviation
	,c5.NumberOfReceiptsCanceled_deviation_min
	,c5.NumberOfReceiptsCanceled_deviation_max
	,c2.CanceledReceiptsAmount_sum
	,c2.CanceledReceiptsAmount_min
	,c2.CanceledReceiptsAmount_max
	,c4.CanceledReceiptsAmount_deviation
	,c5.CanceledReceiptsAmount_deviation_min
	,c5.CanceledReceiptsAmount_deviation_max
	, 0 AS NumberOfDrawerOpenings_sum -- Missing measure
	, 0 AS NumberOfDrawerOpenings_min -- Missing measure
	, 0 AS NumberOfDrawerOpenings_max -- Missing measure
	, 0.0 AS NumberOfDrawerOpenings_deviation -- Missing measure
	, 0.0 AS NumberOfDrawerOpenings_deviation_min -- Missing measure
	, 0.0 AS NumberOfDrawerOpenings_deviation_max -- Missing measure
	, 0 AS NumberOfReceiptsWithZeroSales_sum -- Missing measure
	, 0 AS NumberOfReceiptsWithZeroSales_min -- Missing measure
	, 0 AS NumberOfReceiptsWithZeroSales_max -- Missing measure
	, 0.0 AS NumberOfReceiptsWithZeroSales_deviation -- Missing measure
	, 0.0 AS NumberOfReceiptsWithZeroSales_deviation_min -- Missing measure
	, 0.0 AS NumberOfReceiptsWithZeroSales_deviation_max -- Missing measure
	, c2.NumberOfPriceInquiries_sum -- Missing measure added
	, c2.NumberOfPriceInquiries_min -- Missing measure added
	, c2.NumberOfPriceInquiries_max -- Missing measure added
	, c4.NumberOfPriceInquiries_deviation AS NumberOfPriceInquiries_deviation -- Missing measure added
	, c5.NumberOfPriceInquiries_deviation_min AS NumberOfPriceInquiries_deviation_min -- Missing measure added
	, c5.NumberOfPriceInquiries_deviation_max AS NumberOfPriceInquiries_deviation_max -- Missing measure added
FROM #ReceiptAnalysisPerCashier r
JOIN #SalesFiguresPerCashier s ON s.StoreId = r.StoreId AND s.CashierUserIdx = r.CashierUserIdx
JOIN #TenderPerCashier t ON t.StoreId = r.StoreId AND t.CashierUserIdx = r.CashierUserIdx 
JOIN RBIM.Dim_User (NOLOCK) u ON u.UserIdx = r.CashierUserIdx
JOIN #Calculations1 c ON c.StoreId = r.StoreId AND c.CashierUserIdx = r.CashierUserIdx
JOIN #Calculations2 c2 ON c2.StoreId = r.StoreId
JOIN #Calculations3 c3 ON c3.StoreId = r.StoreId AND c3.CashierUserIdx = r.CashierUserIdx
JOIN #Calculations4 c4 ON c4.StoreId = r.StoreId AND c4.CashierUserIdx = r.CashierUserIdx
JOIN #Calculations5 c5 ON c5.StoreId = r.StoreId 
ORDER BY u.LoginName




/*
;WITH ReceiptAnalysisPerCashier AS (
SELECT
	ds.StoreId
	,f.CashierUserIdx
	,SUM(f.SalesAmount + f.ReturnAmount) AS RevenueInclVat
	,SUM(f.ReturnAmount) AS ReturnAmount
	,SUM(f.NumberOfSelectedCorrections + f.NumberOfLastCorrections) AS NumberOfCorrections
	,SUM(f.NumberOfReceiptsParked) AS NumberOfReceiptsParked
	,SUM(f.NumberOfReceiptsCanceled) AS NumberOfReceiptsCanceled
FROM RBIM.Agg_CashierSalesAndReturnPerHour f (NOLOCK)
JOIN RBIM.Dim_Date dd (NOLOCK) on dd.DateIdx = f.ReceiptDateIdx 
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE  																																		
dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1  
GROUP BY ds.StoreId, f.CashierUserIdx 
)
,SalesFiguresPerCashier AS (
SELECT 
	ds.StoreId
	,f.CashierUserIdx
	,SUM(f.SalesAmount + f.ReturnAmount) AS RevenueInclVat
	,SUM(f.QuantityOfArticlesInReturn)  AS QuantityOfArticlesInReturn
	,SUM(f.ReturnAmount) AS ReturnAmount
	,SUM(f.DiscountAmount) AS DiscountAmount
	,SUM(f.NumberOfCustomers) AS NumberOfCustomers
FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
JOIN RBIM.Dim_Date dd (NOLOCK) on dd.DateIdx = f.ReceiptDateIdx 
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE  																																		
dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1   
GROUP BY ds.StoreId, f.CashierUserIdx 
)
, TenderPerCashier AS (
SELECT 
	ds.StoreId
	,f.CashierUserIdx
	,SUM(CASE WHEN t.TenderId = 1 THEN f.Amount ELSE 0 END) AS CashAmount
	,SUM(CASE WHEN t.TenderId = 3 THEN f.Amount ELSE 0 END) AS PaymentcardAmount
	,SUM(f.Amount) AS amount
FROM RBIM.Fact_ReceiptTender f (NOLOCK)
JOIN RBIM.Dim_Tender t (NOLOCK) ON t.TenderIdx = f.TenderIdx
JOIN RBIM.Dim_Date dd (NOLOCK) on dd.DateIdx = f.ReceiptDateIdx 
JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.storeidx = f.storeidx
WHERE  																																		
dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ds.StoreId = @StoreId
AND ds.isCurrentStore = 1   
GROUP BY ds.StoreId, f.CashierUserIdx
)
, Calculations AS (
SELECT 
	ds.StoreId,
	SUM(s.RevenueInclVat) AS RevenueInclVat_sum 
	FROM SalesFiguresPerCashier s 
	JOIN RBIM.Dim_Store ds ON ds.StoreId = s.StoreId
	GROUP BY ds.StoreId
)
SELECT 
	r.StoreId
	,r.CashierUserIdx
	,u.LoginName
	,s.RevenueInclVat
	,t.CashAmount
	,t.PaymentcardAmount
	,s.QuantityOfArticlesInReturn
	,s.ReturnAmount
	,s.DiscountAmount
	,'' AS NumberOfPriceOverrides
	,'' AS PriceOverrideDiscountAmount
	,r.NumberOfReceiptsParked
	,r.NumberOfReceiptsCanceled
	,'' AS NumberOfDrawerOpenings
	,'' AS NumberOfReceiptsWithZeroSales
	,'' AS NumberOfPriceInquiries
	,s.NumberOfCustomers
FROM ReceiptAnalysisPerCashier r
JOIN SalesFiguresPerCashier s ON s.StoreId = r.StoreId AND s.CashierUserIdx = r.CashierUserIdx
JOIN TenderPerCashier t ON t.StoreId = r.StoreId AND t.CashierUserIdx = r.CashierUserIdx 
JOIN RBIM.Dim_User (NOLOCK) u ON u.UserIdx = r.CashierUserIdx
JOIN Calculations c ON c.StoreId = r.StoreId
ORDER BY r.CashierUserIdx
*/

END


GO

