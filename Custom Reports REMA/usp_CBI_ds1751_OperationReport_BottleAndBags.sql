USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_BottleAndBags]    Script Date: 07.02.2020 10:42:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_BottleAndBags] (@PeriodType AS char(1),
@DateFrom AS datetime,
@DateTo AS datetime,
@YearToDate AS integer,
@RelativePeriodType AS char(5),
@RelativePeriodStart AS integer,
@RelativePeriodDuration AS integer,
@StoreId varchar(50))
AS

BEGIN
set TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
END
ELSE BEGIN
--if (@DateFrom is null) set @DateFrom = convert(date,getdate()-1) set @DateTo = convert(date,getdate()-1)
;WITH Bottel AS (
  SELECT
    CashierId,
    CasierName,
    SalesRevenueInclVat, --{RS-27230} 
    BottleDepositSalesAmount,
    BottleDepositSalePctVsRegSales,
    BottleDepositReturnAmount,
    BottleDepositManualReturnQty,
    BottleDepositManualReturnAmount,
    LotteryReceiptRedeemed
  FROM ((SELECT
    a.CashierId,
    a.CasierName,
    a.SalesAmount + a.ReturnAmount AS SalesRevenueInclVat,
    a.BottleDepositSalesAmount + ISNULL(b.BottleDepositReturnAmt, 0) AS BottleDepositSalesAmount,
    ISNULL((a.BottleDepositSalesAmount + ISNULL(b.BottleDepositReturnAmt, 0)) / NULLIF((a.SalesAmount + a.ReturnAmount),0),0) AS BottleDepositSalePctVsRegSales, --{RS-31366} Division by zero fixed 
    a.BottleDepositReturnAmount AS BottleDepositReturnAmount,
    a.BottleDepositManualReturnQty,
    a.BottleDepositManualReturnAmount AS BottleDepositManualReturnAmount,
    0 AS LotteryReceiptRedeemed
  FROM (SELECT
    ISNULL(su.UserNameID,'') AS CashierId,
    su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName,
    SUM(f.SalesAmount) AS SalesAmount,
    SUM(f.ReturnAmount) AS ReturnAmount,
    SUM(f.BottleDepositSalesAmount) AS BottleDepositSalesAmount,
    SUM(f.BottleDepositReturnAmount) AS BottleDepositReturnAmount,
    SUM(f.NumberOfReceiptsWithBottleDepositManualReturn) AS BottleDepositManualReturnQty,
    SUM(f.BottleDepositManualReturnAmount) AS BottleDepositManualReturnAmount
  FROM RBIM.Agg_CashierSalesAndReturnPerHour AS f
  INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx
  INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = f.StoreIdx AND ds.StoreId = @StoreId AND IsCurrentStore = 1
  INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
  WHERE (@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
  OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1)
  GROUP BY su.UserNameID,su.FirstName,su.LastName) a
  LEFT JOIN (SELECT
    ISNULL(su.UserNameID,'') AS CashierId,
    su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName,
    SUM(CASE
      WHEN a.ArticleTypeId = 130 THEN agg.ReturnAmount
      ELSE 0
    END) AS BottleDepositReturnAmt
  FROM RBIM.Agg_SalesAndReturnPerHour AS agg (NOLOCK)
  INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = agg.ReceiptDateIdx
  INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = agg.StoreIdx AND ds.StoreId = @StoreId AND IsCurrentStore = 1
  INNER JOIN RBIM.Dim_Article AS a (NOLOCK) ON a.ArticleIdx = agg.ArticleIdx
  INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = agg.SystemUserIdx
  WHERE a.ArticleTypeId = 130 AND agg.ReturnAmount != 0
  AND (@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo 
  OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
  OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1)
  GROUP BY su.UserNameID,su.FirstName,su.LastName) b
    ON a.CashierId = b.CashierId
    AND a.CasierName = b.CasierName)

  UNION ALL
  SELECT
    ISNULL(su.UserNameID,'') AS CashierId,
    su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName,
    0 AS SalesRevenueInclVat --{RS-27230}
    ,
    0 AS BottleDepositSalesAmount,
    0 AS BottleDepositSalePctVsRegSales,
    0 AS BottleDepositReturnAmount,
    0 AS BottleDepositManualReturnQty,
    0 AS BottleDepositManualReturnAmount,
    SUM(f.TotalAmount) AS LotteryReceiptRedeemed
  FROM RBIM.Agg_RvmReceiptPerDay AS f
  INNER JOIN RBIM.Dim_Date AS dd
    ON dd.DateIdx = f.DateIdx
  INNER JOIN RBIM.Dim_Store AS ds
    ON ds.StoreIdx = f.StoreIdx
    AND ds.StoreId = @StoreId
  INNER JOIN RBIM.Dim_User AS su
    ON su.UserIdx = f.CashierUserIdx
  INNER JOIN RBIM.Dim_TransType AS tt
    ON tt.TransTypeIdx = f.TransTypeIdx
  WHERE (@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
  OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
  OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1)
  AND (tt.TransTypeId = 90307)
  GROUP BY su.UserNameID,su.FirstName,su.LastName) AS sub
  )
  ,Bags AS (
SELECT
    ISNULL(su.UserNameID,'') AS CashierId,
    su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName,
	SUM(agg.NumberOfArticlesSold-agg.NumberOfArticlesInReturn) AS NumberOfBags
  FROM RBIM.Agg_SalesAndReturnPerDay AS agg (NOLOCK)
  INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = agg.ReceiptDateIdx
  INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = agg.StoreIdx AND ds.StoreId = @StoreId AND IsCurrentStore = 1
  INNER JOIN RBIM.Dim_Article AS a (NOLOCK) ON a.ArticleIdx = agg.ArticleIdx
  INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = agg.SystemUserIdx 
  INNER JOIN RBIM.Dim_Gtin AS DG ON DG.GtinIdx = agg.GtinIdx
 WHERE dg.Gtin='999' 
  AND (@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
  OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
  OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1) 
  GROUP BY su.UserNameID,su.FirstName,su.LastName 
  )
  ,
  Customer AS ( 
  SELECT
  ISNULL(su.UserNameID,'') AS CashierId,
  su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName,
  CAST(SUM(agg.NumberOfCustomers) AS DECIMAL(20,4)) AS Customers
  FROM RBIM.Agg_SalesAndReturnPerDay AS agg (NOLOCK)
  INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = agg.ReceiptDateIdx
  INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = agg.StoreIdx AND ds.StoreId = @StoreId AND IsCurrentStore = 1
  INNER JOIN RBIM.Dim_Article AS a (NOLOCK) ON a.ArticleIdx = agg.ArticleIdx
  INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = agg.SystemUserIdx 
  INNER JOIN RBIM.Dim_Gtin AS DG ON DG.GtinIdx = agg.GtinIdx
 WHERE 1=1 
  AND (@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
  OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
  OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
  OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1) 
  GROUP BY su.UserNameID,su.FirstName,su.LastName 
  )
  , totals AS (
  SELECT B.CashierId, B.CasierName, B.NumberOfBags, C.Customers,(NumberOfBags / c.Customers) AS BagPrCustomer 
FROM bags AS B
INNER JOIN Customer C ON C.CashierId = B.CashierId AND C.CasierName = B.CasierName
  )

SELECT B.*, CAST(t.BagPrCustomer AS DECIMAL (20,2)) AS BagPrCustomer  FROM totals t
JOIN Bottel B ON B.CasierName=T.CasierName





END
END
GO

