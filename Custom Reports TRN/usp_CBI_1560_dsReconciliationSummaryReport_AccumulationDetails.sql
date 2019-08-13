USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_0559_dsReconciliationSummaryReport_AccumulationDetails]    Script Date: 14.09.2017 14:03:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_AccumulationDetails]     
(
	@TotalTypeId AS INT ,	
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME )
AS  
BEGIN
-- 14.09.2017: Taken from usp_RBI_0559_dsReconciliationSummaryReport_AccumulationDetails and added daterange instead of date. 
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
			,SUM(CASE WHEN dat.AccumulationId = '11' THEN f.Amount ELSE 0 END) AS ReturnAmount -- retur belÃ¸p
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN f.Count ELSE 0 END) AS NumberOfCorrection -- antall korrigerte (Past void)
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN f.Amount ELSE 0 END) AS CorrectionAmount -- korrigerte belÃ¸p
			,SUM(CASE WHEN dat.AccumulationId = '10' THEN f.Count ELSE 0 END) AS NumberOfCanceled -- antall kansellerte
			,SUM(CASE WHEN dat.AccumulationId = '19' THEN f.Count ELSE 0 END) AS Price -- prisforespÃ¸rsel
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
			,SUM(CASE WHEN dat.AccumulationId = '11' THEN fc.Amount ELSE NULL END) AS ReturnAmount -- retur belÃ¸p
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN fc.Amount ELSE NULL END) AS CorrectionAmount -- korrigerte belÃ¸p (Past void)
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
  )
  SELECT DISTINCT 
		CAST(pa.ZNR AS varchar(20))+'-'+CONVERT(varchar(20), dd.FullDate,4) AS ZNR
		,COALESCE(pa.OperatorId,pt.OperatorId) AS CashierId
		,ISNULL(du.FirstName,'') + ISNULL(du.LastName,'') AS Cashier
		,pa.TillId
		,ISNULL(pa.NumberOfCustomers, 0) AS NumberOfCustomers
		,ISNULL(pt.SalesAmount, 0) AS SalesAmount
		,ISNULL(pa.NumberOfReturn, 0) AS NumberOfReturn
        ,COALESCE(NULLIF(la.ReturnAmount,0),pa.ReturnAmount, 0) AS ReturnAmount --(RS-29807)
		,ISNULL(pa.NumberOfCorrection, 0) AS NumberOfCorrection
		,COALESCE(NULLIF(la.CorrectionAmount,0), pa.CorrectionAmount, 0) AS CorrectionAmount  --(RS-29807)
		,ISNULL( pa.NumberOfCanceled, 0) AS NumberOfCanceled
		,ISNULL(pa.Price, 0) AS Price
		,ISNULL(pa.Discount, 0) AS Discount
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
  WHERE 
  ds.StoreId = @StoreId
  AND ds.IsCurrentStore = 1
  AND dd.FullDate BETWEEN @DateFrom AND @DateTo
  AND dtt.TotalTypeId = @TotalTypeId
END 

GO


