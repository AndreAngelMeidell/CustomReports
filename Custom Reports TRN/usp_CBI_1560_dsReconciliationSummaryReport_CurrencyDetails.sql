USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_0559_dsReconciliationSummaryReport_CurrencyDetails]    Script Date: 14.09.2017 14:14:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



 
CREATE PROCEDURE [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_CurrencyDetails]     
(
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME )
AS  
BEGIN 
	-- 14.09.2017: Taken from usp_RBI_0559_dsReconciliationSummaryReport_CurrencyDetails and added daterange instead of date.
  -----------------------------------------
SELECT 
	dc.CurrencyCode
	,SUM(frt.CurrencyAmount) AS CurrenyAmount
	,frt.ExchangeRateToLocalCurrency
	,SUM(frt.Amount) AS NorwegianAmount
FROM RBIM.Fact_ReceiptTender frt
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = frt.StoreIdx	
	JOIN RBIM.Dim_Date dd ON dd.DateIdx = frt.ReceiptDateIdx	
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = frt.TenderIdx
	JOIN RBIM.Dim_Currency dc ON dc.CurrencyIdx = frt.CurrencyIdx
WHERE 
	ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1
	AND (dd.FullDate BETWEEN @DateFrom AND @DateTo)
	AND dt.tenderId = '8' --currency 
GROUP BY	dc.CurrencyCode, frt.ExchangeRateToLocalCurrency


END 
GO


