USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_PaymentCardDetails]    Script Date: 14.09.2017 08:15:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_PaymentCardDetails]     
(
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME )
AS  
BEGIN 
-- 14.09.2017: Taken from usp_RBI_0559_dsReconciliationSummaryReport_PaymentCardDetails and added daterange instead of date.
  -----------------------------------------

DECLARE @DateFromIdx integer = CAST(CONVERT(varchar(8),@DateFrom,112) as integer)
DECLARE @DateToIdx integer = CAST(CONVERT(varchar(8),@DateTo,112) as integer)
DECLARE @NextToDateIdx integer = CAST(CONVERT(varchar(8),DATEADD(dd,1,@DateTo),112) as integer)


;WITH ReceiptTender AS (
SELECT 
	CASE WHEN dst.SubTenderId IN (4,14) THEN 'Mastercard' -- slå sammen Maestro og Eurocard til Mastercard
	ELSE ISNULL(dst.SubTenderName,'N/A') END AS BankCardName
	,SUM(frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0)) AS BankCardAmount
	,COUNT(DISTINCT frt.ReceiptId) AS BankCardCount
FROM RBIM.Fact_ReceiptTender frt
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = frt.StoreIdx	
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = frt.TenderIdx
	JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = frt.SubTenderIdx
WHERE 
	ds.StoreId = @StoreId
	AND ds.isCurrentStore = 1 
	AND frt.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
	AND dt.TenderId  in (3,5) -- kort og reserveløsning
GROUP BY  CASE WHEN dst.SubTenderId IN (4,14) THEN 'Mastercard'
				ELSE ISNULL(dst.SubTenderName,'N/A') END
) 
,EftSettlements AS (
	SELECT
	CASE WHEN dst.SubTenderId IN (4,14) THEN 'Mastercard'
			ELSE ISNULL(dst.SubTenderName,'N/A') END AS BankCardName -- slå sammen Maestro og Eurocard til Mastercard
	,SUM(NumberOfTransactions) AS BankCardCount
	,SUM(TransferedAmount) AS BankCardAmount
	FROM RBIM.Fact_EftSettlement (NOLOCK) fc
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = fc.StoreIdx	
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
	JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = fc.SubTenderIdx
	WHERE 
	ds.StoreId = @StoreId
	AND ds.isCurrentStore = 1 
	AND ((fc.ReceiptDateIdx = @DateFromIdx AND fc.ReceiptTimeIdx >= 0100) 
	OR ((fc.ReceiptDateIdx > @DateFromIdx) AND (fc.ReceiptDateIdx <= @DateToIdx))
	OR (fc.ReceiptDateIdx = @NextToDateIdx AND fc.ReceiptTimeIdx < 0100 )) --Bankavstemning går klokken 00.00 for TRN, derfor ta med (dagens dato - første time) + (første time i neste dato) så riktig bankavstemning kommer på rapporten.
	AND fc.EftSettlementTypeIdx = 1  -- 1=Bank, 2=Mobile, 3= Bank Reserve. Reserveløsning fra kasse og fra Bankavstemning. For å unngå duplikater fjern den fra kassen.
	AND dt.TenderId  in (3) --kort 
	GROUP BY CASE WHEN dst.SubTenderId IN (4,14) THEN 'Mastercard'
					ELSE ISNULL(dst.SubTenderName,'N/A') END
 )

	SELECT 
	COALESCE(e.BankCardName,rt.BankCardName) AS BankCardName
	,e.BankCardCount AS RegisteredByBankCount
	,e.BankCardAmount AS RegisteredByBankAmount
	,rt.BankCardCount AS RegisteredByPosReceiptCount
	,rt.BankCardAmount AS RegisteredByPosReceiptAmount
	FROM EftSettlements e 
	FULL OUTER JOIN ReceiptTender rt ON e.BankCardName = rt.BankCardName
	ORDER BY COALESCE(e.BankCardName,rt.BankCardName)

	end
GO


