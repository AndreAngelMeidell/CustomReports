USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1185_dsReconciliationSummaryReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1185_dsReconciliationSummaryReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1185_dsReconciliationSummaryReport_data]
(   
    @StoreId AS VARCHAR(100), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME

) 
AS  
BEGIN
  
------------------------------------------------------------------------------------------------------
-- debug
--DECLARE @storeId INT = 9998, @dateFrom DATE = '2016-10-01', @dateTo DATE = '2016-12-12'

DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer)
DECLARE @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer)

SELECT 
dd.FullDate,
ACCOUNTING.ZNR AS znr,
TENDER.RevenueInclVat,
TENDER.PaymentCardAmount,
TENDER.PaymentCardReserve,
TENDER.CashAmount,
VAT.Revenue_0,
VAT.Revenue_15,
VAT.SalesVatAmount_15,
VAT.Revenue_25,
VAT.SalesVatAmount_25
FROM (
		SELECT  
			f.ReceiptDateIdx,
			SUM(CASE WHEN f.VatGroup = 0 THEN f.SalesAmountExclVat+f.ReturnAmountExclVat+f.RoundingAmount ELSE 0 END) AS Revenue_0,
			SUM(CASE WHEN f.VatGroup = 0 THEN f.SalesVatAmount+f.ReturnVatAmount ELSE 0 END) AS SalesVatAmount_0,
			SUM(CASE WHEN f.VatGroup = 15 THEN f.SalesAmountExclVat+f.ReturnAmountExclVat+f.RoundingAmount ELSE 0 END) AS Revenue_15,
			SUM(CASE WHEN f.VatGroup = 15 THEN f.SalesVatAmount+f.ReturnVatAmount ELSE 0 END) AS SalesVatAmount_15,
			SUM(CASE WHEN f.VatGroup = 25 THEN f.SalesAmountExclVat+f.ReturnAmountExclVat+f.RoundingAmount ELSE 0 END) AS Revenue_25,
			SUM(CASE WHEN f.VatGroup = 25 THEN f.SalesVatAmount+f.ReturnVatAmount ELSE 0 END) AS SalesVatAmount_25
		FROM RBIM.Agg_VatGroupSalesAndReturnPerDay f
		JOIN RBIM.Dim_Store ds ON ds.StoreIdx = f.StoreIdx
		WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
		AND ds.StoreId = @storeId
		AND ds.IsCurrentStore = 1
		GROUP BY f.ReceiptDateIdx
		) VAT
	JOIN 
		( 
		SELECT 
				f.ReceiptDateIdx,
				SUM(f.Amount) AS RevenueInclVat,
				SUM(CASE WHEN dt.TenderId IN (1,8) THEN f.Amount ELSE 0 END) AS CashAmount,
				SUM(CASE WHEN dt.TenderId IN (3) THEN f.Amount ELSE 0 END) AS PaymentCardAmount,
				SUM(CASE WHEN dt.TenderId IN (5) THEN f.Amount ELSE 0 END) AS PaymentCardReserve
		FROM RBIM.Fact_ReceiptTender f
		JOIN RBIM.Dim_Store ds ON ds.StoreIdx = f.StoreIdx
		JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = f.TenderIdx
		WHERE f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
		AND ds.StoreId = @storeId
		AND ds.IsCurrentStore = 1
		GROUP BY f.ReceiptDateIdx
		) TENDER ON TENDER.ReceiptDateIdx = VAT.ReceiptDateIdx
	JOIN RBIM.Dim_Date dd ON TENDER.ReceiptDateIdx = dd.DateIdx
	LEFT JOIN 
		(
		SELECT 
			SettlementDate,
			MAX(ZNR) AS ZNR
		FROM BI_Export.CBIE.RBI_AccountingExportDataInterface
		WHERE SettlementDate BETWEEN @DateFrom AND @DateTo
		AND StoreId = @storeId
		GROUP BY SettlementDate
		) ACCOUNTING ON ACCOUNTING.SettlementDate = dd.FullDate
ORDER BY dd.FullDate 

END
