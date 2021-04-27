USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1200_EOD_Report]    Script Date: 27.04.2021 08:29:51 ******/
DROP PROCEDURE [dbo].[usp_CBI_1200_EOD_Report]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1200_EOD_Report]    Script Date: 27.04.2021 08:29:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1200_EOD_Report]
(
	---------------------------------------------
	@StoreId	AS VARCHAR(100),
	@DateFrom AS DATETIME ,
	@DateTo AS DATETIME

)
AS  
BEGIN 


--St1 
DECLARE @DateFromIdx    int  = cast(convert(varchar(8),@DateFrom, 112) as integer)   -- Added for performance optimization 
DECLARE @DateToIdx		INT  = cast(convert(varchar(8),@DateTo, 112) as integer) -- Added for performance optimization 

;WITH DriveOff AS 
	(SELECT DS.StoreId,aa.Lev2ArticleHierarchyId,SUM(DO.SalesAmount) AS SalesPrice FROM RBIM.Fact_ReceiptRowSalesAndReturn DO 
JOIN RBIM.Dim_Article AA ON AA.ArticleIdx = DO.ArticleIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = DO.StoreIdx
JOIN RBIM.Dim_Customer AS DC ON DC.CustomerIdx = DO.CustomerIdx
WHERE 1=1
AND DO.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND ds.StoreId = @StoreId --AND ds.isCurrentStore = 1 
--AND do.CustomerIdx=3 --Obetald
AND DC.LastName='drive off' --new 25102018
AND AA.ArticleIdx<>-1
GROUP BY DS.StoreId,AA.Lev2ArticleHierarchyId)
, FuelDriveOff AS (
	SELECT DS.StoreId
	,aa.Lev2ArticleHierarchyId
	,aa.articleName
	,SUM(DO.SalesAmount) AS SalesPrice 
	FROM RBIM.Fact_ReceiptRowSalesAndReturn DO 
JOIN RBIM.Dim_Article AA ON AA.ArticleIdx = DO.ArticleIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = DO.StoreIdx
JOIN RBIM.Dim_Customer AS DC ON DC.CustomerIdx = DO.CustomerIdx
WHERE 1=1
AND DO.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND AA.Lev2ArticleHierarchyId=990
AND ds.StoreId = @StoreId --AND ds.isCurrentStore = 1 
--AND do.CustomerIdx=3 --Obetald
AND DC.LastName='drive off' --new 25102018
AND AA.ArticleIdx<>-1
GROUP BY DS.StoreId,AA.Lev2ArticleHierarchyId, aa.ArticleName)
, Customers AS (
SELECT DS.StoreId,AA.Lev2ArticleHierarchyId,COUNT(DISTINCT DO.ReceiptId) AS NuberOfCustomers 
FROM RBIM.Fact_ReceiptRowSalesAndReturn DO 
JOIN RBIM.Dim_Article AA ON AA.ArticleIdx = DO.ArticleIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = DO.StoreIdx
WHERE 1=1
AND DO.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND ds.StoreId = @StoreId --AND ds.isCurrentStore = 1 
AND AA.ArticleIdx<>-1
GROUP BY DS.StoreId,AA.Lev2ArticleHierarchyId)
, FuelCustomers AS (
SELECT DS.StoreId,AA.Lev2ArticleHierarchyId,aa.articleName ,COUNT(DISTINCT DO.ReceiptId) AS NuberOfCustomers 
FROM RBIM.Fact_ReceiptRowSalesAndReturn DO 
JOIN RBIM.Dim_Article AA ON AA.ArticleIdx = DO.ArticleIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = DO.StoreIdx
WHERE 1=1
AND DO.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND ds.StoreId = @StoreId --AND ds.isCurrentStore = 1 
AND AA.Lev2ArticleHierarchyId=990
AND AA.ArticleIdx<>-1
GROUP BY DS.StoreId,AA.Lev2ArticleHierarchyId ,aa.articleName)
, FuelArticle AS ( 
select
 ds.StoreId
,DS.StoreName
,DA.Lev2ArticleHierarchyId
,da.Lev2ArticleHierarchyName 
,da.ArticleName 
,SUM(FR.NumberOfCustomers) AS NumberOfCustomers
,SUM(FR.QuantityOfArticlesSold-FR.QuantityOfArticlesInReturn) AS QuantityOfArticlesSold
,SUM(FR.WeighedSalesAmount-FR.WeighedReturnAmount)AS WeighedUnitOfMeasureAmount
,SUM(FR.SalesAmount+FR.ReturnAmount) AS SalesAmount
,SUM(fr.SalesAmountExclVat+FR.ReturnAmountExclVat) AS SalesPriceExclVat
FROM RBIM.Fact_ReceiptRowSalesAndReturn AS FR
JOIN RBIM.Dim_Store AS DS ON ds.StoreIdx=fr.StoreIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = FR.ArticleIdx
WHERE 1=1
AND FR.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND DA.Lev2ArticleHierarchyId=990
AND ds.StoreId = @StoreId --AND ds.isCurrentStore = 1 
AND DA.ArticleIdx<>-1
GROUP BY DS.StoreId,DS.StoreName,DA.Lev2ArticleHierarchyId,DA.Lev2ArticleHierarchyName, da.articleName	)
, MainData AS (
SELECT 
DS.StoreId
,DS.StoreName
,DA.Lev2ArticleHierarchyId
,DA.Lev2ArticleHierarchyName
,'' AS ArticleName
,SUM(FR.NumberOfCustomers) AS NumberOfCustomers
,SUM(FR.QuantityOfArticlesSold-FR.QuantityOfArticlesInReturn) AS QuantityOfArticlesSold
,SUM(FR.WeighedSalesAmount-FR.WeighedReturnAmount)AS WeighedUnitOfMeasureAmount
,SUM(FR.SalesAmount+FR.ReturnAmount) AS SalesAmount
,SUM(fr.SalesAmountExclVat+FR.ReturnAmountExclVat) AS SalesPriceExclVat
FROM RBIM.Fact_ReceiptRowSalesAndReturn AS FR
JOIN RBIM.Dim_Store AS DS ON ds.StoreIdx=fr.StoreIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = FR.ArticleIdx
WHERE 1=1
AND FR.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND ds.StoreId = @StoreId --AND ds.isCurrentStore = 1 
AND DA.ArticleIdx<>-1
GROUP BY DS.StoreId,DS.StoreName,DA.Lev2ArticleHierarchyId,DA.Lev2ArticleHierarchyName
)

