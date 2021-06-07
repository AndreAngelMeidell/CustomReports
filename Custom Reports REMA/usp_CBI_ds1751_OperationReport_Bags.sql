USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_Bags]    Script Date: 07.02.2020 10:42:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_Bags] (@PeriodType AS char(1),
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

  ;WITH Bags AS (
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
  SELECT B.CashierId, B.CasierName, B.NumberOfBags, C.Customers,(NumberOfBags / ISNULL(NULLIF(c.Customers,0),1)) AS BagPrCustomer 
FROM bags AS B
INNER JOIN Customer C ON C.CashierId = B.CashierId AND C.CasierName = B.CasierName
  )

SELECT t.CashierId, t.CasierName, CAST(t.BagPrCustomer AS DECIMAL (20,2)) AS BagsPrCustomers, t.NumberOfBags, t.Customers  FROM totals t

END
END
GO

