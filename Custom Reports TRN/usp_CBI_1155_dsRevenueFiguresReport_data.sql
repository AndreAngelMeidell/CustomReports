USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1155_dsRevenueFiguresReport_data]    Script Date: 19.02.2020 10:52:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1155_dsRevenueFiguresReport_data]
(   
    @StoreId AS VARCHAR(100),
	@PeriodType AS VARCHAR(1), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@YearToDate AS INTEGER, 
	@RelativePeriodType AS VARCHAR(5),
	@RelativePeriodStart AS INTEGER, 
	@RelativePeriodDuration AS INTEGER ,	
    @GtinFrom AS VARCHAR(50),
	@GtinTo AS VARCHAR(50),	
	@ArticleIdFrom AS VARCHAR(50),
	@ArticleIdTo AS VARCHAR(50),
	@BrandIdFrom AS VARCHAR(50),
	@BrandIdTo	AS VARCHAR(50),
	@ArticleHierarchyIdFrom AS VARCHAR(50),
	@ArticleHierarchyIdTo AS VARCHAR(50),
	@GroupBy AS VARCHAR(50) = 'Month', --Month, Week, WeekDay, Supplier, ArticleHierarchy, Article, Brand
	@ArticleSelectionId AS VARCHAR(1000) 
	
) 
AS  
BEGIN
  
SET @GtinFrom = CASE WHEN @GtinFrom = '' THEN NULL ELSE @GtinFrom END;
SET @GtinTo = CASE WHEN @GtinTo = '' THEN NULL ELSE @GtinTo END;
SET @ArticleIdFrom = CASE WHEN @ArticleIdFrom = '' THEN NULL ELSE @ArticleIdFrom END;
SET @ArticleIdTo = CASE WHEN @ArticleIdTo = '' THEN NULL ELSE @ArticleIdTo END;


--- Converting date to dateIdx'es
DECLARE @DateIdxBegin VARCHAR(8) = cast(convert(char(8), @DateFrom, 112) as VARCHAR(8))
DECLARE @DateIdxEnd VARCHAR(8) = cast(convert(char(8), @DateTo, 112) as VARCHAR(8))

DECLARE @QueryStringPart1 NVARCHAR(MAX)

------------------------------------------------------------------------------------------------------

IF (@DateFrom IS NULL) 
BEGIN
	SELECT TOP(0) 1 
END
ELSE 
BEGIN 

