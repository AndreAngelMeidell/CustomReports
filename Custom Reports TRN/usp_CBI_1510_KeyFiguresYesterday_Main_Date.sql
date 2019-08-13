USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1510_KeyFiguresYesterday_Main_Date]    Script Date: 15.01.2019 14:34:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER PROCEDURE [dbo].[usp_CBI_1510_KeyFiguresYesterday_Main_Date] 
(@DateTo AS DATE)

AS 
BEGIN
SET NOCOUNT ON;

--TRN KeyFiguresYesterday 3 tabeller
--1 av 3 --KeyFigures Yesterday OK lik PDF
IF OBJECT_ID('tempdb..#Sale') IS NOT NULL 
	DROP TABLE #Sale

DECLARE @Date1 DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @Date2 DATE = DATEADD(DAY, -2, @DateTo)
DECLARE @Date3 DATE = DATEADD(DAY, -3, @DateTo)
DECLARE @Date4 DATE = DATEADD(DAY, -4, @DateTo)
DECLARE @DateCY DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @DateLY DATE = DATEADD(DAY, -365, @DateTo)
--DECLARE @DateAccFrom DATE = (SELECT MIN(DD.PeriodStartDate) FROM  RBIM.Dim_Date AS DD WHERE DD.RelativeMonth=0)
--DECLARE @DateAccTo   DATE = (SELECT MAX(DD.PeriodEndDate) FROM  RBIM.Dim_Date AS DD WHERE DD.RelativeMonth=0)

SELECT @Date1 AS [Date],
    st.StoreId,
	st.StoreName AS Store,
	SUM(CASE WHEN d.FullDate = @DateLY THEN f.NumberOfCustomers ELSE 0 END) CustomersLY,
	SUM(CASE WHEN d.FullDate = @DateCY THEN f.NumberOfCustomers ELSE 0 END) CustomersCY,
    SUM(CASE WHEN d.FullDate = @DateLY THEN f.SalesAmountExclVat + f.ReturnAmountExclVat ELSE 0 END) AS TurnoverLY,
    SUM(CASE WHEN d.FullDate = @DateCY THEN f.SalesAmountExclVat + f.ReturnAmountExclVat ELSE 0 END) AS TurnoverCY,
	SUM(CASE WHEN d.FullDate = @DateLY THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) ItemsSoldLY,
	SUM(CASE WHEN d.FullDate = @DateCY THEN f.NumberOfArticlesSold  ELSE 0 END) ItemsSoldCY,
	SUM(CASE WHEN d.FullDate = @DateLY THEN f.NumberOfReceipts ELSE 0 END) NumberOfReceiptsLY,
	SUM(CASE WHEN d.FullDate = @DateCY THEN f.NumberOfReceipts ELSE 0 END) NumberOfReceiptsCY,
	SUM(CASE WHEN d.FullDate = @Date2 THEN f.NumberOfReceipts ELSE 0 END) NumberOfReceiptsDay2
INTO #Sale
FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
	INNER JOIN RBIM.Dim_Store st (NOLOCK) ON f.StoreIdx = st.StoreIdx
	INNER JOIN RBIM.Dim_Date d (NOLOCK) ON d.DateIdx = f.ReceiptDateIdx
WHERE d.FullDate IN (@DateLY, @DateCY, @Date2, @Date3, @Date4)
GROUP BY st.StoreId, st.StoreName


SELECT 
	s.Date,
	s.Store,
	s.CustomersLY AS CustLY,
	s.CustomersCY AS CustCY,
	CASE WHEN s.NumberOfReceiptsLY = 0  THEN 0 ELSE s.TurnoverLY/s.NumberOfReceiptsLY END AvgBuyLY,
	CASE WHEN s.NumberOfReceiptsCY = 0  THEN 0 ELSE s.TurnoverCY/s.NumberOfReceiptsCY END AvgBuyCY,
	CASE WHEN s.NumberOfReceiptsLY = 0  THEN 0 ELSE CAST(s.ItemsSoldLY AS DECIMAL(20,4))/s.NumberOfReceiptsLY END AvgItemsLY,
	CASE WHEN s.NumberOfReceiptsCY = 0  THEN 0 ELSE CAST(s.ItemsSoldCY AS DECIMAL(20,4))/s.NumberOfReceiptsCY END AvgItemsCY,
	CASE WHEN s.NumberOfReceiptsLY = 0  THEN 0 ELSE CAST(s.ItemsSoldLY AS DECIMAL(20,4))/s.NumberOfReceiptsLY+0.05 END TargetItem,
	CASE WHEN s.NumberOfReceiptsLY = 0  THEN 0 ELSE CAST(s.ItemsSoldLY AS DECIMAL(20,4)) END ItemsLY,
	CASE WHEN s.NumberOfReceiptsCY = 0	THEN 0 ELSE CAST(s.ItemsSoldCY AS DECIMAL(20,4)) END ItemsCY,
	CASE WHEN s.ItemsSoldLY = 0			THEN 0 ELSE CAST(s.TurnoverLY AS DECIMAL(20,4)) END TurnoverLY,
	CASE WHEN s.ItemsSoldCY = 0			THEN 0 ELSE CAST(s.TurnoverCY AS DECIMAL(20,4)) END TurnoverCY
FROM #Sale AS s
ORDER BY s.Store

END 


GO

