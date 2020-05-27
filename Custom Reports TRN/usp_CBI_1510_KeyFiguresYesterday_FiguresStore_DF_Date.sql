USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1510_KeyFiguresYesterday_FiguresStore_DF_Date]    Script Date: 15.04.2020 09:53:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1510_KeyFiguresYesterday_FiguresStore_DF_Date] 
(@DateTo AS DATE)

AS 
BEGIN
SET NOCOUNT ON;

--2 av 3 Figures Store

IF OBJECT_ID('tempdb..#Sale') IS NOT NULL 
	DROP TABLE #Sale

IF OBJECT_ID('tempdb..#SaleACC') IS NOT NULL 
	DROP TABLE #SaleACC

DECLARE @Date1 DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @Date2 DATE = DATEADD(DAY, -2, @DateTo)
DECLARE @Date3 DATE = DATEADD(DAY, -3, @DateTo)
DECLARE @Date4 DATE = DATEADD(DAY, -4, @DateTo)
DECLARE @DateCY DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @DateLY DATE = DATEADD(DAY, -365, @DateTo)
DECLARE @DateAccFrom DATE = (select dateadd(mm,datediff(mm,0,@Date1),0)) --(SELECT MIN(DD.PeriodStartDate) FROM  RBIM.Dim_Date AS DD WHERE DD.RelativeMonth=0)
DECLARE @DateAccTo   DATE = @Date1 --(SELECT MAX(DD.PeriodEndDate) FROM  RBIM.Dim_Date AS DD WHERE DD.RelativeMonth=0)


SELECT @Date1 AS [Date],
    st.StoreId,
	MAX(st.CurrentStoreName) AS Store,
	SUM(CASE WHEN d.FullDate = @DateLY THEN f.NumberOfCustomers ELSE 0 END) CustomersLY,
	SUM(CASE WHEN d.FullDate = @DateCY THEN f.NumberOfCustomers ELSE 0 END) CustomersCY,
    SUM(CASE WHEN d.FullDate = @DateLY THEN f.SalesAmountExclVat + f.ReturnAmountExclVat ELSE 0 END) AS TurnoverLY,
    SUM(CASE WHEN d.FullDate = @DateCY THEN f.SalesAmountExclVat + f.ReturnAmountExclVat ELSE 0 END) AS TurnoverCY,
    SUM(CASE WHEN d.FullDate = @Date2 THEN f.SalesAmountExclVat + f.ReturnAmountExclVat ELSE 0 END) AS TurnoverDay2,
    SUM(CASE WHEN d.FullDate = @Date3 THEN f.SalesAmountExclVat + f.ReturnAmountExclVat ELSE 0 END) AS TurnoverDay3,
    SUM(CASE WHEN d.FullDate = @Date4 THEN f.SalesAmountExclVat + f.ReturnAmountExclVat ELSE 0 END) AS TurnoverDay4,
	SUM(CASE WHEN d.FullDate = @DateLY THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) ItemsSoldLY,
	SUM(CASE WHEN d.FullDate = @DateCY THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) ItemsSoldCY,
	SUM(CASE WHEN d.FullDate = @DateLY THEN f.NumberOfCustomers ELSE 0 END) NumberOfReceiptsLY,
	SUM(CASE WHEN d.FullDate = @DateCY THEN f.NumberOfCustomers ELSE 0 END) NumberOfReceiptsCY,
	SUM(CASE WHEN d.FullDate = @Date2 THEN f.NumberOfCustomers ELSE 0 END) NumberOfReceiptsDay2
	,@DateLY AS LastYear
INTO #Sale
FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
	INNER JOIN RBIM.Dim_Store st (NOLOCK) ON f.StoreIdx = st.StoreIdx
	INNER JOIN RBIM.Dim_Date d (NOLOCK) ON d.DateIdx = f.ReceiptDateIdx
WHERE d.FullDate IN (@DateLY, @DateCY, @Date2, @Date3, @Date4)
AND st.StoreName NOT LIKE '%TV%'
GROUP BY st.StoreId

SELECT 
    st.StoreId
	,MAX(st.StoreDisplayId) AS Store
	,SUM(f.NumberOfCustomers) AS CustomerACC
	,SUM(NumberOfArticlesSold - f.NumberOfArticlesInReturn) AS ItemSoldACC
	,SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat) AS TurnOverAcc
INTO #SaleACC
FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
	INNER JOIN RBIM.Dim_Store st (NOLOCK) ON f.StoreIdx = st.StoreIdx
	INNER JOIN RBIM.Dim_Date d (NOLOCK) ON d.DateIdx = f.ReceiptDateIdx
WHERE d.FullDate BETWEEN @DateAccFrom AND @DateAccTo
AND st.StoreName NOT LIKE '%TV%'
GROUP BY st.StoreId

SELECT 
	s.*,
	sa.TurnOverAcc,
	sa.TurnOverAcc/sa.CustomerACC AS AccAvgCustomer,
	CONVERT(DECIMAL(19,5),sa.CustomerACC) AS CustomersACC,
	CONVERT(DECIMAL(19,5),sa.ItemSoldACC) AS ItemsSoldACC,
	--CONVERT(DECIMAL(19,5),sa.ItemSoldACC)/CONVERT(DECIMAL(19,5),sa.CustomerACC) AS ACCAvgItem,
	--CONVERT(DECIMAL(19,5),sa.TurnOverAcc)/CONVERT(DECIMAL(19,5),sa.ItemSoldACC) AS AvgPricePerItemACC,
	CASE WHEN sa.CustomerACC = 0 THEN 0 ELSE CONVERT(DECIMAL(19,5),sa.ItemSoldACC)/CONVERT(DECIMAL(19,5),sa.CustomerACC) END ACCAvgItem,
	CASE WHEN sa.ItemSoldACC = 0 THEN 0 ELSE CONVERT(DECIMAL(19,5),sa.TurnOverAcc)/CONVERT(DECIMAL(19,5),sa.ItemSoldACC) END AvgPricePerItemACC,
	CASE WHEN s.NumberOfReceiptsLY = 0 THEN 0 ELSE s.TurnoverLY/s.NumberOfReceiptsLY END AvgTurnoverLY,
	CASE WHEN s.NumberOfReceiptsCY = 0 THEN 0 ELSE s.TurnoverCY/s.NumberOfReceiptsCY END AvgTurnoverCY,
	CASE WHEN s.NumberOfReceiptsDay2 = 0 THEN 0 ELSE s.TurnoverDay2/s.NumberOfReceiptsDay2 END AvgTurnoverDay2,
	CASE WHEN s.NumberOfReceiptsLY = 0 THEN 0 ELSE CAST(s.ItemsSoldLY AS DECIMAL(20,4))/s.NumberOfReceiptsLY END AvgItemsLY,
	CASE WHEN s.NumberOfReceiptsCY = 0 THEN 0 ELSE CAST(s.ItemsSoldCY AS DECIMAL(20,4))/s.NumberOfReceiptsCY END AvgItemsCY,
	CASE WHEN s.ItemsSoldLY = 0 THEN 0 ELSE CAST(s.TurnoverLY AS DECIMAL(20,4))/s.ItemsSoldLY END AvgPricePerItemLY,
	CASE WHEN s.ItemsSoldCY = 0 THEN 0 ELSE CAST(s.TurnoverCY AS DECIMAL(20,4))/s.ItemsSoldCY END AvgPricePerItemCY
FROM #Sale AS s
JOIN #SaleACC AS SA ON SA.StoreId = s.StoreId
ORDER BY s.Store

END 



GO

