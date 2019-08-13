USE [BI_Mart]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1161_dsReturnPerTillNoSubReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1161_dsReturnPerTillNoSubReport_data]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_CBI_1161_dsReturnPerTillNoSubReport_data]
(   
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@StoreId AS VARCHAR(8000),
	@TillId AS VARCHAR(100)

) 
AS  
BEGIN
  
------------------------------------------------------------------------------------------------------

DECLARE @dateFromIdx INT = (SELECT DISTINCT DateIdx FROM RBIM.Dim_Date (NOLOCK) WHERE FullDate = @dateFrom),
@dateToIdx INT = (SELECT DISTINCT DateIdx FROM RBIM.Dim_Date (NOLOCK) WHERE FullDate = @dateTo) 

IF RTRIM(LTRIM(@TillId)) = '*' -- search for return on all tills
BEGIN 
	;WITH 
	TotalSales AS (
		SELECT f.ReceiptDateIdx,
					SUM(f.ReturnAmount) AS TotalReturnAmount -- + f.ReceiptRounding)
		FROM [BI_Mart].[RBIM].[Agg_SalesAndReturnPerDay] f (NOLOCK)
		JOIN [BI_Mart].[RBIM].[Dim_Store] ds (NOLOCK) ON ds.StoreIdx = f.StoreIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
				AND ds.StoreId = @StoreId
		GROUP BY f.ReceiptDateIdx
	),
	TillReceipts AS (
	  SELECT DISTINCT CashRegisterNo, 
					f.StoreIdx, 
					f.ReceiptDateIdx,
					ReceiptId				
	  FROM [BI_Mart].[RBIM].[Fact_ReceiptRowSalesAndReturn] f (NOLOCK)
	  JOIN [BI_Mart].[RBIM].[Dim_Store] ds (NOLOCK) ON ds.StoreIdx = f.StoreIdx
	  WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
				AND ds.StoreId = @StoreId
				AND f.ReturnAmount < 0
	), 
	TendersForTill AS (
		SELECT f.ReceiptDateIdx,
				COUNT(DISTINCT f.ReceiptId) AS NumberOfCustomers,
				SUM(CASE WHEN f.TenderIdx in (1,8) THEN f.Amount ELSE 0 END ) AS CashAmount,
				SUM(CASE WHEN f.TenderIdx = 3 THEN f.Amount ELSE 0 END ) AS PaymentcardAmount
		FROM [BI_Mart].[RBIM].[Fact_ReceiptTender] f (NOLOCK)
		JOIN TillReceipts t ON  t.StoreIdx = f.StoreIdx AND t.CashRegisterNo = f.CashRegisterNo AND t.ReceiptId = f.ReceiptId AND t.ReceiptDateIdx = f.ReceiptDateIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
		AND f.TenderIdx IN (1,3,8)
		GROUP BY f.ReceiptDateIdx
	)
	SELECT --ds.StoreId,
			--ds.StoreName,
			d.FullDate AS Date,
			SUM(s.TotalReturnAmount) AS ReturnAmount, -- + tr.ReceiptRounding)
			SUM(t.NumberOfCustomers) AS NumberOfCustomers,
			SUM(t.CashAmount) AS CashAmount,
			SUM(t.PaymentcardAmount) AS PaymentcardAmount,
			SUM(s.TotalReturnAmount) AS TotalReturnAmount
	FROM TotalSales s
	JOIN RBIM.Dim_Date d ON d.DateIdx = s.ReceiptDateIdx
	LEFT JOIN TendersForTill t ON s.ReceiptDateIdx = t.ReceiptDateIdx
	GROUP BY d.FullDate
	ORDER BY d.FullDate ASC	
END
ELSE
BEGIN
	;WITH 
	TotalSales AS (
		SELECT f.ReceiptDateIdx,
				SUM(f.ReturnAmount) AS TotalReturnAmount -- + f.ReceiptRounding)
		FROM [BI_Mart].[RBIM].[Agg_SalesAndReturnPerDay] f (NOLOCK)
		JOIN [BI_Mart].[RBIM].[Dim_Store] ds (NOLOCK) ON ds.StoreIdx = f.StoreIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
				AND ds.StoreId = @StoreId
		GROUP BY f.ReceiptDateIdx
	),
	TillReceipts AS (
	  SELECT f.ReceiptId,
				f.CashRegisterNo,
				f.StoreIdx,
				f.ReceiptDateIdx,
				f.ReturnAmount,
				f.ReceiptRounding	
	  FROM [BI_Mart].[RBIM].[Fact_ReceiptRowSalesAndReturn] f (NOLOCK)
	  JOIN [BI_Mart].[RBIM].[Dim_Store] ds (NOLOCK) ON ds.StoreIdx = f.StoreIdx
	  WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
				AND f.TillId = @tillId
				AND ds.StoreId = @StoreId
				AND f.ReturnAmount < 0
	), 
	TillReturn AS (
		SELECT --f.StoreIdx,
				f.ReceiptDateIdx,
				SUM(f.ReturnAmount) AS ReturnAmount,
				SUM(f.ReceiptRounding) AS ReceiptRounding
		FROM TillReceipts f
		GROUP BY f.ReceiptDateIdx
	),
	TendersForTill AS (
		SELECT --f.StoreIdx,
				f.ReceiptDateIdx,
				COUNT(DISTINCT f.ReceiptId) AS NumberOfCustomers,
				SUM(CASE WHEN f.TenderIdx in (1,8) THEN f.Amount ELSE 0 END ) AS CashAmount,
				SUM(CASE WHEN f.TenderIdx = 3 THEN f.Amount ELSE 0 END ) AS PaymentcardAmount
		FROM [BI_Mart].[RBIM].[Fact_ReceiptTender] f (NOLOCK)
		JOIN TillReceipts t ON  t.ReceiptId = f.ReceiptId AND t.CashRegisterNo = f.CashRegisterNo AND t.StoreIdx = f.StoreIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
		AND f.TenderIdx IN (1,3,8)
		GROUP BY  f.ReceiptDateIdx
	)
	SELECT --stores.StoreId,
			--stores.StoreName,
			d.FullDate AS Date,
			SUM(tr.ReturnAmount) AS ReturnAmount, -- + tr.ReceiptRounding)
			SUM(t.NumberOfCustomers) AS NumberOfCustomers,
			SUM(t.CashAmount) AS CashAmount,
			SUM(t.PaymentcardAmount) AS PaymentcardAmount,
			SUM(s.TotalReturnAmount) AS TotalReturnAmount
	FROM TotalSales s
	JOIN RBIM.Dim_Date d ON d.DateIdx = s.ReceiptDateIdx
	--JOIN Stores stores ON stores.StoreIdx = s.StoreIdx
	LEFT JOIN TillReturn tr ON s.ReceiptDateIdx = tr.ReceiptDateIdx
	LEFT JOIN TendersForTill t ON s.ReceiptDateIdx = t.ReceiptDateIdx
	GROUP BY d.FullDate
	ORDER BY d.FullDate ASC		
END


END
