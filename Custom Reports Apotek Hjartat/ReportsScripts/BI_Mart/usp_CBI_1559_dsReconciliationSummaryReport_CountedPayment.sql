USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_CountedPayment]    Script Date: 10/3/2019 11:30:27 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 
CREATE   PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_CountedPayment]
(
@StoreId AS VARCHAR(100),
@Date AS DATETIME
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
			
		 DECLARE @DateIdx int = cast(convert(varchar(8),@Date, 112) as integer) -- Added for performance optimization (RS-34652)

		 DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		 SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		 WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		 );
		 SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
				 		
		-- Gather stores into temp table based on @IncludeInReportsCurrentStoreOnly parameter
		DROP TABLE IF EXISTS #Stores
			SELECT StoreIdx
			INTO #Stores
			FROM RBIM.Dim_Store
			WHERE (StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly = 0 OR (@IncludeInReportsCurrentStoreOnly = 1 AND IsCurrentStore = 1))) -- RS-42516	


		-- Get reconciliation date and ZNR per tender into temp table
		DROP TABLE IF EXISTS #ReconciliationDatePerTender
			SELECT DISTINCT 
				fc.[StoreIdx]
				,fc.[ZNR]
				,fc.ReconciliationDateIdx
			INTO #ReconciliationDatePerTender			
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender fc
			INNER JOIN #Stores ds ON ds.StoreIdx = fc.StoreIdx
			WHERE fc.ReconciliationDateIdx = @DateIdx			


		-- Get reconciliation tenders into temp table
		DROP TABLE IF EXISTS #ReconciliationTenders
			SELECT DISTINCT 
				fc.TenderIdx
			INTO #ReconciliationTenders 
			FROM RBIM.Fact_ReconciliationCountingPerTender fc
			INNER JOIN #ReconciliationDatePerTender rdt ON fc.StoreIdx = rdt.StoreIdx AND fc.ZNR = rdt.ZNR
			INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx


		-- Get reconciliation counted tenders into temp table
		DROP TABLE IF EXISTS #ReconciliationCountedTenders
			SELECT DISTINCT 
				fc.TenderIdx
				,MAX(fc.CountNo) AS CountNo
				,fc.ZNR
			INTO #ReconciliationCountedTenders 
			FROM RBIM.Fact_ReconciliationCountingPerTender fc
			INNER JOIN #ReconciliationDatePerTender rdt ON fc.StoreIdx = rdt.StoreIdx AND fc.ZNR = rdt.ZNR
			INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
			WHERE fc.NumberOfCountingsForAmount <> 0
			GROUP BY 
				fc.TenderIdx
				,fc.ZNR


		-- Get all manually counted Tenders
		DROP TABLE IF EXISTS #CountingPerTender
			SELECT 
				fc.StoreIdx
				,dt.TenderId
				,dt.TenderName
				,0 AS SumSystemAmount
				,SUM(ISNULL(fc.Amount, 0)) AS SumCountedAmount
				,0 AS Antal
			INTO #CountingPerTender
			FROM RBIM.Fact_ReconciliationCountingPerTender fc
			INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
			JOIN #ReconciliationDatePerTender trd ON fc.StoreIdx = trd.StoreIdx AND fc.ZNR = trd.ZNR
			JOIN #ReconciliationCountedTenders rct ON fc.TenderIdx = rct.TenderIdx AND fc.CountNo = rct.CountNo
			GROUP BY
				fc.StoreIdx
				,dt.TenderId
				,dt.TenderName


		-- Get all system counted Tenders (including system values for Tenders that has been counted manually if such exists)
		DROP TABLE IF EXISTS #ReceiptTender
		SELECT 
			t.StoreIdx
			,t.TenderId
			,t.TenderName
			,SUM(t.SumAmount) AS SumSystemAmount
			,0 AS SumCountedAmount
			,SUM(t.Antal) AS Antal	
		INTO #ReceiptTender
		FROM (
			SELECT
				fr.StoreIdx
				,dt.TenderId
				,dt.TenderName
				,SUM(ISNULL(fr.Amount, 0)) AS SumAmount
				,CASE WHEN fr.[Name] = 'Tender'
					THEN COUNT(dt.TenderIdx) 
					ELSE 0 
				END AS Antal
			FROM RBIM.Fact_ReceiptTender fr
			INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fr.TenderIdx
			INNER JOIN #Stores ds ON ds.StoreIdx = fr.StoreIdx			  
			JOIN #ReconciliationTenders rt ON fr.TenderIdx = rt.TenderIdx
			WHERE 
				fr.ReceiptDateIdx = @DateIdx
				AND fr.ReceiptStatusIdx = 1
			GROUP BY 
				fr.StoreIdx
				,dt.TenderName
				,dt.TenderId
				,fr.[Name]
		) t
		GROUP BY 
			t.StoreIdx
			,t.TenderName
			,t.TenderId


	-- Full outer join and then take all the goodies
	SELECT 
		CASE WHEN ct.StoreIdx IS NOT NULL
			THEN ct.StoreIdx
			ELSE rt.StoreIdx
		END AS StoreIdx,
		CASE WHEN ct.TenderId IS NOT NULL 
			THEN CONVERT(int, ct.TenderId)
			ELSE CONVERT(int, rt.TenderId)
		END AS TenderId,
		CASE WHEN ct.TenderName IS NOT NULL 
			THEN ct.TenderName
			ELSE rt.TenderName
		END AS TenderName,
		ISNULL(rt.SumSystemAmount, 0) AS SumSystemAmount,
		ISNULL(ct.SumCountedAmount, 0) AS SumCountedAmount,
		ISNULL(rt.Antal, 0) AS Antal
	FROM #CountingPerTender ct
	FULL OUTER JOIN #ReceiptTender rt ON ct.StoreIdx = rt.StoreIdx AND ct.TenderId = rt.TenderId
	ORDER BY 2

	-- Clean temp table cache after general dataset is selected 
	DROP TABLE IF EXISTS #Stores
	DROP TABLE IF EXISTS #ReconciliationDatePerTender
	DROP TABLE IF EXISTS #ReconciliationTenders
	DROP TABLE IF EXISTS #ReconciliationCountedTenders
	DROP TABLE IF EXISTS #CountingPerTender
	DROP TABLE IF EXISTS #ReceiptTender

	END
END  
GO


