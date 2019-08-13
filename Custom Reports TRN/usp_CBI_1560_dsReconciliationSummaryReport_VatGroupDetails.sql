USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_0559_dsReconciliationSummaryReport_VatGroupDetails]    Script Date: 14.09.2017 14:07:33 ******/
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
  -----------------------------------------
SELECT 
	agg.VatGroup
	,SUM(agg.SalesAmount + agg.ReturnAmount) AS SalesAmount
	,SUM(agg.SalesVatAmount + agg.ReturnVatAmount) AS SalesVatAmount
	,SUM(agg.SalesAmountExclVat + agg.ReturnAmountExclVat) AS SalesAmountExclVat
FROM RBIM.Agg_VatGroupSalesAndReturnPerDay agg
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = agg.StoreIdx
	JOIN rbim.Dim_Date dd ON dd.DateIdx = agg.ReceiptDateIdx
WHERE 
	ds.StoreId = @StoreId
	AND ds.IsCurrentStore = 1
	AND dd.FullDate BETWEEN @DateFrom AND @DateTo	
GROUP BY agg.VatGroup

END 
GO


