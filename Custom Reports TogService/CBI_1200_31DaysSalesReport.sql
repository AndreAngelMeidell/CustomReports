USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1200_31DaysSalesReport]    Script Date: 25.09.2018 08:23:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[usp_CBI_1200_31DaysSalesReport]
(
	@StoreOrGroupNo					VARCHAR(MAX)
	,@DateFrom						DATETIME 
	,@DataType						INT 

)
AS
BEGIN

--Manuel test
--DECLARE @DataType AS VARCHAR(100) = 'SalesRevenueInclVat'
--DECLARE @DateFrom as		 DATETIME = GETDATE()-32
--DECLARE @DateFrom+31 as			 DATETIME = GETDATE() -1
--DECLARE @StoreOrGroupNo		 VARCHAR(500) = ('10062,10063,10028,10055,10035,10021')

--Finne dag i året for start
DECLARE @day INT = ( SELECT MIN (dd.DayNumberOfYear) AS StartDay FROM RBIM.Dim_Date AS DD
					 WHERE 1=1
					 AND dd.FullDate between @DateFrom and @DateFrom+31
					 AND dd.Dateidx not in (-1,-2,-3,-4) )

--Values:
--0--"NumberOfCustomers",						-- f.NumberOfCustomers
--1--"QuantityOfArticlesSold",					--,(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS QuantityOfArticlesSold
--2--"AvgQuantityOfArticlesSoldPerCustomer",	--,(f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/ISNULL(f.NumberOfCustomers,1) AS AvgArticlesSoldPrCustomer
--3--"AvgSalesRevenueExclVatPerCustomer",		--,(f.SalesAmountExclVat/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))  AS AvgSalesRevenueExclVatPerCustomer
--4--"AvgSalesRevenueInclVatPerCustomer",		--,(f.SalesRevenueInclVat/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1)) AS AvgSalesRevenueInclVatPerCustomer
--5--"AvgGrossProfitPerCustomer",				--,(f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1)) AS AvgGrossProfitPerCustomer
--6--"SalesRevenueInclVat",						--,(f.SalesRevenueInclVat-f.ReturnAmount) AS SalesRevenueInclVat
--7--"SalesVatAmount",							--,(f.SalesVatAmount-f.ReturnVatAmount) AS SalesVatAmount
--8--"SalesAmountExclVat",						--,(f.SalesAmountExclVat-f.ReturnAmountExclVat) AS SalesAmountExclVat
--9--"NetPurchasePrice",						--,f.NetPurchasePrice
--10--"GrossProfit",							--,f.GrossProfit

--0--"NumberOfCustomers",						-- f.NumberOfCustomers
IF( @DataType = 0  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN f.NumberOfCustomers	ELSE 0.00 END) AS 'Day31'
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			--LEFT JOIN rbim.Dim_Gtin  B  ON f.GtinIdx = B.GtinIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 

SELECT * FROM SelectedSales ss ORDER BY ss.StoreId

END
--1--"QuantityOfArticlesSold",					--,(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS QuantityOfArticlesSold
IF( @DataType = 1 )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)	ELSE 0.00 END) AS 'Day31'
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			--LEFT JOIN rbim.Dim_Gtin  B  ON f.GtinIdx = B.GtinIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss ORDER BY ss.StoreId
END
--2--"AvgQuantityOfArticlesSoldPerCustomer",	--,(f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/ISNULL(f.NumberOfCustomers,1) AS AvgArticlesSoldPrCustomer	
	IF( @DataType = 2  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
,Totals as (
SELECT DISTINCT
'9999999' AS StoreId
,'Avg' AS StoreName
,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle  ELSE 0.00 END) AS 'Day1'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day2'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day3'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day4'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day5'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day6'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day7'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day8'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day9'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day10'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day11'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day12'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day13'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day14'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day15'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day16'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day17'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day18'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day19'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day20'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day21'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day22'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day23'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day24'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day25'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day26'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day27'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day28'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day29'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day30'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day31'
FROM (
			SELECT f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfArticlesSold)) AS NumberOfArticlesSold
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfArticlesInReturn))  AS NumberOfArticlesInReturn
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY f.ReceiptDateIdx) f
JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) )

, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)/f.NumberOfReceiptsWithSalePerSelectedArticle	ELSE 0.00 END) AS 'Day31'
			FROM (
			SELECT f.StoreIdx,ds.StoreId,ds.StoreName,f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfArticlesSold)) AS NumberOfArticlesSold
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfArticlesInReturn))  AS NumberOfArticlesInReturn
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY f.StoreIdx, ds.StoreId, ds.StoreName, f.ReceiptDateIdx) f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss 
UNION
SELECT  * FROM Totals tt  ORDER BY 1
END
--3--"AvgSalesRevenueExclVatPerCustomer",		--,(f.SalesAmountExclVat/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1)  AS AvgSalesRevenueExclVatPerCustomer	
IF( @DataType = 3  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
,Totals as (
SELECT DISTINCT
'9999999' AS StoreId
,'Avg' AS StoreName
,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)  ELSE 0.00 END) AS 'Day1'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day2'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day3'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day4'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day5'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day6'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day7'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day8'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day9'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day10'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day11'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day12'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day13'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day14'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day15'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day16'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day17'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day18'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day19'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day20'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day21'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day22'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day23'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day24'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day25'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day26'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day27'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day28'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day29'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day30'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day31'
FROM (
			SELECT f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.SalesAmountExclVat)) AS SalesAmountExclVat
			,SUM(CONVERT(DECIMAL(19,5),f.ReturnAmountExclVat)) AS ReturnAmountExclVat
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY f.ReceiptDateIdx) f
JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) )

, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)  ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN ((f.SalesAmountExclVat+f.ReturnAmountExclVat)/f.NumberOfReceiptsWithSalePerSelectedArticle)	ELSE 0.00 END) AS 'Day31'
			FROM (
			SELECT f.StoreIdx,ds.StoreId,ds.StoreName,f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.SalesAmountExclVat)) AS SalesAmountExclVat
			,SUM(CONVERT(DECIMAL(19,5),f.ReturnAmountExclVat)) AS ReturnAmountExclVat
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			--AND da.ArticleIdx>-1
			GROUP BY f.StoreIdx, ds.StoreId, ds.StoreName, f.ReceiptDateIdx) f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss 
UNION
SELECT  * FROM Totals tt  ORDER BY 1

END	
--4--"AvgSalesRevenueInclVatPerCustomer",		--,(f.SalesRevenueInclVat/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1) AS AvgSalesRevenueInclVatPerCustomer
IF( @DataType = 4  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
,Totals as (
SELECT DISTINCT
'9999999' AS StoreId
,'Avg' AS StoreName
,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day1'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day2'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day3'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day4'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day5'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day6'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day7'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day8'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day9'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day10'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day11'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day12'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day13'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day14'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day15'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day16'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day17'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day18'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day19'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day20'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day21'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day22'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day23'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day24'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day25'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day26'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day27'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day28'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day29'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day30'
,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day31'
FROM (
			SELECT f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.SalesAmount)) AS SalesAmount
			,SUM(CONVERT(DECIMAL(19,5),f.ReturnAmount)) AS ReturnAmount
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY f.ReceiptDateIdx) f
JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) )

, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN ((f.SalesAmount+f.ReturnAmount)/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day31'
			FROM (
			SELECT f.StoreIdx,ds.StoreId,ds.StoreName,f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.SalesAmount)) AS SalesAmount
			,SUM(CONVERT(DECIMAL(19,5),f.ReturnAmount)) AS ReturnAmount
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			--AND da.ArticleIdx>-1
			GROUP BY f.StoreIdx, ds.StoreId, ds.StoreName, f.ReceiptDateIdx) f  
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss 
UNION
SELECT  * FROM Totals tt  ORDER BY 1
END
--5--"AvgGrossProfitPerCustomer",				--,(f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1)) AS AvgGrossProfitPerCustomer
IF( @DataType = 5  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
,Totals as (
SELECT DISTINCT
'9999999' AS StoreId
,'Avg' AS StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day31'
FROM (
			SELECT f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.GrossProfit)) AS GrossProfit
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY f.ReceiptDateIdx) f
JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
WHERE dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 AND dd.Dateidx NOT IN (-1,-2,-3,-4) )

, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.GrossProfit/ISNULL(NULLIF(f.NumberOfReceiptsWithSalePerSelectedArticle,0),1))	ELSE 0.00 END) AS 'Day31'
			FROM (
			SELECT f.StoreIdx,ds.StoreId,ds.StoreName,f.ReceiptDateIdx
			,SUM(CONVERT(DECIMAL(19,5),f.GrossProfit)) AS GrossProfit
			,SUM(CONVERT(DECIMAL(19,5),f.NumberOfCustomers)) AS NumberOfReceiptsWithSalePerSelectedArticle
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			--AND da.ArticleIdx>-1
			GROUP BY f.StoreIdx, ds.StoreId, ds.StoreName, f.ReceiptDateIdx) f  
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss 
UNION
SELECT  * FROM Totals tt  ORDER BY 1
END
--6--"SalesRevenueInclVat",						--,(f.SalesRevenueInclVat-f.ReturnAmount) AS SalesRevenueInclVat
IF( @DataType = 6 )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.SalesAmount+f.ReturnAmount)	ELSE 0.00 END) AS 'Day31'
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			--LEFT JOIN rbim.Dim_Gtin  B  ON f.GtinIdx = B.GtinIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss ORDER BY ss.StoreId
END
--7--"SalesVatAmount",							--,(f.SalesVatAmount-f.ReturnVatAmount) AS SalesVatAmount
IF( @DataType = 7  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.SalesVatAmount+f.ReturnVatAmount) ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.SalesVatAmount+f.ReturnVatAmount)	ELSE 0.00 END) AS 'Day31'
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			--LEFT JOIN rbim.Dim_Gtin  B  ON f.GtinIdx = B.GtinIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss ORDER BY ss.StoreId
END
--8--"SalesAmountExclVat",						--,(f.SalesAmountExclVat-f.ReturnAmountExclVat) AS SalesAmountExclVat
IF( @DataType = 8  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat) ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN (f.SalesAmountExclVat+f.ReturnAmountExclVat)	ELSE 0.00 END) AS 'Day31'
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			--LEFT JOIN rbim.Dim_Gtin  B  ON f.GtinIdx = B.GtinIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss ORDER BY ss.StoreId
END
--9--"NetPurchasePrice",						--,f.NetPurchasePrice
IF( @DataType = 9 )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN NetPurchasePrice	ELSE 0.00 END) AS 'Day31'
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			--LEFT JOIN rbim.Dim_Gtin  B ON f.GtinIdx = B.GtinIdx 
			JOIN Stores				 ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss ORDER BY ss.StoreId
END
--10--"GrossProfit",							--,f.GrossProfit
IF( @DataType = 10  )		-- Type of data
BEGIN
;WITH Stores AS
	(
SELECT
		DISTINCT ds.StoreId, ds.StoreName, ds.StoreIdx
	FROM
		RBIM.Dim_Store ds
	LEFT JOIN ( SELECT ParameterValue FROM dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1	)
, DateHeader AS ( SELECT DISTINCT DD.FullDate FROM RBIM.Dim_Date AS DD -- new
					 WHERE 1=1
					 AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31 --new
					 AND dd.Dateidx NOT IN (-1,-2,-3,-4)
					  )
, SelectedSales AS (
			SELECT DISTINCT
				ds.StoreId
				,ds.StoreName
				,SUM(CASE WHEN dd.DayNumberOfYear = @Day      THEN f.GrossProfit  ELSE 0.00 END) AS 'Day1'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+1    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day2'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+2    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day3'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+3    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day4'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+4    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day5'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+5    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day6'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+6    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day7'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+7    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day8'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+8    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day9'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+9    THEN f.GrossProfit	ELSE 0.00 END) AS 'Day10'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+10   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day11'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+11   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day12'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+12   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day13'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+13   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day14'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+14   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day15'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+15   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day16'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+16   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day17'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+17   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day18'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+18   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day19'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+19   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day20'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+20   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day21'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+21   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day22'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+22   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day23'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+23   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day24'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+24   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day25'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+25   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day26'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+26   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day27'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+27   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day28'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+28   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day29'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+29   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day30'
				,SUM(CASE WHEN dd.DayNumberOfYear = @day+30   THEN f.GrossProfit	ELSE 0.00 END) AS 'Day31'
			FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			JOIN rbim.Dim_Date       dd ON dd.DateIdx    = f.ReceiptDateIdx 
			--JOIN rbim.Dim_Article    da ON da.ArticleIdx = f.ArticleIdx 
			--LEFT JOIN rbim.Dim_Gtin B ON f.GtinIdx = B.GtinIdx 
			JOIN Stores ds ON ds.StoreIdx = f.StoreIdx
			WHERE 1=1
			AND dd.FullDate BETWEEN @DateFrom AND @DateFrom+31
			AND dd.Dateidx NOT IN (-1,-2,-3,-4) 
			GROUP BY ds.StoreId, ds.StoreName
) 
SELECT * FROM SelectedSales ss ORDER BY ss.StoreId
END



END

GO

