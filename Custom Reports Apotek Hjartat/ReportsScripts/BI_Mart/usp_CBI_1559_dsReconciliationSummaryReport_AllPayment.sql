USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_AllPayment]    Script Date: 10/3/2019 11:34:59 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_AllPayment]
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


		-- Get reconciliation tenders yhat has been counted by cashier into temp table
		DROP TABLE IF EXISTS #ReconciliationTenders
			SELECT DISTINCT 
				fc.TenderIdx
			INTO #ReconciliationTenders 
			FROM RBIM.Fact_ReconciliationCountingPerTender fc
			INNER JOIN #ReconciliationDatePerTender rdt ON fc.StoreIdx = rdt.StoreIdx AND fc.ZNR = rdt.ZNR
			INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx


		-- Get all system counted Tenders (including system values for Tenders that has been counted manually if such exists)
		SELECT 
			t.StoreIdx
			,SUM(t.SumAmount) AS SumSystemAmount
			,SUM(t.Antal) AS Antal	
		FROM (
			SELECT
				fr.StoreIdx
				,dt.TenderId
				,CASE WHEN fr.TenderIdx = 18
					THEN -SUM(ISNULL(fr.Amount, 0))
					ELSE SUM(ISNULL(fr.Amount, 0)) 
				END AS SumAmount
				,CASE WHEN fr.[Name] = 'Tender'					
					THEN COUNT(dt.TenderIdx) 					
					ELSE 0 				
				END AS Antal
			FROM RBIM.Fact_ReceiptTender fr
			INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fr.TenderIdx
			INNER JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = fr.SubTenderIdx
			INNER JOIN #Stores ds ON ds.StoreIdx = fr.StoreIdx			  
			WHERE 
				fr.ReceiptDateIdx = @DateIdx
				AND fr.ReceiptStatusIdx = 1
				AND fr.TenderIdx NOT IN (53) -- Exclude ReceptPåse
			GROUP BY 
				fr.StoreIdx
				,dt.TenderId
				,fr.TenderIdx
				,fr.SubTenderIdx
				,fr.[Name]
			) t
		GROUP BY 
			t.StoreIdx
		ORDER BY 2

	-- Clean temp table cache after general dataset is selected 
	DROP TABLE IF EXISTS #Stores
	DROP TABLE IF EXISTS #ReconciliationDatePerTender
	DROP TABLE IF EXISTS #ReconciliationTenders

	END
END  
GO