--Hovedspørring
SELECT 
 MA.StoreId
,MA.StoreName
,MA.Lev2ArticleHierarchyId AS GroupId
,ma.Lev2ArticleHierarchyName AS GroupName
,CASE WHEN MA.Lev2ArticleHierarchyId=990
      THEN fa.ArticleName
      ELSE MA.ArticleName
	  END AS 'ArticleName'
--,MA.WeighedUnitOfMeasureAmount AS QuantitySold
,CASE WHEN MA.Lev2ArticleHierarchyId=990
      THEN fa.WeighedUnitOfMeasureAmount
      ELSE MA.WeighedUnitOfMeasureAmount
	  END AS 'QuantitySold'
--,MA.SalesAmount AS SalesRevenueInclVat
,CASE WHEN MA.Lev2ArticleHierarchyId=990
      THEN fa.SalesAmount
      ELSE MA.SalesAmount
	  END AS 'SalesRevenueInclVat'
--,MA.SalesPriceExclVat AS SalesRevenueExclVat
,CASE WHEN MA.Lev2ArticleHierarchyId=990
      THEN fa.SalesPriceExclVat
      ELSE MA.SalesPriceExclVat
	  END AS 'SalesRevenueExclVat'
--,ISNULL(DO.SalesPrice,0) AS 'DriveOff'
,CASE WHEN MA.Lev2ArticleHierarchyId=990
      THEN ISNULL(fdo.SalesPrice,0)
      ELSE ISNULL(DO.SalesPrice,0)
	  END AS 'DriveOff'
--,CU.NuberOfCustomers
,CASE WHEN MA.Lev2ArticleHierarchyId=990
      THEN FC.NuberOfCustomers
      ELSE CU.NuberOfCustomers
	  END AS 'NuberOfCustomers'
 FROM MainData MA
LEFT JOIN DriveOff DO ON DO.Lev2ArticleHierarchyId = MA.Lev2ArticleHierarchyId  AND do.StoreId=ma.StoreId		-- Sum for DriveOff
LEFT JOIN Customers CU ON CU.Lev2ArticleHierarchyId = MA.Lev2ArticleHierarchyId  AND cu.StoreId=ma.StoreId		-- Count Customers
LEFT JOIN FuelArticle FA ON FA.Lev2ArticleHierarchyId = MA.Lev2ArticleHierarchyId AND FA.StoreId = MA.StoreId	-- FuelArticles
LEFT JOIN FuelCustomers FC ON FC.ArticleName = FA.ArticleName AND FC.StoreId = MA.StoreId						-- FuelCustomer
LEFT JOIN FuelDriveOff FDO ON FDO.ArticleName = FA.ArticleName AND FDO.StoreId = MA.StoreId						-- FuelDriveOff
ORDER BY MA.Lev2ArticleHierarchyId


END 




GO

