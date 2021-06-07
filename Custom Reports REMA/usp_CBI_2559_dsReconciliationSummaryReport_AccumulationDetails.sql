USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_AccumulationDetails]    Script Date: 07.02.2020 10:39:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------







---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_AccumulationDetails]     
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
	-- 19.02.2016: Returns details about reconciliation that have been counted
	--					Not counted reconciliations is not present in the DWH now.
	  -----------------------------------------
		DECLARE @DateIdx int = cast(convert(varchar(8),@Date, 112) as integer)

	   	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); 
		
		-- Gather stores into temp table based on @IncludeInReportsCurrentStoreOnly parameter
		DROP TABLE IF EXISTS #Stores
			SELECT StoreIdx
			INTO #Stores
			FROM RBIM.Dim_Store
			WHERE StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly=0 OR (@IncludeInReportsCurrentStoreOnly=1 AND IsCurrentStore = 1))
		
		-- Get reconciliation dates into temp table
		DROP TABLE IF EXISTS #ReconciliationDate
			SELECT DISTINCT 
				fc.[StoreIdx]
				,fc.[ZNR]
				,fc.[TotalTypeIdx]
				,fc.ReconciliationDateIdx
			INTO #ReconciliationDate
			FROM [RBIM].Fact_ReconciliationSystemTotalPerTender fc
			INNER JOIN #Stores ds ON ds.StoreIdx = fc.StoreIdx
			INNER JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = fc.TotalTypeIdx
			WHERE fc.ReconciliationDateIdx=@DateIdx		
			AND dtt.TotalTypeId = @TotalTypeId		
		
		-- Get total per accumulation into tempt table
		DROP TABLE IF EXISTS #TotalPerAccumulation
			SELECT	
				f.ZNR
				,f.TotalTypeIdx
				,f.StoreIdx
				,f.CashRegisterIdx
				,f.CashierUserIdx
				,f.ReconciliationDateIdx
				,ISNULL(f.TillId,'') AS TillId	-- Convert NULL tillid values to blank for efficient joins in final select query (RS-40526)
				,f.OperatorId
				,SUM(CASE WHEN dat.AccumulationId = '1' THEN f.Count ELSE 0 END) AS NumberOfCustomers -- kunder
				,SUM(CASE WHEN dat.AccumulationId = '11' THEN f.Count ELSE 0 END) AS NumberOfReturn -- antall retur
				,SUM(CASE WHEN dat.AccumulationId = '11' THEN f.Amount ELSE 0 END) AS ReturnAmount -- retur belÃ¸p
				,SUM(CASE WHEN dat.AccumulationId = '5' THEN f.Count ELSE 0 END) AS NumberOfCorrection -- antall korrigerte (Past void)
				,SUM(CASE WHEN dat.AccumulationId = '5' THEN f.Amount ELSE 0 END) AS CorrectionAmount -- korrigerte belÃ¸p
				,SUM(CASE WHEN dat.AccumulationId = '10' THEN f.Count ELSE 0 END) AS NumberOfCanceled -- antall kansellerte
				,SUM(CASE WHEN dat.AccumulationId = '19' THEN f.Count ELSE 0 END) AS Price -- prisforespÃ¸rsel
				,SUM(CASE WHEN dat.AccumulationId ='6' THEN f.Amount ELSE 0 END) AS Discount -- rabatt
			INTO #TotalPerAccumulation
			FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType f
			INNER JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = f.AccumulationTypeIdx
			INNER JOIN #Stores ds ON ds.StoreIdx=f.StoreIdx			
			INNER JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx=f.TotalTypeIdx														-- 
			WHERE f.ReconciliationDateIdx = @DateIdx 
			AND dtt.TotalTypeId=@TotalTypeId		
			GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
		
		-- Get counting per accumulation into temp table 
		DROP TABLE IF EXISTS #CountingPerAccumulation
			SELECT 
				fc.ZNR
				,fc.TotalTypeIdx
				,fc.StoreIdx
				,SUM(CASE WHEN fc.AccumulationId = '11' THEN fc.Amount ELSE NULL END) AS ReturnAmount -- retur belÃ¸p
				,SUM(CASE WHEN fc.AccumulationId = '5' THEN fc.Amount ELSE NULL END) AS CorrectionAmount -- korrigerte belÃ¸p (Past void)
			INTO #CountingPerAccumulation
			FROM (
					SELECT 
						fc.ZNR
						,fc.TotalTypeIdx
						,fc.StoreIdx
						,fc.AccumulationTypeIdx
						,fc.Amount 
						,dat.AccumulationId
						,ROW_NUMBER() OVER(PARTITION BY  
													fc.StoreIdx,
													fc.ZNR,
													fc.TotalTypeIdx,
													fc.AccumulationTypeIdx
													ORDER BY fc.CountNo DESC) ReverseOrder
					FROM RBIM.Fact_ReconciliationCountingPerAccumulationType fc
					INNER JOIN #ReconciliationDate Srd ON fc.Znr = Srd.Znr
														AND fc.StoreIdx = Srd.StoreIdx
														AND fc.TotalTypeIdx = Srd.TotalTypeIdx
					INNER JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = fc.AccumulationTypeIdx
				) fc
			--JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = fc.AccumulationTypeIdx -- Moved join into sub-query to limit records incoming (RS-40526)
			WHERE fc.ReverseOrder = 1
			GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx	
		
		-- Get total per accumulation into temp table 
		DROP TABLE IF EXISTS #TotalPerTender
			SELECT	f.ZNR
					,f.TotalTypeIdx
					,f.StoreIdx
					,f.CashRegisterIdx
					,f.CashierUserIdx
					,f.ReconciliationDateIdx
					,ISNULL(f.TillId,'') AS TillId	-- Convert NULL tillid values to blank for efficient joins in final select query (RS-40526)
					,f.OperatorId
					,SUM(f.Amount) AS SalesAmount
			INTO #TotalPerTender
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender f
				INNER JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = f.TenderIdx
				INNER JOIN #Stores ds ON ds.StoreIdx = f.StoreIdx
				INNER JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = f.TotalTypeIdx
			WHERE f.ReconciliationDateIdx = @DateIdx										
			AND dtt.TotalTypeId = @TotalTypeId
			GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
	  
		SELECT DISTINCT 
			pa.ZNR
			,COALESCE(pa.OperatorId,pt.OperatorId) AS CashierId
			,ISNULL(du.FirstName,'') + ISNULL(du.LastName,'') AS Cashier
			,pa.TillId
			,ISNULL(pa.NumberOfCustomers, 0) AS NumberOfCustomers
			,ISNULL(pt.SalesAmount, 0) AS SalesAmount
			,ISNULL(pa.NumberOfReturn, 0) AS NumberOfReturn
			,COALESCE(NULLIF(la.ReturnAmount,0),pa.ReturnAmount, 0) AS ReturnAmount
			,ISNULL(pa.NumberOfCorrection, 0) AS NumberOfCorrection
			,COALESCE(NULLIF(la.CorrectionAmount,0), pa.CorrectionAmount, 0) AS CorrectionAmount  
			,ISNULL( pa.NumberOfCanceled, 0) AS NumberOfCanceled
			,ISNULL(pa.Price, 0) AS Price
			,ISNULL(pa.Discount, 0) AS Discount
		FROM #TotalPerAccumulation pa
		LEFT JOIN #CountingPerAccumulation la ON la.StoreIdx = pa.StoreIdx
												AND la.TotalTypeIdx = pa.TotalTypeIdx
												AND la.ZNR = pa.ZNR
		LEFT JOIN #TotalPerTender pt ON pt.ZNR = pa.ZNR 
									AND pt.CashierUserIdx = pa.CashierUserIdx 
									AND pt.CashRegisterIdx = pa.CashRegisterIdx 
									AND pt.TotalTypeIdx = pa.TotalTypeIdx
									AND pt.StoreIdx = pa.StoreIdx
									AND pt.tillId = pa.TillId 		
		JOIN RBIM.Dim_User du ON (du.UserIdx = pt.CashierUserIdx OR du.UserIdx = pa.CashierUserIdx)

		-- Clean temp table cache after general dataset is selected 

		DROP TABLE IF EXISTS #Stores
		DROP TABLE IF EXISTS #ReconciliationDate
		DROP TABLE IF EXISTS #TotalPerAccumulation
		DROP TABLE IF EXISTS #CountingPerAccumulation
		DROP TABLE IF EXISTS #TotalPerTender
	  	
	END
END 




GO