SET @QueryStringPart1 = '
;WITH SelectedSales AS (
SELECT 
 dd.[YearMonthNumber]
,dd.[YearWeekNumber]
,dsup.[SupplierName]
,da.[Lev1ArticleHierarchyName]
,da.[Lev1ArticleHierarchyId]
,da.[BrandId]
,da.[BrandName]
,da.[ArticleName]
,da.[ArticleId]
,g.Gtin
,dd.FullDate
,(f.[QuantityOfArticlesSold] - f.QuantityOfArticlesInReturn) AS Quantity -- Antall
,(f.[SalesAmount] + f.[ReturnAmount]) AS RevenueAmountInclVat -- Omsetning
,(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS Revenue --Netto Omsetning
,(f.NetPurchasePriceDerived + f.NetPurchasePrice) AS [PurchaseAmount]-- Innverdi
from BI_Mart.RBIM.Agg_SalesAndReturnPerDay f (NOLOCK) 
join rbim.Dim_Date dd (NOLOCK) ON dd.DateIdx = f.ReceiptDateIdx 
join rbim.Dim_Article da (NOLOCK)on da.ArticleIdx = f.ArticleIdx 
join rbim.Dim_Store ds (NOLOCK) on ds.storeidx = f.storeidx
JOIN rbim.Dim_Supplier dsup (NOLOCK) ON dsup.SupplierIdx = f.SupplierIdx
LEFT JOIN RBIM.Dim_Gtin g (NOLOCK) ON g.GtinIdx = f.gtinIdx
Where ds.StoreId =  '+ @StoreId
 + '  and f.ReceiptDateIdx BETWEEN ' +@DateIdxBegin+' AND '+@DateIdxEnd+'
and ds.isCurrentStore = 1  ' 	

if @GtinFrom>0
SET @QueryStringPart1 = @QueryStringPart1+ '
AND g.Gtin	>= CAST(CASE WHEN '+@GtinFrom+' IS NULL THEN g.Gtin ELSE '+@GtinFrom+' END AS BIGINT) '				

if @GtinTo>0
SET @QueryStringPart1 = @QueryStringPart1+ '
and g.Gtin  <= CAST(CASE WHEN '+@GtinTo+' IS NULL THEN g.Gtin ELSE '+@GtinTo+' END AS BIGINT) '

if @ArticleIdFrom>0
SET @QueryStringPart1 = @QueryStringPart1+ '
and da.ArticleId >= CAST(CASE WHEN '+@ArticleIdFrom+' IS NULL THEN da.ArticleId ELSE '+@ArticleIdFrom+' END AS INT)	'	
		
if @ArticleIdTo>0
SET @QueryStringPart1 = @QueryStringPart1+ '
and da.ArticleId <= CAST(CASE WHEN '+@ArticleIdTo+' IS NULL THEN da.ArticleId ELSE '+@ArticleIdTo+' END AS INT)	'	

if @BrandIdFrom>0
SET @QueryStringPart1 = @QueryStringPart1+ '
and da.BrandId >= CAST(CASE WHEN '+@BrandIdFrom+' IS NULL THEN da.BrandId ELSE '+@BrandIdFrom+' END AS INT)	'		
	
if @BrandIdTo>0
SET @QueryStringPart1 = @QueryStringPart1+ '
and da.BrandId <= CAST(CASE WHEN '+@BrandIdTo+' IS NULL THEN da.BrandId ELSE '+@BrandIdTo+' END AS INT)	'
			
if @ArticleHierarchyIdFrom>0
SET @QueryStringPart1 = @QueryStringPart1+ '
and da.Lev2ArticleHierarchyId >= CAST(CASE WHEN '+@ArticleHierarchyIdFrom+' IS NULL THEN da.Lev2ArticleHierarchyId ELSE '+@ArticleHierarchyIdFrom+' END AS INT)	'	
		
if @ArticleHierarchyIdTo>0
SET @QueryStringPart1 = @QueryStringPart1+ '
and da.Lev2ArticleHierarchyId <= CAST(CASE WHEN '+@ArticleHierarchyIdTo+' IS NULL THEN da.Lev2ArticleHierarchyId ELSE '+@ArticleHierarchyIdTo+' END AS INT)	'

if @ArticleSelectionId>0
SET @QueryStringPart1 = @QueryStringPart1+ '
AND da.ArticleIdx IN ('+@ArticleSelectionId+') '

SET @QueryStringPart1 = @QueryStringPart1+ '			
)'

IF @ArticleSelectionId>0
BEGIN
SET @QueryStringPart1 = @QueryStringPart1+ '
,ArticlesInSelection AS 
(
SELECT cas.ArticleIdx
FROM RBIM.Dim_ArticleSelection das
LEFT JOIN RBIM.Cov_ArticleSelection cas ON cas.ArticleSelectionIdx = das.ArticleSelectionIdx
WHERE das.ArticleSelectionId = '+@ArticleSelectionId+'
)
'
END

IF @GroupBy = 'ArticleHierarchy'
	BEGIN
	SET @QueryStringPart1 = @QueryStringPart1+ '
	SELECT
	Lev1ArticleHierarchyName AS GroupedBy
	,NULL AS GroupedBy2
	,''''  AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	GROUP BY Lev1ArticleHierarchyName
	ORDER BY 1
	'		
	END

----Month, Week, WeekDay, Supplier, ArticleHierachy, Article, Brand
IF @GroupBy = 'Month'
BEGIN
SET @QueryStringPart1 = @QueryStringPart1+ '
SELECT 
	CONVERT(VARCHAR(10),yearMonthNumber) AS GroupedBy
	,NULL AS GroupedBy2
	,''''  AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	GROUP BY CONVERT(VARCHAR(10),yearMonthNumber)
	ORDER BY 1
	'
END


IF @GroupBy = 'Week'
BEGIN
SET @QueryStringPart1 = @QueryStringPart1+ '
SELECT 
	 CONVERT(VARCHAR(10),yearWeekNumber) AS GroupedBy
	,NULL AS GroupedBy2
	,''''  AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	GROUP BY CONVERT(VARCHAR(10),yearWeekNumber)
	ORDER BY 1
'
END 

IF @GroupBy = 'WeekDay'
BEGIN
SET @QueryStringPart1 = @QueryStringPart1+ '
SELECT
	 '''' AS GroupedBy
	,FullDate AS GroupedBy2
	,''''  AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	GROUP BY FullDate
	ORDER BY FullDate
'
END


IF @GroupBy = 'Supplier'
BEGIN
SET @QueryStringPart1 = @QueryStringPart1+ '
SELECT 
	 SupplierName AS GroupedBy
	,NULL AS GroupedBy2
	,''''  AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	GROUP BY  SupplierName
	ORDER BY 1
'
END



IF @GroupBy = 'Article'
BEGIN
SET @QueryStringPart1 = @QueryStringPart1+ '
SELECT
	ArticleName AS GroupedBy
	,NULL AS GroupedBy2
	,CONVERT(VARCHAR(50),Gtin) AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	GROUP BY ArticleName, Gtin
	ORDER BY 1,3
'
END


IF @GroupBy = 'Brand'
BEGIN
SET @QueryStringPart1 = @QueryStringPart1+ '
SELECT 
	 BrandName AS GroupedBy
	,NULL AS GroupedBy2
	,''''  AS Gtin
	,SUM(Quantity) AS Quantity 
	,SUM(RevenueAmountInclVat) AS RevenueAmountInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(PurchaseAmount) AS PurchaseAmount
	FROM SelectedSales
	GROUP BY BrandName
'
END

--PRINT @QueryStringPart1

EXEC sp_executesql @QueryStringPart1

END 

END


GO

