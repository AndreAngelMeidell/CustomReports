USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1600_dsReconciliationSummaryReport_ReconciliationDetailsBag]    Script Date: 15.01.2019 09:12:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





 
CREATE PROCEDURE [dbo].[usp_CBI_1600_dsReconciliationSummaryReport_ReconciliationDetailsBag]     
(
@TotalTypeId AS INT ,	
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME
	)
AS  
BEGIN	
IF (@Date IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
END
ELSE BEGIN
			
	

			DECLARE @DateIdx INT = CAST(CONVERT(VARCHAR(8),@Date, 112) AS INTEGER) -- Added for performance optimization (RS-34652)		
		----------------------------------------------------------------------------------------------------------------------
		-- 19.02.2016: Returns details about reconciliation that have been counted
		--					Not counted reconciliations is not present in the DWH now.
		-----------------------------------------
		 ;WITH SystemReconciliationDatePerTender AS(									-- Added for performance optimization (RS-34652)
			SELECT DISTINCT 
				fc.[StoreIdx]
				,fc.[ZNR]
				,fc.[TotalTypeIdx]
				,fc.ReconciliationDateIdx			
			FROM BI_Mart.RBIM.Fact_ReconciliationSystemTotalPerTender fc
			JOIN RBIM.Dim_Store ds ON ds.StoreIdx = fc.StoreIdx
			JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = fc.TotalTypeIdx
			WHERE fc.ReconciliationDateIdx=@DateIdx
			AND ds.StoreId = @StoreId
			AND ds.IsCurrentStore = 1
			AND dtt.TotalTypeId = @TotalTypeId
		),
		SystemReconciliationDatePerAccumulation AS(									-- Added for performance optimization (RS-34652)
			SELECT DISTINCT 
				fc.[StoreIdx]
				,fc.[ZNR]
				,fc.[TotalTypeIdx]
				,fc.ReconciliationDateIdx			
			FROM BI_Mart.RBIM.Fact_ReconciliationSystemTotalPerAccumulationType fc
			JOIN RBIM.Dim_Store ds ON ds.StoreIdx = fc.StoreIdx
			JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = fc.TotalTypeIdx
			WHERE fc.ReconciliationDateIdx=@DateIdx
			AND ds.StoreId = @StoreId
			AND ds.IsCurrentStore = 1
			AND dtt.TotalTypeId = @TotalTypeId
		),
		LastReconciliationCountingPerTender AS(
			SELECT 
				 fc.ZNR
				,fc.TotalTypeIdx
				,fc.StoreIdx
				,fc.BagId
				,fc.ReconciliationStatusId
				,SUM(CASE WHEN fc.TenderId IN ('3', '5') THEN fc.Amount ELSE NULL END) AS PaymentCard -- kort og reserveløsning
				,SUM(CASE WHEN fc.TenderId = '1' THEN fc.Amount ELSE NULL END) AS CountedCash -- kontant
				,SUM(CASE WHEN fc.TenderId = '6' THEN fc.Amount ELSE NULL END) AS AccountSale -- kundekreditt 
				,SUM(CASE WHEN fc.TenderId = '22' THEN fc.Amount ELSE NULL END) AS MobilePay -- mobil betaling
				,SUM(CASE WHEN fc.TenderId IN ('2', '19') THEN fc.Amount ELSE NULL END) AS GiftCardAndVoucher -- kupong og gavekort
				,SUM(CASE WHEN fc.TenderId = '8' THEN fc.Amount ELSE NULL END) AS Currency  -- valuta */
			FROM
			(SELECT 
				fc.ZNR
				,fc.TotalTypeIdx
				,fc.StoreIdx
				,fc.TenderIdx
				,fc.Amount 
				,fc.Rate
				,fc.BagId
				--,fc.ReconciliationStatusIdx
				,fc.Unit
				,dt.TenderId
				,drs.ReconciliationStatusId
				,ROW_NUMBER() OVER(PARTITION BY  
										   fc.StoreIdx,
										   fc.ZNR,
										   fc.TotalTypeIdx,
										   fc.TenderIdx,
										   fc.CurrencyIdx
											ORDER BY fc.CountNo DESC) ReverseOrder
			FROM RBIM.Fact_ReconciliationCountingPerTender fc
			INNER JOIN SystemReconciliationDatePerTender Srd ON fc.Znr = Srd.Znr
			AND fc.StoreIdx = Srd.StoreIdx
			AND fc.TotalTypeIdx = Srd.TotalTypeIdx		
			JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
			LEFT JOIN RBIM.Dim_ReconciliationStatus drs ON drs.ReconciliationStatusIdx = fc.ReconciliationStatusIdx	
			 ) fc
			--JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
			WHERE fc.ReverseOrder = 1
			GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.ReconciliationStatusId /*, fc.ReconciliationStatusIdx*/
	  ),
	  LastReconciliationCountingPerAccumulationType AS(
			SELECT 
				 fc.ZNR
				,fc.TotalTypeIdx
				,fc.StoreIdx
				,fc.BagId
				,fc.ReconciliationStatusId
				,SUM(CASE WHEN fc.AccumulationId = '7' THEN fc.Amount ELSE 0 END) AS BottleDeposit -- pant
			FROM (
			SELECT 
				fc.ZNR
				,fc.TotalTypeIdx
				,fc.StoreIdx
				,fc.AccumulationTypeIdx
				,fc.Amount 
				,fc.BagId
				--,fc.ReconciliationStatusIdx
				,dat.AccumulationId
				,drs.ReconciliationStatusId
				,ROW_NUMBER() OVER(PARTITION BY  
										   fc.StoreIdx,
										   fc.ZNR,
										   fc.TotalTypeIdx,
										   fc.AccumulationTypeIdx
											ORDER BY fc.CountNo DESC) ReverseOrder
			FROM RBIM.Fact_ReconciliationCountingPerAccumulationType fc
			INNER JOIN SystemReconciliationDatePerAccumulation Srd ON fc.Znr = Srd.Znr
			AND fc.StoreIdx = Srd.StoreIdx
			AND fc.TotalTypeIdx = Srd.TotalTypeIdx
			JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = fc.AccumulationTypeIdx
			LEFT JOIN RBIM.Dim_ReconciliationStatus drs ON drs.ReconciliationStatusIdx = fc.ReconciliationStatusIdx				
			 ) fc
			--JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = fc.AccumulationTypeIdx
			WHERE fc.ReverseOrder = 1
			GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.ReconciliationStatusId/*, fc.ReconciliationStatusIdx*/
	  ),
	  systemTotalPerAccumulation AS (
			SELECT	
				f.ZNR
				,f.TotalTypeIdx
				,f.StoreIdx
				,f.CashRegisterIdx
				,f.CashierUserIdx
				,f.ReconciliationDateIdx
				,f.TillId
				,f.OperatorId
				,SUM(CASE WHEN dat.AccumulationId = '7' THEN f.Amount ELSE 0 END) AS BottleDeposit -- pant
			FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType f
			JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = f.AccumulationTypeIdx
			INNER JOIN SystemReconciliationDatePerAccumulation Srd ON f.Znr = Srd.Znr
			AND f.StoreIdx = Srd.StoreIdx
			AND f.TotalTypeIdx = Srd.TotalTypeIdx			
			GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
	  ),
	  SystemTotalPerTender AS (
			SELECT	
				f.ZNR
				,f.TotalTypeIdx
				,f.StoreIdx
				,f.CashRegisterIdx
				,f.CashierUserIdx
				,f.ReconciliationDateIdx
				,f.TillId
				,f.OperatorId
				,SUM(CASE WHEN dt.TenderId IN ('1','3','6','22','2','19','8', '5') THEN f.Amount ELSE NULL END) AS SalesAmount
				,SUM(CASE WHEN dt.TenderId = '1' THEN f.Amount ELSE NULL END) AS Cash -- kontant
				,SUM(CASE WHEN dt.TenderId IN ('3', '5') THEN f.Amount ELSE NULL END) AS PaymentCard -- kort og reserveløsning
				,SUM(CASE WHEN dt.TenderId = '6' THEN f.Amount ELSE NULL END) AS AccountSale -- kundekreditt 
				,SUM(CASE WHEN dt.TenderId = '22' THEN f.Amount ELSE NULL END) AS MobilePay -- mobil betaling
				,SUM(CASE WHEN dt.TenderId IN ('2', '19') THEN f.Amount ELSE NULL END) AS GiftCardAndVoucher -- kupong og gavekort
				,SUM(CASE WHEN dt.TenderId = '8' THEN f.Amount ELSE NULL END) AS Currency  -- valuta */
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender f
			JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = f.TenderIdx
			INNER JOIN SystemReconciliationDatePerTender Srd ON f.Znr = Srd.Znr
			AND f.StoreIdx = Srd.StoreIdx
			AND f.TotalTypeIdx = Srd.TotalTypeIdx		
			GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
	  --),
	  --TotalKeyFiguresSub1 AS (
			--SELECT 
			--		 f.StoreIdx					
			--		--,f.CashRegisterNo 
			--		--,f.CashierUserIdx 
			--		,SUM(CASE WHEN dt.TenderId IN ('1','3','6','22','2','19','8', '5') THEN f.Amount ELSE NULL END) AS ReceiptSalesTotal
			--		,SUM(CASE WHEN dt.TenderId IN ('3', '5') THEN f.Amount ELSE 0 END) AS TotalPaymentCard -- kort og reserveløsning
			--		,SUM(CASE WHEN dt.TenderId = '1' THEN f.Amount ELSE 0 END) AS TotalCash -- kontant
			--		,SUM(CASE WHEN dt.TenderId = '6' THEN f.Amount ELSE 0 END) AS TotalAccountSale -- kundekreditt 
			--		,SUM(CASE WHEN dt.TenderId = '22' THEN f.Amount ELSE 0 END) AS TotalMobilePay -- mobil betaling
			--		,SUM(CASE WHEN dt.TenderId IN ('2', '19') THEN f.Amount ELSE 0 END) AS TotalGiftCardAndVoucher -- kupong og gavekort
			--		,SUM(CASE WHEN dt.TenderId = '8' THEN f.Amount ELSE 0 END) AS TotalCurrency
			--FROM RBIM.Fact_ReceiptTender f
			--JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = f.TenderIdx
			--JOIN RBIM.Dim_Store ds ON ds.StoreIdx = f.StoreIdx			  
			--WHERE 		  
			--(((f.ReceiptDateIdx = @ReportReconciliationDateFromIdx AND f.ReceiptTimeIdx >= @ReportReconciliationTimeFromIdx) 
			--OR (f.ReceiptDateIdx = @ReportReconciliationDateToIdx AND f.ReceiptTimeIdx <= @ReportReconciliationTimeToIdx))
			--OR (f.ReceiptDateIdx > @ReportReconciliationDateFromIdx AND f.ReceiptDateIdx < @ReportReconciliationDateToIdx))
			--AND ds.StoreId = @StoreId
			--AND ds.IsCurrentStore = 1	 
			--AND f.ReceiptStatusIdx = 1
			--GROUP BY f.StoreIdx	
	  --),
	  --TotalKeyFiguresSub2 AS (
			--SELECT 
			--		asr.StoreIdx				
			--		--,asr.CashRegisterNo
			--		--,SUM(asr.SalesAmount+asr.ReceiptRounding + asr.ReturnAmount) AS TotalSalesAmount
			--		,SUM(CASE WHEN da.ArticleIdx = -98 OR da.ArticleTypeId IN (/*130,*/132,133) THEN asr.SalesAmount ELSE 0 END) AS TotalBottleDeposit --(RS-32775)
			--FROM RBIM.Fact_ReceiptRowSalesAndReturn AS asr  			
			--JOIN RBIM.Dim_Store ds ON ds.StoreIdx = asr.StoreIdx
			--			--JOIN rbim.Dim_Date dd ON dd.DateIdx = asr.ReceiptDateIdx
			--JOIN rbim.Dim_Article da ON da.ArticleIdx = asr.ArticleIdx			 		
			--WHERE
			--(((asr.ReceiptDateIdx = @ReportReconciliationDateFromIdx AND asr.ReceiptTimeIdx >= @ReportReconciliationTimeFromIdx) 
			--OR (asr.ReceiptDateIdx = @ReportReconciliationDateToIdx AND asr.ReceiptTimeIdx <= @ReportReconciliationTimeToIdx))
			--OR (asr.ReceiptDateIdx > @ReportReconciliationDateFromIdx AND asr.ReceiptDateIdx < @ReportReconciliationDateToIdx))
			--AND ds.StoreId = @StoreId	
			--AND ds.IsCurrentStore = 1	 
			--AND asr.ReceiptStatusIdx = 1			
			--GROUP BY asr.StoreIdx
	  )
	  SELECT DISTINCT 
			pa.ZNR
			,COALESCE(pa.OperatorId,pt.OperatorId) AS CashierId
			,ISNULL(du.FirstName,'') + ISNULL(du.LastName,'') AS Cashier
			--,pa.TillId
			--,ISNULL(pt.SalesAmount, 0) AS SalesAmount
			--,ISNULL(pt.PaymentCard,0) AS PaymentCard
			--,ISNULL(pt.Cash,0) AS Cash --SystemCash  --old
			,ISNULL(CountedCash,0) AS Cash --SystemCash    --new
			--,ISNULL(pt.AccountSale,0) AS AccountSale
			--,ISNULL(pt.MobilePay,0) AS MobilePay
			--,ISNULL(pt.GiftCardAndVoucher,0) AS GiftCardAndVoucher
			--,ISNULL(pt.Currency,0) AS Currency
			--,ISNULL(pa.BottleDeposit,0) AS BottleDeposit
			--,ISNULL(lt.CountedCash,0) AS CountedCash
			--,(ISNULL(CountedCash,0)-ISNULL(Cash,0)) AS CashDeviation
			--,lt.BagId
			, 1 AS NoOfZnr --for å telle antalle dagsoppgjør
			--,COALESCE(la.ReconciliationStatusId,lt.ReconciliationStatusId) AS ReconciliationStatusId
			--,drs.ReconciliationStatusId
			--,t2.TotalSalesAmount
			--,t1.ReceiptSalesTotal AS TotalSalesAmount
			--,t1.TotalPaymentCard
			--,t1.TotalCash
			--,t1.TotalAccountSale
			--,t1.TotalMobilePay
			--,t1.TotalGiftCardAndVoucher
			--,t1.TotalCurrency
			--,t2.TotalBottleDeposit
	  FROM systemTotalPerAccumulation pa
	  LEFT JOIN SystemTotalPerTender pt ON pt.ZNR = pa.ZNR 
									AND pt.CashierUserIdx = pa.CashierUserIdx 
									AND pt.CashRegisterIdx = pa.CashRegisterIdx 
									AND pt.TotalTypeIdx = pa.TotalTypeIdx
									AND pt.StoreIdx = pa.StoreIdx
									AND ISNULL(pa.TillId,'') = ISNULL(pt.TillId,'')   
	  JOIN RBIM.Dim_User du ON (du.UserIdx = pt.CashierUserIdx OR du.UserIdx = pa.CashierUserIdx)  
	  --LEFT JOIN TotalKeyFiguresSub1 t1 ON t1.StoreIdx = pa.StoreIdx --AND t1.ReceiptDateIdx = pa.ReconciliationDateIdx--	AND t1.CashRegisterNo =pt.CashRegisterIdx --AND t1.CashierUserIdx = pt.CashierUserIdx 
	  --LEFT JOIN TotalKeyFiguresSub2 t2 ON t2.StoreIdx = pa.StoreIdx --AND t2.ReceiptDateIdx = pa.ReconciliationDateIdx--	AND t2.CashRegisterNo =pt.CashRegisterIdx 
	  LEFT JOIN lastReconciliationCountingPerTender lt ON (lt.StoreIdx = pt.StoreIdx OR lt.StoreIdx = pa.StoreIdx)
									AND (lt.TotalTypeIdx = pt.TotalTypeIdx OR lt.TotalTypeIdx = pa.TotalTypeIdx)
									AND (lt.ZNR = pt.ZNR OR	lt.ZNR = pa.ZNR)
	  LEFT JOIN LastReconciliationCountingPerAccumulationType la ON (la.StoreIdx = pa.StoreIdx OR lt.StoreIdx = la.StoreIdx)
									AND (la.TotalTypeIdx = pa.TotalTypeIdx OR la.TotalTypeIdx = lt.TotalTypeIdx)
									AND (la.ZNR = pa.ZNR  OR la.ZNR = lt.ZNR)

	  WHERE pt.Cash>0
	  ORDER BY pa.ZNR	  

END 
END


GO

