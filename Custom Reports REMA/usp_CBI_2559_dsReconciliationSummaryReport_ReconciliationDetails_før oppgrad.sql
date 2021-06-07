USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_ReconciliationDetails]    Script Date: 17.06.2019 12:36:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


 
ALTER   PROCEDURE [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_ReconciliationDetails]     
(
@TotalTypeId AS INT ,	
---------------------------------------------
@StoreId AS VARCHAR(100),
@Date AS DATETIME,
@ReportReconciliationDateFromIdx AS INT,
@ReportReconciliationDateToIdx AS INT,
@ReportReconciliationTimeFromIdx AS INT,
@ReportReconciliationTimeToIdx AS INT
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
				 		
		----------------------------------------------------------------------------------------------------------------------
		-- 19.02.2016: Returns details about reconciliation that have been counted
		--					Not counted reconciliations is not present in the DWH now.
		-----------------------------------------

		-- Gather stores into temp table based on @IncludeInReportsCurrentStoreOnly parameter
		DROP TABLE IF EXISTS #Stores
			SELECT StoreIdx
			INTO #Stores
			FROM RBIM.Dim_Store
			WHERE StoreId = @StoreId		

		-- Get tender selection information into temp table	
		DROP TABLE IF EXISTS #TenderSelection
			SELECT 
				A.Tenderid, 
				A.TenderIdx, 
				C.TenderSelectionId
			INTO #TenderSelection
			FROM [RBIM].[Dim_Tender] AS A			
			INNER JOIN [RBIM].[Cov_TenderSelection] AS B
				ON A.TenderIdx = B.TenderIdx 
			INNER JOIN [RBIM].[Dim_TenderSelection] AS C
				ON B.TenderSelectionIdx = C.TenderSelectionIdx
		
		-- Get reconciliation date and ZNR per tender into temp table
		DROP TABLE IF EXISTS #ReconciliationDatePerTender
			SELECT DISTINCT 
				fc.[StoreIdx]
				,fc.[ZNR]
				,fc.[TotalTypeIdx]
				,fc.ReconciliationDateIdx
			INTO #ReconciliationDatePerTender			
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender fc
			INNER JOIN #Stores ds ON ds.StoreIdx = fc.StoreIdx
			INNER JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = fc.TotalTypeIdx
			WHERE fc.ReconciliationDateIdx=@DateIdx			
			AND dtt.TotalTypeId = @TotalTypeId
		
		-- Get reconciliation date and ZNR per accumulation into temp table
		DROP TABLE IF EXISTS #ReconciliationDatePerAccumulation
			SELECT DISTINCT 
					fc.[StoreIdx]
					,fc.[ZNR]
					,fc.[TotalTypeIdx]
					,fc.ReconciliationDateIdx
			INTO #ReconciliationDatePerAccumulation			
			FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType fc
			INNER JOIN #Stores ds ON ds.StoreIdx = fc.StoreIdx
			INNER JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = fc.TotalTypeIdx
			WHERE fc.ReconciliationDateIdx=@DateIdx			
			AND dtt.TotalTypeId = @TotalTypeId		
		
		-- Get reconciliation counting per tender into temp table
		DROP TABLE IF EXISTS #CountingPerTender
			SELECT 
				fc.ZNR
				,fc.TotalTypeIdx
				,fc.StoreIdx
				,fc.BagId
				,fc.ReconciliationStatusId
				,SUM(CASE WHEN fc.TenderSelectionId = 3 THEN fc.Amount ELSE NULL END) AS PaymentCard -- kort og reserveløsning
				,SUM(CASE WHEN fc.TenderSelectionId = 2 THEN fc.Amount ELSE NULL END) AS CountedCash -- kontant
				,SUM(CASE WHEN fc.TenderSelectionId = 4 THEN fc.Amount ELSE NULL END) AS AccountSale -- kundekreditt 
				,SUM(CASE WHEN fc.TenderSelectionId = 5 THEN fc.Amount ELSE NULL END) AS MobilePay -- mobil betaling
				,SUM(CASE WHEN fc.TenderSelectionId = 1 THEN fc.Amount ELSE NULL END) AS GiftCardAndVoucher -- kupong og gavekort
				,SUM(CASE WHEN fc.TenderId = '8' THEN fc.Amount ELSE NULL END) AS Currency  -- valuta */
			INTO #CountingPerTender
			FROM (
					SELECT 
						fc.ZNR
						,fc.TotalTypeIdx
						,fc.StoreIdx
						,fc.TenderIdx
						,fc.Amount 
						,fc.Rate
						,fc.BagId				
						,fc.Unit
						,dt.TenderId
						,drs.ReconciliationStatusId
						,dt.TenderSelectionId
						,ROW_NUMBER() OVER(PARTITION BY  
													fc.StoreIdx,
													fc.ZNR,
													fc.TotalTypeIdx,
													fc.TenderIdx,
													fc.CurrencyIdx
													ORDER BY fc.CountNo DESC) ReverseOrder
					FROM RBIM.Fact_ReconciliationCountingPerTender fc
					INNER JOIN #ReconciliationDatePerTender Srd ON fc.Znr = Srd.Znr
																	AND fc.StoreIdx = Srd.StoreIdx
																	AND fc.TotalTypeIdx = Srd.TotalTypeIdx		
					INNER JOIN #TenderSelection dt ON dt.TenderIdx = fc.TenderIdx
					LEFT JOIN RBIM.Dim_ReconciliationStatus drs ON drs.ReconciliationStatusIdx = fc.ReconciliationStatusIdx	
				) fc			
			WHERE fc.ReverseOrder = 1
			GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.ReconciliationStatusId 
	 
		-- Get reconciliation counting per accumulation into temp table
		DROP TABLE IF EXISTS #CountingPerAccumulation
			SELECT 
					fc.ZNR
				,fc.TotalTypeIdx
				,fc.StoreIdx
				,fc.BagId
				,fc.ReconciliationStatusId
				,SUM(CASE WHEN fc.AccumulationId = '7' THEN fc.Amount ELSE 0 END) AS BottleDeposit -- pant
			INTO #CountingPerAccumulation
			FROM (
					SELECT 
						fc.ZNR
						,fc.TotalTypeIdx
						,fc.StoreIdx
						,fc.AccumulationTypeIdx
						,fc.Amount 
						,fc.BagId				
						,dat.AccumulationId
						,drs.ReconciliationStatusId
						,ROW_NUMBER() OVER(PARTITION BY  
													fc.StoreIdx,
													fc.ZNR,
													fc.TotalTypeIdx,
													fc.AccumulationTypeIdx
													ORDER BY fc.CountNo DESC) ReverseOrder
					FROM RBIM.Fact_ReconciliationCountingPerAccumulationType fc
					INNER JOIN #ReconciliationDatePerAccumulation Srd ON fc.Znr = Srd.Znr
																	AND fc.StoreIdx = Srd.StoreIdx
																	AND fc.TotalTypeIdx = Srd.TotalTypeIdx
					INNER JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = fc.AccumulationTypeIdx
					LEFT JOIN RBIM.Dim_ReconciliationStatus drs ON drs.ReconciliationStatusIdx = fc.ReconciliationStatusIdx				
				) fc		
			WHERE fc.ReverseOrder = 1
			GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.ReconciliationStatusId
	  
		-- Get reconciliation total per accumulation into temp table
		DROP TABLE IF EXISTS #TotalPerAccumulation
			SELECT	
				f.ZNR
				,f.TotalTypeIdx
				,f.StoreIdx
				,f.CashRegisterIdx
				,f.CashierUserIdx
				,f.ReconciliationDateIdx
				,ISNULL(f.TillId, '') As TillId
				,f.OperatorId
				,SUM(CASE WHEN dat.AccumulationId = '7' THEN f.Amount ELSE 0 END) AS BottleDeposit -- pant
			INTO #TotalPerAccumulation
			FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType f
			JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = f.AccumulationTypeIdx
			INNER JOIN #ReconciliationDatePerAccumulation Srd ON f.Znr = Srd.Znr
																AND f.StoreIdx = Srd.StoreIdx
																AND f.TotalTypeIdx = Srd.TotalTypeIdx			
			GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
	  
		-- Get reconciliation total per tender into temp table
		DROP TABLE IF EXISTS #TotalPerTender
			SELECT	
				f.ZNR
				,f.TotalTypeIdx
				,f.StoreIdx
				,f.CashRegisterIdx
				,f.CashierUserIdx
				,f.ReconciliationDateIdx
				,ISNULL(f.TillId,'') AS TillId
				,f.OperatorId
				,SUM(CASE WHEN dt.TenderId in ('1','3','6','22','2','19','8', '5') THEN f.Amount ELSE NULL END) AS SalesAmount
				,SUM(CASE WHEN dt.TenderSelectionId = 2 THEN f.Amount ELSE NULL END) AS Cash -- kontant
				,SUM(CASE WHEN dt.TenderSelectionId = 3 THEN f.Amount ELSE NULL END) AS PaymentCard -- kort og reserveløsning
				,SUM(CASE WHEN dt.TenderSelectionId = 4 THEN f.Amount ELSE NULL END) AS AccountSale -- kundekreditt 
				,SUM(CASE WHEN dt.TenderSelectionId = 5  THEN f.Amount ELSE NULL END) AS MobilePay -- mobil betaling
				,SUM(CASE WHEN dt.TenderSelectionId = 1 THEN f.Amount ELSE NULL END) AS GiftCardAndVoucher -- kupong og gavekort
				,SUM(CASE WHEN dt.TenderId = '8' THEN f.Amount ELSE NULL END) AS Currency  -- valuta */
			INTO #TotalPerTender
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender f
			INNER JOIN #TenderSelection dt ON dt.TenderIdx = f.TenderIdx
			INNER JOIN #ReconciliationDatePerTender Srd ON f.Znr = Srd.Znr
														AND f.StoreIdx = Srd.StoreIdx
														AND f.TotalTypeIdx = Srd.TotalTypeIdx		
			GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
	 
		-- Get key sales figures per tender into temp table
		DROP TABLE IF EXISTS #KeyFiguresReceiptTender
			SELECT 
						f.StoreIdx					
					,SUM(CASE WHEN dt.TenderId in ('1','3','6','22','2','19','8', '5') THEN f.Amount ELSE NULL END) AS ReceiptSalesTotal
					,SUM(CASE WHEN dt.TenderSelectionId = 3 THEN f.Amount ELSE 0 END) AS TotalPaymentCard -- kort og reserveløsning
					,SUM(CASE WHEN dt.TenderSelectionId = 2 THEN f.Amount ELSE 0 END) AS TotalCash -- kontant
					,SUM(CASE WHEN dt.TenderSelectionId = 4 THEN f.Amount ELSE 0 END) AS TotalAccountSale -- kundekreditt 
					,SUM(CASE WHEN dt.TenderSelectionId = 5 THEN f.Amount ELSE 0 END) AS TotalMobilePay -- mobil betaling
					,SUM(CASE WHEN dt.TenderSelectionId = 1 THEN f.Amount ELSE 0 END) AS TotalGiftCardAndVoucher -- kupong og gavekort						
					,SUM(CASE WHEN dt.TenderId = '8' THEN f.Amount ELSE 0 END) AS TotalCurrency
			INTO #KeyFiguresReceiptTender
			FROM RBIM.Fact_ReceiptTender f
			INNER JOIN #TenderSelection dt ON dt.TenderIdx = f.TenderIdx
			INNER JOIN #Stores ds ON ds.StoreIdx = f.StoreIdx			  
			WHERE 		  
			(((f.ReceiptDateIdx = @ReportReconciliationDateFromIdx AND f.ReceiptTimeIdx >= @ReportReconciliationTimeFromIdx) 
			OR (f.ReceiptDateIdx = @ReportReconciliationDateToIdx AND f.ReceiptTimeIdx <= @ReportReconciliationTimeToIdx))
			OR (f.ReceiptDateIdx > @ReportReconciliationDateFromIdx AND f.ReceiptDateIdx < @ReportReconciliationDateToIdx))
			--AND ds.StoreId = @StoreId
			--AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}	 
			AND f.ReceiptStatusIdx = 1			
			GROUP BY f.StoreIdx	
		
		-- Get key sales figures from sales and return into temp table
		DROP TABLE IF EXISTS #KeyFiguresSalesAndReturn
			SELECT 
					asr.StoreIdx					
					,SUM(CASE WHEN da.ArticleIdx = -98 OR da.ArticleTypeId IN (/*130,*/132,133) THEN asr.SalesAmount ELSE 0 END) AS TotalBottleDeposit --(RS-32775)
			INTO #KeyFiguresSalesAndReturn
			FROM RBIM.Fact_ReceiptRowSalesAndReturn as asr  			
			INNER JOIN #Stores ds ON ds.StoreIdx = asr.StoreIdx						
			INNER JOIN rbim.Dim_Article da ON da.ArticleIdx = asr.ArticleIdx			 		
			WHERE
			(((asr.ReceiptDateIdx = @ReportReconciliationDateFromIdx AND asr.ReceiptTimeIdx >= @ReportReconciliationTimeFromIdx) 
			OR (asr.ReceiptDateIdx = @ReportReconciliationDateToIdx AND asr.ReceiptTimeIdx <= @ReportReconciliationTimeToIdx))
			OR (asr.ReceiptDateIdx > @ReportReconciliationDateFromIdx AND asr.ReceiptDateIdx < @ReportReconciliationDateToIdx))
			--AND ds.StoreId = @StoreId	
			--AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}	 
			AND asr.ReceiptStatusIdx = 1			
			GROUP BY asr.StoreIdx
	  
		-- General data select
		--SELECT DISTINCT 
		--	pa.ZNR
		--	,COALESCE(pa.OperatorId,pt.OperatorId) AS CashierId
		--	,ISNULL(du.FirstName,'') + ISNULL(du.LastName,'') AS Cashier
		--	,pa.TillId
		--	,ISNULL(pt.SalesAmount, 0) AS SalesAmount
		--	,ISNULL(pt.PaymentCard,0) AS PaymentCard
		--	,ISNULL(pt.Cash,0) AS Cash --SystemCash
		--	,ISNULL(pt.AccountSale,0) AS AccountSale
		--	,ISNULL(pt.MobilePay,0) AS MobilePay
		--	,ISNULL(pt.GiftCardAndVoucher,0) AS GiftCardAndVoucher
		--	,ISNULL(pt.Currency,0) AS Currency
		--	,ISNULL(pa.BottleDeposit,0) AS BottleDeposit
		--	,ISNULL(lt.CountedCash,0) AS CountedCash
		--	,(ISNULL(CountedCash,0)-ISNULL(Cash,0)) AS CashDeviation
		--	,lt.BagId
		--	,COALESCE(la.ReconciliationStatusId,lt.ReconciliationStatusId) as ReconciliationStatusId			
		--	,t1.ReceiptSalesTotal AS TotalSalesAmount
		--	,t1.TotalPaymentCard
		--	,t1.TotalCash
		--	,t1.TotalAccountSale
		--	,t1.TotalMobilePay
		--	,t1.TotalGiftCardAndVoucher
		--	,t1.TotalCurrency
		--	,t2.TotalBottleDeposit
		--FROM #TotalPerAccumulation pa
		--LEFT JOIN #TotalPerTender pt ON pt.ZNR = pa.ZNR 
		--							AND pt.CashierUserIdx = pa.CashierUserIdx 
		--							AND pt.CashRegisterIdx = pa.CashRegisterIdx 
		--							AND pt.TotalTypeIdx = pa.TotalTypeIdx
		--							AND pt.StoreIdx = pa.StoreIdx
		--							AND pa.TillId = pt.TillId   
		--INNER JOIN RBIM.Dim_User du ON (du.UserIdx = pt.CashierUserIdx OR du.UserIdx = pa.CashierUserIdx)  
		--LEFT JOIN #KeyFiguresReceiptTender t1 ON t1.StoreIdx = pa.StoreIdx  
		--LEFT JOIN #KeyFiguresSalesAndReturn t2 ON t2.StoreIdx = pa.StoreIdx 
		--LEFT JOIN #CountingPerTender lt ON (lt.StoreIdx = pt.StoreIdx OR lt.StoreIdx = pa.StoreIdx)
		--							AND (lt.TotalTypeIdx = pt.TotalTypeIdx OR lt.TotalTypeIdx = pa.TotalTypeIdx)
		--							AND (lt.ZNR = pt.ZNR OR	lt.ZNR = pa.ZNR)
		--LEFT JOIN #CountingPerAccumulation la ON (la.StoreIdx = pa.StoreIdx OR lt.StoreIdx = la.StoreIdx)
		--							AND (la.TotalTypeIdx = pa.TotalTypeIdx OR la.TotalTypeIdx = lt.TotalTypeIdx)
		--							AND (la.ZNR = pa.ZNR  OR la.ZNR = lt.ZNR)	  
		--ORDER BY pa.ZNR

		--from Custom report:
		SELECT DISTINCT 
			pa.ZNR
			,COALESCE(pa.OperatorId,pt.OperatorId) AS CashierId
			,ISNULL(du.FirstName,'') + ISNULL(du.LastName,'') AS Cashier
			,ISNULL(CountedCash,0) AS Cash --SystemCash    --new
			,1 AS NoOfZnr --for å telle antalle dagsoppgjør
	  FROM #TotalPerAccumulation pa
	  LEFT JOIN #TotalPerTender pt ON pt.ZNR = pa.ZNR 
									AND pt.CashierUserIdx = pa.CashierUserIdx 
									AND pt.CashRegisterIdx = pa.CashRegisterIdx 
									AND pt.TotalTypeIdx = pa.TotalTypeIdx
									AND pt.StoreIdx = pa.StoreIdx
									AND ISNULL(pa.TillId,'') = ISNULL(pt.TillId,'')   
	  JOIN RBIM.Dim_User du ON (du.UserIdx = pt.CashierUserIdx OR du.UserIdx = pa.CashierUserIdx)  
	  LEFT JOIN #CountingPerTender lt ON (lt.StoreIdx = pt.StoreIdx OR lt.StoreIdx = pa.StoreIdx)
									AND (lt.TotalTypeIdx = pt.TotalTypeIdx OR lt.TotalTypeIdx = pa.TotalTypeIdx)
									AND (lt.ZNR = pt.ZNR OR	lt.ZNR = pa.ZNR)
	  LEFT JOIN #CountingPerAccumulation la ON (la.StoreIdx = pa.StoreIdx OR lt.StoreIdx = la.StoreIdx)
									AND (la.TotalTypeIdx = pa.TotalTypeIdx OR la.TotalTypeIdx = lt.TotalTypeIdx)
									AND (la.ZNR = pa.ZNR  OR la.ZNR = lt.ZNR)

	  WHERE pt.Cash>0
	  ORDER BY pa.ZNR	  

		-- Clean temp table cache after general dataset is selected 

		DROP TABLE IF EXISTS #Stores
		DROP TABLE IF EXISTS #TenderSelection
		DROP TABLE IF EXISTS #ReconciliationDatePerTender
		DROP TABLE IF EXISTS #ReconciliationDatePerAccumulation
		DROP TABLE IF EXISTS #CountingPerTender
		DROP TABLE IF EXISTS #CountingPerAccumulation
		DROP TABLE IF EXISTS #TotalPerAccumulation
		DROP TABLE IF EXISTS #TotalPerTender
		DROP TABLE IF EXISTS #KeyFiguresReceiptTender
		DROP TABLE IF EXISTS #KeyFiguresSalesAndReturn
	END
END  




GO

