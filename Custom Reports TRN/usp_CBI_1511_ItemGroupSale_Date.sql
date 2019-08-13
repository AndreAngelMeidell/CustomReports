USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1511_ItemGroupSale_Date]    Script Date: 15.01.2019 14:35:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER PROCEDURE [dbo].[usp_CBI_1511_ItemGroupSale_Date] 
(@DateTo AS DATE)

AS 
BEGIN
SET NOCOUNT ON;


--TRN ItemGroupSale

DECLARE @sql NVARCHAR(MAX)

DECLARE @DateFrom1 DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @DateFrom2 DATE = DATEADD(DAY, -2, @DateTo)
DECLARE @DateFrom3 DATE = DATEADD(DAY, -3, @DateTo)
DECLARE @DateFrom4 DATE = DATEADD(DAY, -4, @DateTo)
DECLARE @DateFrom5 DATE = DATEADD(DAY, -5, @DateTo)
DECLARE @DateFrom6 DATE = DATEADD(DAY, -6, @DateTo)
DECLARE @DateFrom7 DATE = DATEADD(DAY, -7, @DateTo)


IF OBJECT_ID('tempdb..#ArticleHierarchies') IS NOT NULL 
	DROP TABLE #ArticleHierarchies
IF OBJECT_ID('tempdb..#Sales') IS NOT NULL 
	DROP TABLE #Sales

--DECLARE @ToDate DATE = @DateTo
--DECLARE @FromDate DATE = DATEADD(DAY, -6, @DateTo)

SELECT DISTINCT da.Lev1ArticleHierarchyId, SUBSTRING(da.Lev1ArticleHierarchyId,1,1) + '00' ArticleHierarchyDisplayId, da.Lev1ArticleHierarchyName ArticleHierarchyName
INTO #ArticleHierarchies
FROM RBIM.Dim_Article AS da
WHERE (da.Lev1ArticleHierarchyId NOT LIKE '-%' AND LEN(da.Lev1ArticleHierarchyId) = 3)
--AND da.Lev1ArticleHierarchyId IN (200,300)
ORDER BY da.Lev1ArticleHierarchyId


UPDATE ah1
SET ah1.ArticleHierarchyName = ah2.ArticleHierarchyName
FROM #ArticleHierarchies AS ah1
JOIN #ArticleHierarchies AS ah2 ON ah2.Lev1ArticleHierarchyId = ah1.ArticleHierarchyDisplayId
WHERE ah1.Lev1ArticleHierarchyId != ah1.ArticleHierarchyDisplayId


SELECT ds.StoreId AS Shop,
		ah.ArticleHierarchyDisplayId AS [Group],
		ah.ArticleHierarchyName AS GroupName,
		SUM(CASE WHEN d.FullDate = @DateFrom7 THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) AS QuantityDay7,
		SUM(CASE WHEN d.FullDate = @DateFrom6 THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) AS QuantityDay6,
		SUM(CASE WHEN d.FullDate = @DateFrom5 THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) AS QuantityDay5,
		SUM(CASE WHEN d.FullDate = @DateFrom4 THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) AS QuantityDay4,
		SUM(CASE WHEN d.FullDate = @DateFrom3 THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) AS QuantityDay3,
		SUM(CASE WHEN d.FullDate = @DateFrom2 THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) AS QuantityDay2,
		SUM(CASE WHEN d.FullDate = @DateFrom1 THEN f.NumberOfArticlesSold - f.NumberOfArticlesInReturn ELSE 0 END) AS QuantityDay1,
		SUM(CASE WHEN d.FullDate = @DateFrom7 THEN f.SalesAmountExclVat ELSE 0 END) AS AmountDay7,
		SUM(CASE WHEN d.FullDate = @DateFrom6 THEN f.SalesAmountExclVat ELSE 0 END) AS AmountDay6,
		SUM(CASE WHEN d.FullDate = @DateFrom5 THEN f.SalesAmountExclVat ELSE 0 END) AS AmountDay5,
		SUM(CASE WHEN d.FullDate = @DateFrom4 THEN f.SalesAmountExclVat ELSE 0 END) AS AmountDay4,
		SUM(CASE WHEN d.FullDate = @DateFrom3 THEN f.SalesAmountExclVat ELSE 0 END) AS AmountDay3,
		SUM(CASE WHEN d.FullDate = @DateFrom2 THEN f.SalesAmountExclVat ELSE 0 END) AS AmountDay2,
		SUM(CASE WHEN d.FullDate = @DateFrom1 THEN f.SalesAmountExclVat ELSE 0 END) AS AmountDay1
INTO #Sales
FROM    
	RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
INNER JOIN RBIM.Dim_Article da ( NOLOCK ) ON da.ArticleIdx = f.ArticleIdx
INNER JOIN #ArticleHierarchies AS ah ON ah.Lev1ArticleHierarchyId = da.Lev1ArticleHierarchyId
INNER JOIN RBIM.Dim_Date d (NOLOCK) ON d.DateIdx = f.ReceiptDateIdx
INNER JOIN RBIM.Dim_Store ds (NOLOCK) ON ds.StoreIdx = f.StoreIdx
INNER JOIN RBIM.Dim_Gtin AS DG (NOLOCK) ON DG.GtinIdx = f.GtinIdx
--JOIN #B12tmpItems AS EAN ON EAN.EAN=dg.Gtin 
WHERE d.FullDate BETWEEN @DateFrom7 AND @DateFrom1
AND f.SalesAmount != 0
GROUP BY ds.StoreId, ah.ArticleHierarchyDisplayId, ah.ArticleHierarchyName
ORDER BY ds.StoreId, ah.ArticleHierarchyDisplayId


SELECT s.Shop, s.[Group], s.GroupName, 'Quantity' AS Unit, 
	CAST(s.QuantityDay7 AS INT) AS Day7,
	CAST(s.QuantityDay6 AS INT) AS Day6,
	CAST(s.QuantityDay5 AS INT) AS Day5,
	CAST(s.QuantityDay4 AS INT) AS Day4,
	CAST(s.QuantityDay3 AS INT) AS Day3,
	CAST(s.QuantityDay2 AS INT) AS Day2,
	CAST(s.QuantityDay1 AS INT) AS Day1
FROM #Sales AS s
UNION ALL
SELECT s.Shop, s.[Group], s.GroupName, 'Sum' AS Unit, 
	CAST(s.AmountDay7 AS INT),
	CAST(s.AmountDay6 AS INT),
	CAST(s.AmountDay5 AS INT),
	CAST(s.AmountDay4 AS INT),
	CAST(s.AmountDay3 AS INT),
	CAST(s.AmountDay2 AS INT),
	CAST(s.AmountDay1 AS INT)
FROM #Sales AS s
ORDER BY 1, 2, 4

END 




GO

