USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Bank]    Script Date: 15.05.2018 08:40:50 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Bank]     
(
	@StoreOrGroupNo AS VARCHAR(MAX),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME 
	)
AS  
BEGIN 

;WITH Stores AS (
SELECT DISTINCT ds.*	--(RS-27332)
FROM RBIM.Dim_Store ds
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1 AND ds.isCurrent=1)
,
ReceiptTender AS (
SELECT 
	 ISNULL(dst.SubTenderName,'N/A') AS BankCardName
	,SUM(frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0)) AS BankCardAmount
	,COUNT(DISTINCT frt.ReceiptId) AS BankCardCount
FROM RBIM.Fact_ReceiptTender frt
	JOIN Stores ds ON ds.StoreIdx = frt.StoreIdx	
	JOIN RBIM.Dim_Date dd ON dd.DateIdx = frt.ReceiptDateIdx	
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = frt.TenderIdx
	JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = frt.SubTenderIdx
WHERE 1=1 
	--AND ds.StoreId = @StoreOrGroupNo
	--AND ds.isCurrentStore = 1 
	AND dd.FullDate BETWEEN @DateFrom AND @DateTo
	AND dt.TenderId  IN ('3','14', '5') -- kort 
GROUP BY dst.SubTenderId, ISNULL(dst.SubTenderName,'N/A')
) 
,EftSettlements AS (
	SELECT
	ISNULL(dst.SubTenderName,'N/A') AS BankCardName
	,SUM(NumberOfTransactions) AS BankCardCount
	,SUM(TransferedAmount) AS BankCardAmount
	FROM RBIM.Fact_EftSettlement (NOLOCK) fc
	JOIN Stores ds ON ds.StoreIdx = fc.StoreIdx	
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
	JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = fc.SubTenderIdx
	JOIN RBIM.Dim_Date dd ON dd.DateIdx = fc.ReceiptDateIdx	
	WHERE 1=1
	--AND ds.StoreId = @StoreOrGroupNo
	--AND ds.isCurrentStore = 1 
	AND dd.FullDate BETWEEN @DateFrom AND @DateTo
	AND fc.EftSettlementTypeIdx != 3  -- 1=Bank, 2=Mobile, 3= Bank Reserve. Reserveløsning fra kasse og fra Bankavstemning. For å unngå duplikater fjern den fra kassen.
	AND fc.EftSettlementTypeIdx = 1
	AND dt.TenderId  IN ('3','14', '5') --kort
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

