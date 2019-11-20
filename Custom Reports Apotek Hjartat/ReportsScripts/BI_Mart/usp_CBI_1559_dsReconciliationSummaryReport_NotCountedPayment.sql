USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_NotCountedPayment]    Script Date: 10/3/2019 11:31:18 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE   PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_NotCountedPayment]
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


		-- Get system counted Accumulators and Tenders (excluding system values for Tenders that has been counted manually if such exists)
		SELECT 
			t.StoreIdx
			,t.SourceTypeId
			,CONVERT(int, t.TypeId) AS TypeId
			,t.TypeName
			,SUM(t.SumAmount) AS SumSystemAmount
			,SUM(t.Qty) AS Qty
		FROM (
			-- For Tender 23 "Kupong Betalning" we will use the conected Accumulators
			SELECT 
				fc.StoreIdx
				,1 AS SourceTypeId
				,dat.AccumulationId AS TypeId
				,dat.AccumulationTypeName AS TypeName
				,fc.Amount AS SumAmount
				,fc.[Count] AS Qty
			FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType fc
			JOIN RBIM.Dim_AccumulationType dat ON fc.AccumulationTypeIdx = dat.AccumulationTypeIdx
			INNER JOIN #Stores ds ON ds.StoreIdx = fc.StoreIdx
			WHERE fc.ReconciliationDateIdx = @DateIdx
				AND fc.AccumulationTypeIdx in (34) -- 34 = KI-coupon TODO: Add new AccumulationTypeIdx for Värdeavi when development (RSP-10689) is done
				AND fc.[Count] > 0

			UNION

			SELECT
				fr.StoreIdx
				,2 AS SourceTypeId
				,dt.TenderId AS TypeId
--				,fr.TenderIdx
				,CASE WHEN (fr.TenderIdx = 3 AND fr.SubTenderIdx in (99))
					THEN dst.SubTenderName
					ELSE dt.TenderName
				END AS TypeName
				,CASE WHEN fr.TenderIdx = 18
					THEN -SUM(ISNULL(fr.Amount, 0))
--					WHEN fr.TenderIdx = 6 THEN SUM(ISNULL(fc.Amount, 0))
					ELSE SUM(ISNULL(fr.Amount, 0)) 
				END AS SumAmount
				,CASE WHEN fr.[Name] = 'Tender'					
					THEN COUNT(dt.TenderIdx) 					
					ELSE 0 				
				END AS Qty
			FROM RBIM.Fact_ReceiptTender fr
			INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fr.TenderIdx
			INNER JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = fr.SubTenderIdx
			INNER JOIN #Stores ds ON ds.StoreIdx = fr.StoreIdx			  
			WHERE 
				fr.ReceiptDateIdx = @DateIdx
				AND fr.ReceiptStatusIdx = 1
				AND fr.TenderIdx NOT IN (SELECT DISTINCT TenderIdx FROM #ReconciliationTenders) -- This will get all tenders except the ones that has been counted by cashier
				AND fr.TenderIdx NOT IN (23, 53) -- Exclude "ReceptPåse" (53) and "Kupong Betalning" (23) The different "Kupong Betalning" is specified  in first select from Fact_ReconciliationSystemTotalPerAccumulationType 
				AND fr.TenderIdx NOT IN (-4) -- TODO! Take away this row when Developmet (RSP-10690) is done
			GROUP BY 
				fr.StoreIdx
				,dt.TenderId
				,fr.TenderIdx
				,fr.SubTenderIdx
				,dst.SubTenderName
				,dt.TenderName
				,fr.[Name]
			) t
		GROUP BY 
			t.SourceTypeId
			,t.StoreIdx
			,t.TypeName
			,t.TypeId
		ORDER BY 1, 3

	-- Clean temp table cache after general dataset is selected 
	DROP TABLE IF EXISTS #Stores
	DROP TABLE IF EXISTS #ReconciliationDatePerTender
	DROP TABLE IF EXISTS #ReconciliationTenders

	END
END  
GO


