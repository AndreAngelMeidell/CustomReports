USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_AccumulationDetails]    Script Date: 21.06.2018 13:51:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_AccumulationDetails]     
(
	@TotalTypeId AS INT ,	
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME )
AS  
BEGIN 
-- 19.02.2016: Returns details about reconciliation that have been counted
--					Not counted reconciliations is not present in the DWH now.
  -----------------------------------------
   ;WITH systemTotalPerAccumulation AS (
		SELECT	
			f.ZNR
			,f.TotalTypeIdx
			,f.StoreIdx
			,f.CashRegisterIdx
			,f.CashierUserIdx
			,f.ReconciliationDateIdx
			,f.TillId
			,f.OperatorId
			,SUM(CASE WHEN dat.AccumulationId = '1' THEN f.Count ELSE 0 END) AS NumberOfCustomers -- kunder
			,SUM(CASE WHEN dat.AccumulationId = '11' THEN f.Count ELSE 0 END) AS NumberOfReturn -- antall retur
			,SUM(CASE WHEN dat.AccumulationId = '11' THEN f.Amount ELSE 0 END) AS ReturnAmount -- retur belÃƒÂ¸p
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN f.Count ELSE 0 END) AS NumberOfCorrection -- antall korrigerte (Past void)
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN f.Amount ELSE 0 END) AS CorrectionAmount -- korrigerte belÃƒÂ¸p
			,SUM(CASE WHEN dat.AccumulationId = '10' THEN f.Count ELSE 0 END) AS NumberOfCanceled -- antall kansellerte
			,SUM(CASE WHEN dat.AccumulationId = '19' THEN f.Count ELSE 0 END) AS Price -- prisforespÃƒÂ¸rsel
			,SUM(CASE WHEN dat.AccumulationId ='6' THEN f.Amount ELSE 0 END) AS Discount -- rabatt
		FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType f
		JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = f.AccumulationTypeIdx
		GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
  ),
   LastReconciliationCountingPerAccumulationType AS(
		SELECT 
			 fc.ZNR
			,fc.TotalTypeIdx
			,fc.StoreIdx
			,SUM(CASE WHEN dat.AccumulationId = '11' THEN fc.Amount ELSE NULL END) AS ReturnAmount -- retur belÃƒÂ¸p
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN fc.Amount ELSE NULL END) AS CorrectionAmount -- korrigerte belÃƒÂ¸p (Past void)
		FROM (
		SELECT 
			fc.ZNR
			,fc.TotalTypeIdx
			,fc.StoreIdx
			,fc.AccumulationTypeIdx
			,fc.Amount 
			,ROW_NUMBER() OVER(PARTITION BY  
									   fc.StoreIdx,
									   fc.ZNR,
									   fc.TotalTypeIdx,
									   fc.AccumulationTypeIdx
										ORDER BY fc.CountNo DESC) ReverseOrder
		FROM RBIM.Fact_ReconciliationCountingPerAccumulationType fc ) fc
		JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = fc.AccumulationTypeIdx
		WHERE fc.ReverseOrder = 1
		GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx
  ),
  SystemTotalPerTender AS (
  SELECT	f.ZNR
			,f.TotalTypeIdx
			,f.StoreIdx
			,f.CashRegisterIdx
			,f.CashierUserIdx
			,f.ReconciliationDateIdx
			,f.TillId
			,f.OperatorId
			,SUM(f.Amount) AS SalesAmount
  FROM RBIM.Fact_ReconciliationSystemTotalPerTender f
  JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = f.TenderIdx
  GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
  ),
  TotalKeyFiguresSub1 AS (
  SELECT
		acs.ReceiptDateIdx
		,acs.StoreIdx 
		,SUM(acs.NumberOfSelectedCorrections + acs.NumberOfLastCorrections) AS TotalCorrectionQuantity
		,SUM(acs.SelectedCorrectionsAmount + acs.LastCorrectionsAmount) AS TotalCorrectionAmount
		,SUM(acs.NumberOfReceiptsCanceled) AS TotalCanceled
		,NULL AS TotalSalesAmount
		,NULL AS TotalReturnAmount
		,NULL AS TotalReturnQuantity
		,NULL AS TotalNumberOfCustomers
		,NULL AS TotalDiscountAmount
  FROM RBIM.Agg_CashierSalesAndReturnPerHour acs 
  JOIN RBIM.Dim_Store ds ON ds.StoreIdx = acs.StoreIdx
  JOIN rbim.Dim_Date dd ON dd.DateIdx = acs.ReceiptDateIdx
  WHERE 
  ds.StoreId = @StoreId
  AND ds.IsCurrentStore = 1
  AND dd.FullDate = @Date
  GROUP BY acs.ReceiptDateIdx, acs.StoreIdx 
  ),
  TotalKeyFiguresSub2 AS (
   SELECT 
		asr.ReceiptDateIdx
		,asr.StoreIdx
		,NULL AS TotalCorrectionQuantity
		,NULL AS TotalCorrectionAmount
		,NULL AS TotalCanceled
		,SUM(asr.SalesAmount + asr.ReceiptRounding + asr.ReturnAmount) AS TotalSalesAmount
		,SUM(asr.ReturnAmount) AS TotalReturnAmount
		,SUM(asr.NumberOfArticlesInReturn) AS TotalReturnQuantity
		,SUM(asr.NumberOfCustomers) AS TotalNumberOfCustomers
		,SUM(asr.DiscountAmount) AS TotalDiscountAmount
  FROM RBIM.Agg_SalesAndReturnPerDay asr
  JOIN RBIM.Dim_Store ds ON ds.StoreIdx = asr.StoreIdx
  JOIN rbim.Dim_Date dd ON dd.DateIdx = asr.ReceiptDateIdx
  WHERE 
  ds.StoreId = @StoreId
  AND ds.IsCurrentStore = 1
  AND dd.FullDate = @Date
  GROUP BY asr.ReceiptDateIdx, asr.StoreIdx
  )
  SELECT DISTINCT 
		pa.ZNR
		,COALESCE(pa.OperatorId,pt.OperatorId) AS CashierId
		,ISNULL(du.FirstName,'') + ISNULL(du.LastName,'') AS Cashier
		,dcr.CashRegisterId
		,pa.TillId
		,ISNULL(pa.NumberOfCustomers, 0) AS NumberOfCustomers
		,ISNULL(pt.SalesAmount, 0) AS SalesAmount
		,ISNULL(pa.NumberOfReturn, 0) AS NumberOfReturn
		,COALESCE(la.ReturnAmount,pa.ReturnAmount, 0) AS ReturnAmount
		,ISNULL(pa.NumberOfCorrection, 0) AS NumberOfCorrection
		,COALESCE(la.CorrectionAmount, pa.CorrectionAmount, 0) AS CorrectionAmount 
		,ISNULL( pa.NumberOfCanceled, 0) AS NumberOfCanceled
		,ISNULL(pa.Price, 0) AS Price
		,ISNULL(pa.Discount, 0) AS Discount
		,t2.TotalSalesAmount
		,t2.TotalNumberOfCustomers
		,t2.TotalReturnAmount
		,t2.TotalReturnQuantity
		,t2.TotalDiscountAmount
		,t1.TotalCorrectionQuantity
		,t1.TotalCorrectionAmount
		,t1.TotalCanceled
  FROM systemTotalPerAccumulation pa
  LEFT JOIN LastReconciliationCountingPerAccumulationType la ON la.StoreIdx = pa.StoreIdx
																	AND la.TotalTypeIdx = pa.TotalTypeIdx
																	AND la.ZNR = pa.ZNR
  LEFT JOIN SystemTotalPerTender pt ON pt.ZNR = pa.ZNR 
								AND pt.CashierUserIdx = pa.CashierUserIdx 
								AND pt.CashRegisterIdx = pa.CashRegisterIdx 
								AND pt.TotalTypeIdx = pa.TotalTypeIdx
								AND pt.StoreIdx = pa.StoreIdx
								AND ISNULL(pt.tillId,'') = ISNULL(pa.TillId,'')
  JOIN RBIM.Dim_TotalType dtt ON (dtt.TotalTypeIdx = pt.TotalTypeIdx OR dtt.TotalTypeIdx = pa.TotalTypeIdx)
  JOIN RBIM.Dim_CashRegister dcr ON (dcr.CashRegisterIdx = pt.CashRegisterIdx OR dcr.CashRegisterIdx = pa.CashRegisterIdx)
  JOIN RBIM.Dim_User du ON (du.UserIdx = pt.CashierUserIdx OR du.UserIdx = pa.CashierUserIdx)
  JOIN RBIM.Dim_Store ds ON (ds.StoreIdx = pt.StoreIdx OR ds.StoreIdx = pa.StoreIdx)
  JOIN rbim.Dim_Date dd ON (dd.DateIdx = pt.ReconciliationDateIdx OR dd.DateIdx = pa.ReconciliationDateIdx)
  LEFT JOIN TotalKeyFiguresSub1 t1 ON t1.StoreIdx = pa.StoreIdx AND t1.ReceiptDateIdx = pa.ReconciliationDateIdx	
  LEFT JOIN TotalKeyFiguresSub2 t2 ON t2.StoreIdx = pa.StoreIdx AND t2.ReceiptDateIdx = pa.ReconciliationDateIdx		
  WHERE 
  ds.StoreId = @StoreId
  AND ds.IsCurrentStore = 1
  AND dd.FullDate = @Date
  AND dtt.TotalTypeId = @TotalTypeId
END 
GO

