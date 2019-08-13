USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_VatGroupDetails]    Script Date: 19.10.2018 09:50:20 ******/
DROP PROCEDURE [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_VatGroupDetails]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_VatGroupDetails]    Script Date: 19.10.2018 09:50:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




 
CREATE PROCEDURE [dbo].[usp_CBI_1560_dsReconciliationSummaryReport_VatGroupDetails]     
(
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME )
AS  
BEGIN
-- 14.09.2017: Taken from usp_RBI_0559_dsReconciliationSummaryReport_VatGroupDetails and added daterange instead of date. 
-- 19.02.2016: Returns details about reconciliation that have been counted
--					Not counted reconciliations is not present in the DWH now.

--17.10.2018 AM extended to inkude Botteldeposit
  -----------------------------------------

; WITH MVA AS (
SELECT 
	ds.StoreId
	,agg.VatGroup
	,SUM(agg.SalesAmount + agg.ReturnAmount) AS SalesAmount
	,SUM(agg.SalesVatAmount + agg.ReturnVatAmount) AS SalesVatAmount
	,SUM(agg.SalesAmountExclVat + agg.ReturnAmountExclVat) AS SalesAmountExclVat
	,0 AS BottleDepositSalesAmount
	,0 AS SalesNoBottle
FROM RBIM.Agg_VatGroupSalesAndReturnPerDay agg
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = agg.StoreIdx
	JOIN rbim.Dim_Date dd ON dd.DateIdx = agg.ReceiptDateIdx
WHERE 
	ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1
	AND dd.FullDate BETWEEN @DateFrom AND @DateTo	
GROUP BY agg.VatGroup, ds.StoreId
)
, Pant AS (

SELECT 
	ds.StoreId
    ,SUM(f.BottleDepositSalesAmount) AS BottleDepositSalesAmount
	,SUM(f.SalesAmount+f.ReturnAmount-f.BottleDepositSalesAmount) AS SalesNoBottle
  FROM RBIM.Agg_CashierSalesAndReturnPerHour AS f
  INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx
  INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = f.StoreIdx 
  INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
WHERE 
	ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1
	AND dd.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY ds.StoreId
)

SELECT m.VatGroup, m.SalesAmount, m.SalesVatAmount, m.SalesAmountExclVat,P.BottleDepositSalesAmount, P.SalesNoBottle FROM  MVA m 
JOIN pant P ON m.storeId=p.StoreId 


END 

GO

