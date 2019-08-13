USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1512_ItemGroupSaleSelections_Date]    Script Date: 15.01.2019 14:35:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER PROCEDURE [dbo].[usp_CBI_1512_ItemGroupSaleSelections_Date] 
(@DateTo AS DATE)

AS 
BEGIN
SET NOCOUNT ON;

--TRN ItemGroupSale Selctions on EAN

DECLARE @sql NVARCHAR(MAX)

DECLARE @DateFrom1 DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @DateFrom2 DATE = DATEADD(DAY, -2, @DateTo)
DECLARE @DateFrom3 DATE = DATEADD(DAY, -3, @DateTo)
DECLARE @DateFrom4 DATE = DATEADD(DAY, -4, @DateTo)
DECLARE @DateFrom5 DATE = DATEADD(DAY, -5, @DateTo)
DECLARE @DateFrom6 DATE = DATEADD(DAY, -6, @DateTo)
DECLARE @DateFrom7 DATE = DATEADD(DAY, -7, @DateTo)

IF OBJECT_ID('tempdb..#B12tmpItems') is NOT NULL
BEGIN 
	set @Sql = 'drop table #B12tmpItems'
	EXEC (@Sql)
END
create table #B12tmpItems (EAN float)

if getdate() >= '02.09.2018'	-- Setter alltid dato til den 2. i mnd da raporten kjører tall for igår - og da var det første							
INSERT into #B12tmpItems (EAN) values 

(5010494195125),
(4009367223981),
(4009367225107),
(5202795130046),
(3024480000944),
(3024480002429),
(3024482295102),
(3024482295126),
(22010346),
(22281937),
(80432400432),
(87000004085),
(87000653795),
(87000654044),
(9900000066031),
(2000007326453),
(7048350168516),
(7048352000838),
(2050005135144),
(8002062006879),
(22234650),
(3029440000408),
(3029440000460),
(3029440000675),
(3029440001597),
(8410337322034),
(2050004200423),
(9300727013460),
(89540493435),
(5703042460188),
(7610594251950),
(7610594251981),
(7610594456225),
(7610594475509),
(2050003376112),
(3035131115832),
(2050011823264),
(3292060108865),
(3292060109152),
(3292060117010),
(2050012348988),
(5010867400092),
(5608309002951),
(2050013842393),
(9501007803300)


ELSE													

INSERT INTO #B12tmpItems (EAN) VALUES 

(2050006445280),
(3248847699934),
(500299226759),
(2050003534062),
(5000299226759),
(5000299609569),
(22198440),
(3035540000682),
(3035542001908),
(3035542002394),
(8501110080453),
(8501110088565),
(5010103519168),
(5010677716000),
(5010677718004),
(7640175740030),
(4003753000026),
(4003753001054),
(4003753001481),
(4003753001948),
(4003753002440),
(4003753003010),
(4003753003720),
(8004645305102),
(2000003028436),
(9007500056507),
(9007500056583),
(9007500056590),
(9007500156146),
(9007500156511),
(9007500156528),
(9007500156535),
(9007500156542),
(9007500156559),
(9007500156566),
(9007500156573),
(22847461),
(3035134126101),
(4004763686255),
(3337690054004),
(3337690062405),
(3337690072244),
(3337690085114),
(3337690118997),
(3337690136625),
(3337690155596),
(3337690158788),
(3337690159945),
(3337690180345),
(84692506545),
(3016570002020),
(3016570002716),
(3016570002747),
(3016570006844),
(2050007187851),
(3183520703754),
(4603400000173),
(4603400000227)

--SELECT * FROM  #B12tmpItems AS BI --for test

IF OBJECT_ID('tempdb..#ArticleHierarchies') IS NOT NULL 
	DROP TABLE #ArticleHierarchies
IF OBJECT_ID('tempdb..#Sales') IS NOT NULL 
	DROP TABLE #Sales

--DECLARE @ToDate DATE = GETDATE()-1
--DECLARE @FromDate DATE = DATEADD(DAY, -6, @ToDate)

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
JOIN #B12tmpItems AS EAN ON EAN.EAN=dg.Gtin
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

