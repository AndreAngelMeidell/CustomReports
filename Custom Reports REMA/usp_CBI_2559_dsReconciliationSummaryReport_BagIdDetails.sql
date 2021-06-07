USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_BagIdDetails]    Script Date: 07.02.2020 10:39:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_BagIdDetails]     
(
	@TotalTypeId AS INT ,	
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME )
AS  
BEGIN 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SET @TotalTypeId = 2 --RS-45270

	IF (@Date IS NULL)
	BEGIN
		SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
	END
	ELSE BEGIN 

		--Get last countings for given store, tender and totaltype
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
			WHERE (StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly = 0 OR (@IncludeInReportsCurrentStoreOnly = 1 AND IsCurrentStore = 1)))

		-- Get tender selection information into temp table	
		DROP TABLE IF EXISTS #TenderSelection
			SELECT A.TenderIdx
			INTO #TenderSelection
			FROM [RBIM].[Dim_Tender] AS A
			LEFT JOIN [RBIM].[Cov_TenderSelection] AS B	ON A.TenderIdx = B.TenderIdx 
			LEFT JOIN [RBIM].[Dim_TenderSelection] AS C	ON B.TenderSelectionIdx = C.TenderSelectionIdx 
			WHERE TenderSelectionName = 'Default Cash Tenders'		
	
		-- Get reconciliation date and ZNR information into temp table
		DROP TABLE IF EXISTS #ReconciliationDateZnr
			SELECT DISTINCT 
				st.ZNR, 
				st.StoreIdx, 
				st.TotalTypeIdx 
			INTO #ReconciliationDateZnr
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender st
			INNER JOIN #Stores ds ON ds.StoreIdx = st.StoreIdx
			INNER JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = st.TotalTypeIdx	
			INNER JOIN #TenderSelection dt ON dt.TenderIdx = st.TenderIdx
			WHERE st.ReconciliationDateIdx = @DateIdx AND dtt.TotalTypeId = @TotalTypeId 
		
		-- Get last reconciliation counting info into temp table	
		DROP TABLE IF EXISTS #LastReconciliationCountingPerTender
			SELECT 
				fc.ZNR				
				,fc.BagId
				,SUM(fc.Amount) AS Amount -- sum cash and currency counted
			INTO #LastReconciliationCountingPerTender
			FROM
				(SELECT 
					fc.ZNR
					,fc.TotalTypeIdx
					,fc.StoreIdx
					,fc.TenderIdx
					,ISNULL(fc.Amount, 0) AS Amount
					,fc.BagId
					,ROW_NUMBER() OVER(PARTITION BY  
												fc.StoreIdx,
												fc.ZNR,
												fc.TotalTypeIdx,
												fc.TenderIdx,
												fc.CurrencyIdx
												ORDER BY fc.CountNo DESC) ReverseOrder
				FROM RBIM.Fact_ReconciliationCountingPerTender fc
				INNER JOIN #ReconciliationDateZnr Rznr ON Rznr.znr = fc.znr
														AND Rznr.Storeidx = fc.storeidx
														AND Rznr.TotalTypeIdx = fc.TotalTypeIdx
				INNER JOIN #TenderSelection dt ON dt.TenderIdx = fc.TenderIdx		
					) fc		
			WHERE fc.ReverseOrder = 1		
			GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.TenderIdx
		
		--Get sum of cash and currency(except negative numbers) for all (last)countings that has same ZNR as selected reconciliation date grouped by BagId
		SELECT 
			lt.BagId, 
			SUM(lt.Amount) AS Amount, 
			COUNT(DISTINCT lt.ZNR) AS NoOfZnr 
		FROM #LastReconciliationCountingPerTender lt	  
		WHERE Amount > 0
		GROUP BY lt.BagId

		-- Clean temp table cache after general dataset is selected 

		DROP TABLE IF EXISTS #Stores
		DROP TABLE IF EXISTS #TenderSelection
		DROP TABLE IF EXISTS #ReconciliationDateZnr
		DROP TABLE IF EXISTS #LastReconciliationCountingPerTender
		
	END
END



GO

