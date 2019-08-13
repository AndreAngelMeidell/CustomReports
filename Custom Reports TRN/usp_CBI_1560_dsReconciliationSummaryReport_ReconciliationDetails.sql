USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_ReconciliationDetails]    Script Date: 20.09.2017 10:00:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



 
CREATE PROCEDURE [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_ReconciliationDetails]     
(
@TotalTypeId AS INT ,	
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME )
AS  
BEGIN
-- 14.09.2017: Taken from usp_RBI_0559_dsReconciliationSummaryReport_ReconciliationDetails and added daterange instead of date.  
-- 19.02.2016: Returns details about reconciliation that have been counted
--					Not counted reconciliations is not present in the DWH now.
  -----------------------------------------
   ;WITH LastReconciliationCountingPerTender AS(
		SELECT 
			 fc.ZNR
			,fc.TotalTypeIdx
			,fc.StoreIdx
			,fc.BagId
			,fc.ReconciliationStatusIdx
			,SUM(CASE WHEN dt.TenderId in ('3', '5') THEN fc.Amount ELSE NULL END) AS PaymentCard -- kort og reserveløsning
			,SUM(CASE WHEN dt.TenderId = '1' THEN fc.Amount ELSE NULL END) AS CountedCash -- kontant
			,SUM(CASE WHEN dt.TenderId = '6' THEN fc.Amount ELSE NULL END) AS AccountSale -- kundekreditt 
			,SUM(CASE WHEN dt.TenderId = '22' THEN fc.Amount ELSE NULL END) AS MobilePay -- mobil betaling
			,SUM(CASE WHEN dt.TenderId IN ('2', '19') THEN fc.Amount ELSE NULL END) AS GiftCardAndVoucher -- kupong og gavekort
			,SUM(CASE WHEN dt.TenderId = '8' THEN fc.Amount ELSE NULL END) AS CountedCurrency  -- valuta */
		FROM
		(SELECT 
			fc.ZNR
			,fc.TotalTypeIdx
			,fc.StoreIdx
			,fc.TenderIdx
			,fc.Amount 
			,fc.Rate
			,fc.BagId
			,fc.ReconciliationStatusIdx
			,fc.Unit
			,ROW_NUMBER() OVER(PARTITION BY  
									   fc.StoreIdx,
									   fc.ZNR,
									   fc.TotalTypeIdx,
									   fc.TenderIdx,
									   fc.CurrencyIdx
										ORDER BY fc.CountNo DESC) ReverseOrder
		FROM RBIM.Fact_ReconciliationCountingPerTender fc ) fc
		JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
		WHERE fc.ReverseOrder = 1
		GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.ReconciliationStatusIdx
  ),
  LastReconciliationCountingPerAccumulationType AS(
		SELECT 
			 fc.ZNR
			,fc.TotalTypeIdx
			,fc.StoreIdx
			,fc.BagId
			,fc.ReconciliationStatusIdx
			,SUM(CASE WHEN dat.AccumulationId = '7' THEN fc.Amount ELSE 0 END) AS BottleDeposit -- pant
		FROM (
		SELECT 
			fc.ZNR
			,fc.TotalTypeIdx
			,fc.StoreIdx
			,fc.AccumulationTypeIdx
			,fc.Amount 
			,fc.BagId
			,fc.ReconciliationStatusIdx
			,ROW_NUMBER() OVER(PARTITION BY  
									   fc.StoreIdx,
									   fc.ZNR,
									   fc.TotalTypeIdx,
									   fc.AccumulationTypeIdx
										ORDER BY fc.CountNo DESC) ReverseOrder
		FROM RBIM.Fact_ReconciliationCountingPerAccumulationType fc ) fc
		JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = fc.AccumulationTypeIdx
		WHERE fc.ReverseOrder = 1
		GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.ReconciliationStatusIdx
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
		GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
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
			,SUM(CASE WHEN dt.TenderId = '1' THEN f.Amount ELSE NULL END) AS Cash -- kontant
			,SUM(CASE WHEN dt.TenderId in ('3', '5') THEN f.Amount ELSE NULL END) AS PaymentCard -- kort og reserveløsning
			,SUM(CASE WHEN dt.TenderId = '6' THEN f.Amount ELSE NULL END) AS AccountSale -- kundekreditt 
			,SUM(CASE WHEN dt.TenderId = '22' THEN f.Amount ELSE NULL END) AS MobilePay -- mobil betaling
			,SUM(CASE WHEN dt.TenderId IN ('2', '19') THEN f.Amount ELSE NULL END) AS GiftCardAndVoucher -- kupong og gavekort
			,SUM(CASE WHEN dt.TenderId = '8' THEN f.Amount ELSE NULL END) AS Currency  -- valuta */
  FROM RBIM.Fact_ReconciliationSystemTotalPerTender f
  JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = f.TenderIdx
  GROUP BY f.ZNR, f.TotalTypeIdx, f.StoreIdx, f.CashRegisterIdx, f.CashierUserIdx, f.ReconciliationDateIdx, f.TillId, f.OperatorId
  ),
  TotalKeyFiguresSub1 AS (
	  SELECT 
			SUM(Amount) AS ReceiptSalesTotal
			,SUM(CASE WHEN dt.TenderId in ('3', '5') THEN f.Amount ELSE 0 END) AS TotalPaymentCard -- kort og reserveløsning
			,SUM(CASE WHEN dt.TenderId = '1' THEN f.Amount ELSE 0 END) AS TotalCash -- kontant
			,SUM(CASE WHEN dt.TenderId = '6' THEN f.Amount ELSE 0 END) AS TotalAccountSale -- kundekreditt 
			,SUM(CASE WHEN dt.TenderId = '22' THEN f.Amount ELSE 0 END) AS TotalMobilePay -- mobil betaling
			,SUM(CASE WHEN dt.TenderId IN ('2', '19') THEN f.Amount ELSE 0 END) AS TotalGiftCardAndVoucher -- kupong og gavekort
			,SUM(CASE WHEN dt.TenderId = '8' THEN f.Amount ELSE 0 END) AS TotalCurrency
	  FROM RBIM.Fact_ReceiptTender f
	  JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = f.TenderIdx
	  JOIN RBIM.Dim_Store ds ON ds.StoreIdx = f.StoreIdx
	  JOIN rbim.Dim_Date dd ON dd.DateIdx = f.ReceiptDateIdx
	  WHERE ds.StoreId = @StoreId
	  AND ds.IsCurrentStore = 1
	  AND dd.FullDate BETWEEN @DateFrom AND @DateTo 
  ),
  TotalKeyFiguresSub2 AS (
	  SELECT 
			SUM(asr.SalesAmount+asr.ReceiptRounding + asr.ReturnAmount) AS TotalSalesAmount
			,SUM(CASE WHEN da.ArticleIdx = -98 OR da.ArticleTypeId IN (130,132,133) THEN asr.SalesAmount ELSE 0 END) AS TotalBottleDeposit
	  FROM RBIM.Agg_SalesAndReturnPerDay asr
	  JOIN RBIM.Dim_Store ds ON ds.StoreIdx = asr.StoreIdx
	  JOIN rbim.Dim_Date dd ON dd.DateIdx = asr.ReceiptDateIdx
	  JOIN rbim.Dim_Article da ON da.ArticleIdx = asr.ArticleIdx
	  WHERE 
	  ds.StoreId = @StoreId
	  AND ds.IsCurrentStore = 1
	  AND dd.FullDate BETWEEN @DateFrom AND @DateTo
 )
    SELECT DISTINCT 
		CAST(pa.ZNR AS varchar(20))+'-'+CONVERT(varchar(20), dd.FullDate,4) AS ZNR
		,COALESCE(pa.OperatorId,pt.OperatorId) AS CashierId
		,ISNULL(du.FirstName,'') + ISNULL(du.LastName,'') AS Cashier
		,pa.TillId
		,ISNULL(pt.SalesAmount, 0) AS SalesAmount
		,ISNULL(pt.PaymentCard,0) AS PaymentCard
		,ISNULL(pt.Cash,0) AS Cash --SystemCash
		,ISNULL(pt.AccountSale,0) AS AccountSale
		,ISNULL(pt.MobilePay,0) AS MobilePay
		,ISNULL(pt.GiftCardAndVoucher,0) AS GiftCardAndVoucher
		,ISNULL(pt.Currency,0) AS Currency
		,ISNULL(pa.BottleDeposit,0) AS BottleDeposit
		,ISNULL(lt.CountedCash,0) AS CountedCash
		,ISNULL(lt.CountedCurrency,0) AS CountedCurrency
		,(ISNULL(lt.CountedCash,0)-ISNULL(pt.Cash,0)) AS CashDeviation
		,(ISNULL(lt.CountedCurrency,0)-ISNULL(pt.Currency,0)) AS CurrencyDeviation
		,lt.BagId
		,drs.ReconciliationStatusName
		,t2.TotalSalesAmount
		--,t1.ReceiptSalesTotal AS TotalSalesAmount
		,t1.TotalPaymentCard
		,t1.TotalCash
		,t1.TotalAccountSale
		,t1.TotalMobilePay
		,t1.TotalGiftCardAndVoucher
		,t1.TotalCurrency
		,t2.TotalBottleDeposit
  FROM systemTotalPerAccumulation pa
  LEFT JOIN SystemTotalPerTender pt ON pt.ZNR = pa.ZNR 
								AND pt.CashierUserIdx = pa.CashierUserIdx 
								AND pt.CashRegisterIdx = pa.CashRegisterIdx 
								AND pt.TotalTypeIdx = pa.TotalTypeIdx
								AND pt.StoreIdx = pa.StoreIdx
								AND ISNULL(pa.TillId,'') = ISNULL(pt.TillId,'')
  JOIN RBIM.Dim_TotalType dtt ON (dtt.TotalTypeIdx = pt.TotalTypeIdx  OR dtt.TotalTypeIdx = pa.TotalTypeIdx)
  JOIN RBIM.Dim_CashRegister dcr ON (dcr.CashRegisterIdx = pt.CashRegisterIdx OR dcr.CashRegisterIdx = pa.CashRegisterIdx)
  JOIN RBIM.Dim_User du ON (du.UserIdx = pt.CashierUserIdx OR du.UserIdx = pa.CashierUserIdx)
  JOIN RBIM.Dim_Store ds ON (ds.StoreIdx = pt.StoreIdx OR ds.StoreIdx = pa.StoreIdx)
  JOIN rbim.Dim_Date dd ON (dd.DateIdx = pt.ReconciliationDateIdx OR dd.DateIdx = pa.ReconciliationDateIdx)
  CROSS APPLY TotalKeyFiguresSub1 t1 	
  CROSS APPLY TotalKeyFiguresSub2 t2 
  LEFT JOIN lastReconciliationCountingPerTender lt ON (lt.StoreIdx = pt.StoreIdx OR lt.StoreIdx = pa.StoreIdx)
								AND (lt.TotalTypeIdx = pt.TotalTypeIdx OR lt.TotalTypeIdx = pa.TotalTypeIdx)
								AND (lt.ZNR = pt.ZNR OR	lt.ZNR = pa.ZNR)
  LEFT JOIN LastReconciliationCountingPerAccumulationType la ON (la.StoreIdx = pa.StoreIdx OR lt.StoreIdx = la.StoreIdx)
								AND (la.TotalTypeIdx = pa.TotalTypeIdx OR la.TotalTypeIdx = pa.TotalTypeIdx)
								AND (la.ZNR = pa.ZNR  OR la.ZNR = pa.ZNR)
  LEFT JOIN RBIM.Dim_ReconciliationStatus drs ON (drs.ReconciliationStatusIdx = lt.ReconciliationStatusIdx 	OR drs.ReconciliationStatusIdx = la.ReconciliationStatusIdx)						
  WHERE 
  ds.StoreId = @StoreId
  AND ds.IsCurrentStore = 1
  AND dd.FullDate BETWEEN @DateFrom AND @DateTo
  AND dtt.TotalTypeId = @TotalTypeId
  ORDER BY CAST(pa.ZNR AS varchar(20))+'-'+CONVERT(varchar(20), dd.FullDate,4)


END 
GO


