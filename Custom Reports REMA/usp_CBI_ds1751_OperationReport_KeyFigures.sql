USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_KeyFigures]    Script Date: 07.02.2020 10:43:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_KeyFigures]
( @PeriodType AS CHAR(1), 
  @DateFrom AS DATETIME,
  @DateTo AS DATETIME,
  @YearToDate AS INTEGER, 
  @RelativePeriodType AS CHAR(5),
  @RelativePeriodStart AS INTEGER, 
  @RelativePeriodDuration AS INTEGER ,
  @StoreId INT)
AS

BEGIN
set TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 

-- 19-10-18 Change to inklude Bags

IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
END
ELSE BEGIN

;WITH Orginal AS (
SELECT      
  CashierId,
  CasierName,
  --SUM(SalesAmount) AS TotalRegTrans, --{RS-27230} 
  SUM(SalesAmount+ReturnAmount) AS TotalRegTrans, --{RS-27230} all returns and all sales, 3.rd sales included.
  --SUM(isnull(SalesAmount,0)) - SUM(ISNULL(Pos3rdPartySalesAmount,0)) AS RegisteredArticleSales, --{RS-27230} 
  SUM(ISNULL(SalesAmount,0)+ISNULL(ReturnAmount,0)) - SUM(ISNULL(Pos3rdPartySalesAmount,0)+ISNULL(Pos3rdPartyReturnAmount,0)) AS RegisteredArticleSales, --{RS-27230} all returns and all sales, 3.rd sales excluded.
  SUM(NumberOfCustomers) - SUM(NumberOfReceiptsWithOnly3rdPartySales) AS NumberOfCustomers, 
  --ISNULL(SUM(SalesAmount - Pos3rdPartySalesAmount) / NULLIF (SUM(NumberOfCustomers - NumberOfReceiptsWithOnly3rdPartySales), 0),0) AS AvgSalesPerCustomer, --{RS-27230} 
  ISNULL((SUM(SalesAmount+ReturnAmount) - SUM(Pos3rdPartySalesAmount+Pos3rdPartyReturnAmount)) / NULLIF (SUM(NumberOfCustomers - NumberOfReceiptsWithOnly3rdPartySales), 0),0) AS AvgSalesPerCustomer, --{RS-27230} 
  ISNULL((SUM(QuantityOfScannableArticles - QuantityOf3rdPartyScannableArticles) / NULLIF (CAST(SUM(QuantityOfArticlesWithout3rdParty) AS FLOAT), 0.0)) , 0) AS ScannableArticlesPercentageExcl3rdParty, --{RS-37977}
  ISNULL((SUM(QuantityOfScannedArticles - QuantityOf3rdPartyScannedArticles) / NULLIF (CAST(SUM(QuantityOfScannableArticles - QuantityOf3rdPartyScannableArticles) AS FLOAT), 0.0)) , 0) AS ScannedArticlesPercentageExcl3rdParty, --{RS-37977}
  --SUM(Pos3rdPartySalesAmount) AS [3rdPartySales], --{RS-27230} 
  SUM(Pos3rdPartySalesAmount+Pos3rdPartyReturnAmount) AS [3rdPartySales],--{RS-27230} all returns and all sales, only 3.rd sales included.
  SUM(NumberOfReceiptsWith3rdPartySales) AS NumberOf3rdPartyCustomers,
  --ISNULL(SUM(Pos3rdPartySalesAmount)/ NULLIF (SUM(NumberOfReceiptsWith3rdPartySales), 0),0) AS Avg3rdPartySalesPerCustomer,  --{RS-27230} 
  ISNULL(SUM(Pos3rdPartySalesAmount+Pos3rdPartyReturnAmount)/ NULLIF (SUM(NumberOfReceiptsWith3rdPartySales), 0),0) AS Avg3rdPartySalesPerCustomer, --{RS-27230} all returns and all sales, only 3.rd sales included.
  SUM(QuantityOfScannedArticles - QuantityOf3rdPartyScannedArticles) AS QuantityOfScannedArticlesWithout3rdParty,                  
  SUM(QuantityOfScannableArticles - QuantityOf3rdPartyScannableArticles)  AS QuantityOfScannableArticlesWithout3rdParty,
  SUM(QuantityOfArticlesWithout3rdParty) AS QuantityOfArticlesWithout3rdParty                       
FROM    (SELECT  
           su.UserNameID AS CashierId
         , su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName
         , SUM(f.SalesAmount) AS SalesAmount
         , SUM(f.ReturnAmount) AS ReturnAmount
         , SUM(f.NumberOfCustomers) AS NumberOfCustomers
		 , SUM(CASE WHEN ISNULL(da.Is3rdPartyArticle, 0) = 0 THEN (f.QuantityOfArticlesSold + f.QuantityOfArticlesInReturn) ELSE 0 END) AS QuantityOfArticlesWithout3rdParty	-- {RS-37977}
	     , 0 AS Pos3rdPartySalesAmount
		 , 0 AS Pos3rdPartyReturnAmount  --{RS-27230} added
         , 0 AS NumberOfReceiptsWith3rdPartySales
         , 0 AS QuantityOfScannedArticles
		 , 0 AS QuantityOfScannableArticles
		 , 0 AS QuantityOf3rdPartyScannedArticles
		 , 0 AS QuantityOf3rdPartyScannableArticles
         , 0 AS NumberOfReceiptsWithOnly3rdPartySales
         FROM   RBIM.Agg_SalesAndReturnPerDay AS f 
            INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
            INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = f.StoreIdx AND ds.StoreId = @StoreId AND IsCurrentStore = 1 
            INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.SystemUserIdx
			INNER JOIN RBIM.Dim_Article AS da ON da.ArticleIdx = f.ArticleIdx
        WHERE       (@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo OR
                                                    @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate OR
                                                    @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                    @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                    @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                    @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                    @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1) 
         GROUP BY su.UserNameID, su.FirstName, su.LastName
                          
         UNION ALL
         SELECT   
            su.UserNameID AS CashierId
          , su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName
          , 0 AS SalesAmount
          , 0 AS ReturnAmount
          , 0 AS NumberOfCustomers
		  , 0 AS QuantityOfArticlesWithout3rdParty
          , SUM(f.Pos3rdPartySalesAmount) AS Pos3rdPartySalesAmount
	      , SUM(f.Pos3rdPartyReturnAmount) AS Pos3rdPartyReturnAmount --{RS-27230} added
          , SUM(f.NumberOfReceiptsWith3rdPartySales) AS NumberOfReceiptsWith3rdPartySales
          , SUM(f.NumberOfScannedArticles) AS QuantityOfScannedArticles
		  , SUM(f.NumberOfScannableArticles) AS QuantityOfScannableArticles
		  , SUM(f.NumberOf3rdPartyScannedArticles) AS QuantityOf3rdPartyScannedArticles
		  , SUM(f.NumberOf3rdPartyScannableArticles) AS QuantityOf3rdPartyScannableArticles
          , SUM(f.NumberOfReceiptsWithOnly3rdPartySales) AS NumberOfReceiptsWithOnly3rdPartySales
          FROM   RBIM.Agg_CashierSalesAndReturnPerHour AS f 
            INNER JOIN  RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
            INNER JOIN  RBIM.Dim_Store AS ds ON ds.StoreIdx = f.StoreIdx AND ds.StoreId = @StoreId 
            INNER JOIN  RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
          WHERE     
                   (@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo OR
                                                   @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate OR
                                                   @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                   @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                   @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                   @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1 OR
                                                   @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1) AND (ds.IsCurrentStore = 1)
        GROUP BY su.UserNameID, su.FirstName, su.LastName) AS sub
GROUP BY CashierId, CasierName
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

--SELECT B.*, CAST(t.BagPrCustomer AS DECIMAL (20,2)) AS BagPrCustomer  FROM totals t
--LEFT JOIN Orginal B ON B.CasierName=T.CasierName

SELECT O.*, CAST(T.BagPrCustomer AS DECIMAL (20,2)) AS BagPrCustomer FROM Orginal O
LEFT JOIN totals T ON T.CasierName = O.CasierName

END




END

GO

