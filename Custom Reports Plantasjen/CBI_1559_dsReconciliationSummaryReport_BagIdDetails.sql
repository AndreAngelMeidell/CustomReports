USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_BagIdDetails]    Script Date: 21.06.2018 13:51:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_BagIdDetails]     
(
@TotalTypeId AS INT ,	
	---------------------------------------------
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME )
AS  
BEGIN 
--Get last countings for given store, tender and totaltype
;WITH 
LastReconciliationCountingPerTender AS(
	SELECT 
		fc.ZNR
		,fc.TotalTypeIdx
		,fc.TenderIdx
		,fc.StoreIdx
		,fc.BagId
		,SUM(fc.Amount) AS Amount -- sum cash and currency counted
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
	FROM RBIM.Fact_ReconciliationCountingPerTender fc ) fc
	JOIN RBIM.Dim_Store ds ON ds.StoreIdx = fc.StoreIdx
	JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = fc.TotalTypeIdx
	JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
	WHERE fc.ReverseOrder = 1 AND ds.StoreId = @StoreId AND dt.TenderId in ('1', '8') AND dtt.TotalTypeId = @TotalTypeId
	GROUP BY fc.ZNR, fc.TotalTypeIdx, fc.StoreIdx, fc.BagId, fc.TenderIdx
),
ReconciliationDateZnr AS( -- Get all ZNRs that has selected reconciliation date 
  SELECT DISTINCT ZNR FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType st
  JOIN RBIM.Dim_Store ds ON ds.StoreIdx = st.StoreIdx
  JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = st.TotalTypeIdx
  JOIN rbim.Dim_Date dd ON dd.DateIdx = st.ReconciliationDateIdx	
  --JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = st.TenderIdx
  WHERE ds.StoreId = @StoreId 
  AND dd.FullDate = @Date 
  AND dtt.TotalTypeId = @TotalTypeId 
 -- AND dt.TenderId in ('1','8') 
  AND ds.IsCurrentStore = 1
)
  --Get sum of cash and currency(except negative numbers) for all (last)countings that has same ZNR as selected reconciliation date grouped by BagId
  SELECT lt.BagId, SUM(lt.Amount) AS Amount, COUNT(DISTINCT lt.ZNR) AS NoOfZnr FROM LastReconciliationCountingPerTender lt
  JOIN ReconciliationDateZnr Rznr ON rznr.ZNR = lt.ZNR
  --WHERE Amount > 0
  GROUP BY lt.BagId
END

GO

