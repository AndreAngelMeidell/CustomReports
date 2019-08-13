USE [BI_Mart]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1161_dsReturnPerTillNoReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1161_dsReturnPerTillNoReport_data]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_CBI_1161_dsReturnPerTillNoReport_data]
(   
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@StoreOrGroupNo AS VARCHAR(8000),
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
	Stores AS (
		SELECT *	
		FROM RBIM.Dim_Store ds (NOLOCK)
		LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue = ds.StoreId
		WHERE n.ParameterValue IS NOT NULL
		AND ds.IsCurrentStore = 1
	),
	TotalSales AS (
		SELECT f.storeIdx,
				 f.ReceiptDateIdx,
				SUM(f.ReturnAmount) AS TotalReturnAmount -- + f.ReceiptRounding)
		FROM [BI_Mart].[RBIM].[Agg_SalesAndReturnPerDay] f (NOLOCK)
		JOIN Stores s ON s.StoreIdx = f.StoreIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
		GROUP BY f.StoreIdx, f.ReceiptDateIdx
	),
	TillReceipts AS (
	  SELECT DISTINCT CashRegisterNo, 
					f.StoreIdx, 
					f.ReceiptDateIdx,
					ReceiptId				
	  FROM [BI_Mart].[RBIM].[Fact_ReceiptRowSalesAndReturn] f (NOLOCK)
	  JOIN Stores s ON s.StoreIdx = f.StoreIdx
	  WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
				AND f.ReturnAmount < 0
	), 
	TendersForTill AS (
		SELECT f.StoreIdx,
				 f.ReceiptDateIdx,
				COUNT(DISTINCT f.ReceiptId) AS NumberOfCustomers,
				SUM(CASE WHEN f.TenderIdx in (1,8) THEN f.Amount ELSE 0 END ) AS CashAmount,
				SUM(CASE WHEN f.TenderIdx = 3 THEN f.Amount ELSE 0 END ) AS PaymentcardAmount
		FROM [BI_Mart].[RBIM].[Fact_ReceiptTender] f (NOLOCK)
		JOIN TillReceipts t ON  t.StoreIdx = f.StoreIdx AND t.CashRegisterNo = f.CashRegisterNo AND t.ReceiptId = f.ReceiptId AND f.ReceiptDateIdx = t.ReceiptDateIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
		AND f.TenderIdx IN (1,3,8)
		GROUP BY f.StoreIdx, f.ReceiptDateIdx--, f.CashRegisterNo
	)
	SELECT stores.StoreId,
			stores.StoreName,
			--d.FullDate AS Date,
			SUM(s.TotalReturnAmount) AS ReturnAmount, -- + tr.ReceiptRounding)
			SUM(t.NumberOfCustomers) AS NumberOfCustomers,
			SUM(t.CashAmount) AS CashAmount,
			SUM(t.PaymentcardAmount) AS PaymentcardAmount,
			SUM(s.TotalReturnAmount) AS TotalReturnAmount
	FROM TotalSales s
	--JOIN RBIM.Dim_Date d ON d.DateIdx = s.ReceiptDateIdx
	JOIN Stores stores ON stores.StoreIdx = s.StoreIdx 
	LEFT JOIN TendersForTill t ON  s.StoreIdx = t.StoreIdx AND s.ReceiptDateIdx = t.ReceiptDateIdx
	GROUP BY Stores.StoreId, Stores.StoreName--, d.FullDate
	ORDER BY stores.StoreId ASC--, d.FullDate ASC	
END
ELSE
BEGIN
	;WITH 
	Stores AS (
		SELECT *	
		FROM RBIM.Dim_Store ds (NOLOCK)
		LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue = ds.StoreId
		WHERE n.ParameterValue IS NOT NULL
		AND ds.IsCurrentStore = 1
	),
	TotalSales AS (
		SELECT f.storeIdx,
				f.ReceiptDateIdx,
				SUM(f.ReturnAmount) AS TotalReturnAmount -- + f.ReceiptRounding)
		FROM [BI_Mart].[RBIM].[Agg_SalesAndReturnPerDay] f (NOLOCK)
		JOIN Stores s ON s.StoreIdx = f.StoreIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
		GROUP BY f.StoreIdx, f.ReceiptDateIdx
	),
	TillReceipts AS (
	  SELECT f.ReceiptId,
				f.CashRegisterNo,
				f.StoreIdx,
				f.ReceiptDateIdx,
				f.ReturnAmount,
				f.ReceiptRounding		
	  FROM [BI_Mart].[RBIM].[Fact_ReceiptRowSalesAndReturn] f (NOLOCK)
	  JOIN Stores s ON s.StoreIdx = f.StoreIdx
	  WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
				AND f.TillId = @tillId
				AND f.ReturnAmount < 0
	), 
	TillReturn AS (
		SELECT f.StoreIdx,
				f.ReceiptDateIdx,
				SUM(f.ReturnAmount) AS ReturnAmount,
				SUM(f.ReceiptRounding) AS ReceiptRounding
		FROM TillReceipts f
		GROUP BY f.StoreIdx, f.ReceiptDateIdx
	),
	TendersForTill AS (
		SELECT f.StoreIdx,
				f.ReceiptDateIdx,
				COUNT(DISTINCT f.ReceiptId) AS NumberOfCustomers,
				SUM(CASE WHEN f.TenderIdx in (1,8) THEN f.Amount ELSE 0 END ) AS CashAmount,
				SUM(CASE WHEN f.TenderIdx = 3 THEN f.Amount ELSE 0 END ) AS PaymentcardAmount
		FROM [BI_Mart].[RBIM].[Fact_ReceiptTender] f (NOLOCK)
		JOIN TillReceipts t ON  t.ReceiptId = f.ReceiptId AND t.CashRegisterNo = f.CashRegisterNo AND t.StoreIdx = f.StoreIdx
		WHERE f.ReceiptDateIdx BETWEEN @dateFromIdx AND @dateToIdx
		AND f.TenderIdx IN (1,3,8)
		--AND t.ReturnAmount < 0
		GROUP BY f.StoreIdx, f.ReceiptDateIdx
	)
	SELECT stores.StoreId,
			stores.StoreName,
			--d.FullDate AS Date,
			SUM(tr.ReturnAmount) AS ReturnAmount, -- + tr.ReceiptRounding)
			SUM(t.NumberOfCustomers) AS NumberOfCustomers,
			SUM(t.CashAmount) AS CashAmount,
			SUM(t.PaymentcardAmount) AS PaymentcardAmount,
			SUM(s.TotalReturnAmount) AS TotalReturnAmount
	FROM TotalSales s
	--JOIN RBIM.Dim_Date d ON d.DateIdx = s.ReceiptDateIdx
	JOIN Stores stores ON stores.StoreIdx = s.StoreIdx
	LEFT JOIN TillReturn tr ON s.StoreIdx = tr.StoreIdx AND s.ReceiptDateIdx = tr.ReceiptDateIdx
	LEFT JOIN TendersForTill t ON  s.StoreIdx = t.StoreIdx AND s.ReceiptDateIdx = t.ReceiptDateIdx
	GROUP BY Stores.StoreId, Stores.StoreName--, d.FullDate
	ORDER BY stores.StoreId ASC--, d.FullDate ASC		
END

END
