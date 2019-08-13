USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Spill]    Script Date: 24.05.2018 08:46:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Spill]     
(
	@StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME 
	)
AS  
BEGIN 

SELECT DS.StoreId, SUM(fr.Amount*ISNULL(NULLIF(fr.ExchangeRateToLocalCurrency,0.0),1.0)) AS SpilliKasse
FROM RBIM.Fact_Receipt AS FR
		INNER JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = FR.StoreIdx
		INNER JOIN RBIM.Dim_Date AS DD ON fr.ReceiptDateIdx = dd.DateIdx
		JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = FR.ArticleIdx
WHERE 1=1
		AND da.Lev4ArticleHierarchyId='241230' --Spill i kasse
		AND ds.StoreId = @StoreId
		AND dd.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY ds.StoreId

END 

GO

