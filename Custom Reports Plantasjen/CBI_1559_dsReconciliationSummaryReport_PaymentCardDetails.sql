USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_PaymentCardDetails]    Script Date: 21.06.2018 13:51:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_PaymentCardDetails]     
(
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME )
AS  
BEGIN 

  -----------------------------------------

DECLARE @DateIdx integer = CAST(CONVERT(varchar(8),@Date,112) as integer)
DECLARE @NextDateIdx integer = CAST(CONVERT(varchar(8),DATEADD(dd,1,@Date),112) as integer)

;WITH ReceiptTender AS (
SELECT 
	 ISNULL(dst.SubTenderName,'N/A') AS BankCardName
	,SUM(frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0)) AS BankCardAmount
	,COUNT(DISTINCT frt.ReceiptId) AS BankCardCount
FROM RBIM.Fact_ReceiptTender frt
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = frt.StoreIdx	
	JOIN RBIM.Dim_Date dd ON dd.DateIdx = frt.ReceiptDateIdx	
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = frt.TenderIdx
	JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = frt.SubTenderIdx
WHERE 
	ds.StoreId = @StoreId
	AND ds.isCurrentStore = 1 
	AND dd.FullDate = @Date	
	AND dt.TenderId  in ('3','14', '5') -- kort 
GROUP BY dst.SubTenderId, ISNULL(dst.SubTenderName,'N/A')
) 
,EftSettlements AS (
	SELECT
	ISNULL(dst.SubTenderName,'N/A') AS BankCardName
	,SUM(NumberOfTransactions) AS BankCardCount
	,SUM(TransferedAmount) AS BankCardAmount
	FROM RBIM.Fact_EftSettlement (NOLOCK) fc
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = fc.StoreIdx	
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
	JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = fc.SubTenderIdx
	WHERE 
	ds.StoreId = @StoreId
	AND ds.isCurrentStore = 1 
	AND (fc.ReceiptDateIdx = @DateIdx and fc.ReceiptTimeIdx >= 0100) OR (fc.ReceiptDateIdx = @NextDateIdx and fc.ReceiptTimeIdx < 0100 ) --Bankavstemning går klokken 00.00 for TRN, derfor ta med (dagens dato - første time) + (første time i neste dato) så riktig bankavstemning kommer på rapporten.
	--AND fc.EftSettlementTypeIdx != 3  -- 1=Bank, 2=Mobile, 3= Bank Reserve. Reserveløsning fra kasse og fra Bankavstemning. For å unngå duplikater fjern den fra kassen.
	AND fc.EftSettlementTypeIdx = 1
	AND dt.TenderId  in ('3','14', '5') --kort
	GROUP BY dst.SubTenderId, ISNULL(dst.SubTenderName,'N/A')
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

END 


GO

