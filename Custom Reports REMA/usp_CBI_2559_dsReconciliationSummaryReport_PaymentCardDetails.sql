USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_PaymentCardDetails]    Script Date: 29.06.2020 15:28:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_PaymentCardDetails]     
(
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME ,
	@TenderSelection AS INT = 3
)
AS  
BEGIN

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	
	IF (@Date IS NULL)
	BEGIN
		SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
	END
	ELSE BEGIN 
 
	------ PARAMETERS ----------
	
	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
	SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
	WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
	);
	SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		
	-- Generate Eft date from/to for 00:00:01 to 23:59:59 of the @Date day
	DECLARE @EftDateFrom DATETIME = dateadd(ss, 1, dateadd(day, datediff(day, 0,  @Date), 0))
	DECLARE @EftDateTo DATETIME = dateadd(ss, -1, dateadd(day, datediff(day, 0,  @Date)+1, 0))	

	-- Gather stores into temp table based on @IncludeInReportsCurrentStoreOnly parameter
	DROP TABLE IF EXISTS #Stores
		SELECT StoreIdx
		INTO #Stores
		FROM RBIM.Dim_Store
		WHERE (StoreId = @StoreId
			AND (@IncludeInReportsCurrentStoreOnly = 0 OR (@IncludeInReportsCurrentStoreOnly = 1 AND IsCurrentStore = 1)))
	
	-- Get tender selection information into temp table	
	DROP TABLE IF EXISTS #TenderSelection
		SELECT 
				tc.TenderIdx				 
		INTO #TenderSelection
		FROM [RBIM].Cov_TenderSelection tc 
		inner join [RBIM].Dim_TenderSelection ts on tc.TenderSelectionIdx=ts.TenderSelectionIdx  
		where ts.TenderSelectionId = @TenderSelection

	-- Gather dates and transaction info from Fact_EftSettlement 
	DROP TABLE IF EXISTS #EftLookup
		SELECT
			DISTINCT
			--ISNULL(dst.SubTenderName,'N/A') AS BankCardName
			CASE WHEN fc.TenderIdx IN ('14') THEN 'Manuell Bank' ELSE ISNULL(dst.SubTenderName,'N/A') END  AS BankCardName
			,NumberOfTransactions 
			,TransferedAmount
			,EftPeriodStartDateTime
			,EftPeriodEndDateTime
		INTO #EftLookup
		FROM RBIM.Fact_EftSettlement fc
			INNER JOIN #Stores ds ON ds.StoreIdx = fc.StoreIdx	
			INNER JOIN #TenderSelection ts ON fc.TenderIdx = ts.TenderIdx 
			INNER JOIN [RBIM].[Dim_EftSettlementType] est  on fc.[EftSettlementTypeIdx]=est.[EftSettlementTypeIdx] --{RS-33385}	
			LEFT JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = fc.SubTenderIdx
		WHERE
		est.EftSettlementTypeId = 1 --in(1/*Bank*//*,2 --Mobile,3 --ReserveBank*/) --{RS-33385}	
		AND (@EftDateFrom <= EftPeriodStartDateTime AND @EftDateTo  >=  EftPeriodStartDateTime)
		--AND fc.ReceiptDateIdx in (SELECT dd.DateIdx FROM  RBIM.Dim_Date AS dd WHERE dd.FullDate=@Date) --missing EftPeriodStartDateTime

	-- Generate Receipt tender Date From/To based on what we get from Fact_EftSettlement table
	DECLARE @ReceiptTenderDatetimeFrom DATETIME
	DECLARE @ReceiptTenderDatetimeTo DATETIME
		
	SET @ReceiptTenderDatetimeFrom = (SELECT MIN(EftPeriodStartDateTime) FROM #EftLookup) 
	SET @ReceiptTenderDatetimeTo = (SELECT MAX(EftPeriodEndDateTime) FROM #EftLookup) 

	-- Generate date idx'es for better performance
	DECLARE @DateIdxFrom INT = CAST(REPLACE(CAST(CAST(@ReceiptTenderDatetimeFrom AS DATE) AS VARCHAR(10)) , '-' ,'') AS INT)
	DECLARE @TimeIdxFrom INT = CAST(REPLACE(LEFT(CAST(CAST(@ReceiptTenderDatetimeFrom AS time(0)) AS VARCHAR(10)),5) , ':' ,'') AS INT)

	DECLARE @DateIdxTo INT = CAST(REPLACE(CAST(CAST(@ReceiptTenderDatetimeTo AS DATE) AS VARCHAR(10)) , '-' ,'') AS INT)
	DECLARE @TimeIdxTo INT = CAST(REPLACE(LEFT(CAST(CAST(@ReceiptTenderDatetimeTo AS time(0)) AS VARCHAR(10)),5) , ':' ,'') AS INT)		
	
	-- Get tender lookup values	into temp table
	DROP TABLE IF EXISTS #ReceiptTenderLookup;
		SELECT				
			--ISNULL(dst.SubTenderName,'N/A') AS BankCardName
			CASE WHEN rt.TenderIdx IN ('14') THEN 'Manuell Bank' ELSE ISNULL(dst.SubTenderName,'N/A') END  AS BankCardName
			,SUM(rt.Amount) AS BankCardAmount
			,SUM(rt.CashFee) AS CashFee
			,SUM(rt.Surcharge) AS Surcharge
			,sum(rt.NumberOfTransactions) AS BankCardCount
		INTO
			#ReceiptTenderLookup
		FROM
			RBIM.Agg_ReceiptTenderDaily AS RT
			INNER JOIN #Stores ds ON ds.StoreIdx = RT.StoreIdx
			INNER JOIN #TenderSelection ts ON RT.TenderIdx = ts.TenderIdx
			LEFT JOIN RBIM.Dim_SubTender dst ON RT.SubTenderIdx = dst.SubTenderIdx
		WHERE 1=1 --RT.ReceiptStatusIdx = 1 --n/a
			--AND RT.ReceiptDateIdx in (SELECT dd.DateIdx FROM  RBIM.Dim_Date AS dd WHERE dd.FullDate=@Date) --missing EftPeriodStartDateTime
			AND	(((RT.ReceiptDateIdx = @DateIdxFrom AND RT.ReceiptTimeIdx >= @TimeIdxFrom) --{RS-39056}
				OR (RT.ReceiptDateIdx = @DateIdxTo AND RT.ReceiptTimeIdx <= @TimeIdxTo))
				OR (RT.ReceiptDateIdx > @DateIdxFrom AND RT.ReceiptDateIdx < @DateIdxTo))				
		--GROUP BY dst.SubTenderId, ISNULL(dst.SubTenderName,'N/A')
		GROUP BY CASE WHEN rt.TenderIdx IN ('14') THEN 'Manuell Bank'	ELSE ISNULL(dst.SubTenderName,'N/A') END
		OPTION (Recompile)

	;with EftSettlements AS (
		SELECT
			 BankCardName
			,SUM(NumberOfTransactions) AS BankCardCount
			,SUM(TransferedAmount) AS BankCardAmount
		FROM #EftLookup fc			
		GROUP BY BankCardName
	)

	---- GENERAL DATASET -----
		SELECT 
		COALESCE(e.BankCardName,rt.BankCardName) AS BankCardName
		,e.BankCardCount AS RegisteredByBankCount
		,e.BankCardAmount AS RegisteredByBankAmount
		,rt.BankCardCount AS RegisteredByPosReceiptCount
		,rt.BankCardAmount AS RegisteredByPosReceiptAmount
		,rt.CashFee AS RegisteredByPosCashFeeAmount
		,rt.Surcharge AS RegisteredByPosSurchargeAmount
		FROM EftSettlements e 
		FULL OUTER JOIN #ReceiptTenderLookup rt ON e.BankCardName = rt.BankCardName
		ORDER BY COALESCE(e.BankCardName,rt.BankCardName)
		
	-- Clean temp table cache after general dataset is selected 

		DROP TABLE IF EXISTS #Stores
		DROP TABLE IF EXISTS #TenderSelection
		DROP TABLE IF EXISTS #EftLookup
		DROP TABLE IF EXISTS #ReceiptTenderLookup

	END
END 



GO

