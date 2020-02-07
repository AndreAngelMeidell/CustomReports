USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_CurrencyDetails]    Script Date: 07.02.2020 10:39:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_CurrencyDetails]     
(
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME )
AS  
BEGIN 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	IF (@Date IS NULL)
	BEGIN
		SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
	END
	ELSE BEGIN

	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
	SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
	WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
	);
	SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		

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
		AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
		AND dd.FullDate = @Date
		AND dt.tenderId = '8' --currency 
	GROUP BY	dc.CurrencyCode, frt.ExchangeRateToLocalCurrency
	END

END 



GO

