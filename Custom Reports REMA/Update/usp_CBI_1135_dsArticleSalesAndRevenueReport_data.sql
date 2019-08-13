USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueReport_data]    Script Date: 13.06.2018 11:27:06 ******/
DROP PROCEDURE [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueReport_data]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueReport_data]    Script Date: 13.06.2018 11:27:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueReport_data]
(   
   @StoreOrGroupNo AS VARCHAR(MAX),
	@PeriodType AS VARCHAR(1), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@YearToDate AS INTEGER, 
	@RelativePeriodType AS VARCHAR(5),
	@RelativePeriodStart AS INTEGER, 
	@RelativePeriodDuration AS INTEGER ,	
	--@ExcludeBottleDeposit AS INTEGER,
	--@ExcludeThirdPartyArticles AS INTEGER,
	--@ArticleIdFrom AS VARCHAR(50),
	--@ArticleIdTo AS VARCHAR(50),
    --@GtinFrom AS VARCHAR(50),
	--@GtinTo AS VARCHAR(50),		
	--@ArticleId AS VARCHAR(50) = '0',
	@StoreGroupCategory AS INTEGER,
	@GroupBy VARCHAR(100) = 'StoreGroup', -- StoreGroup, Article, ArticleHierarchy
	@Filter VARCHAR(100) = NULL
) 
AS  
BEGIN

--SET @PeriodType = 'D'
--SET @YearToDate = 0
--SET @RelativePeriodType = ''
--SET @RelativePeriodStart = 0
--SET @RelativePeriodDuration = 0
--SET @StoreGroupCategory = 11
--SET @GroupBy = 'StoreGroup' 
--SET @Filter = NULL

--SET @StoreOrGroupNo = '3991'

-- For test
--EXEC dbo.usp_CBI_1135_dsArticleSalesAndRevenueReport_data 
--  @StoreOrGroupNo = '2381', 
--	@PeriodType = 'D' , 
--	@DateFrom = '14-may-2018'  , 
--	@DateTo =  '14-may-2018'  ,
--	@YearToDate = 0  ,
--	@RelativePeriodType =  'D' , 
--  @RelativePeriodStart = 0 , 
--  @RelativePeriodDuration =0 , 
--	@StoreGroupCategory = '1'  ,
--	@GroupBy =   'StoreGroup' , 
--	@Filter = NULL


set nocount on;
------------------------------------------------------------------------------------------------------
DECLARE @GroupByHierarchy VARCHAR(100)
SET @GroupByHierarchy = CASE @StoreGroupCategory WHEN 1 THEN 'Store'
													WHEN 2 THEN 'RegionHierarchy'
													WHEN 3 THEN 'LegalHierarchy'
													WHEN 11 THEN 'ChainHierarchy'
													WHEN 12 THEN 'DistrictHierarchy' END
------------------------------------------------------------------------------------------------------
-- CTE contains stores that meets filtering requirements and flag IsCurrentStore=1

--Endringer 04062018 AM: Fjenrnet SIK(spill i kasse, panto og rema gavekort samt eksterne gavekort av omsetningen her)
--Endringer 05062018 AM: De vil ekskludere flere varegrupper kan du legge til disse:
--241010 - REMA Gavekort?
--241011 - Eksterne Gavekort?
--241013 - Provisjon til El-tjenester?
--241098 - Gavekort udefinert? 

;WITH Stores AS (
SELECT DISTINCT ds.*	--(RS-27332)
FROM RBIM.Dim_Store ds
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1 AND ds.isCurrent=1)
,SelectedSales AS (
SELECT 
 CASE @GroupByHierarchy 
	WHEN 'RegionHierarchy' THEN ds.Lev1RegionGroupName 
	WHEN 'LegalHierarchy' THEN ds.Lev1LegalGroupName
	WHEN 'ChainHierarchy' THEN ds.Lev1ChainGroupName
	WHEN 'DistrictHierarchy' THEN ds.Lev1DistrictGroupName
	WHEN 'Store' THEN NULL
   END AS Lev1Name
,CASE @GroupByHierarchy 
	WHEN 'RegionHierarchy' THEN ds.Lev2RegionGroupName 
	WHEN 'LegalHierarchy' THEN ds.Lev2LegalGroupName
	WHEN 'ChainHierarchy' THEN ds.Lev2ChainGroupName
	WHEN 'DistrictHierarchy' THEN ds.Lev2DistrictGroupName
	WHEN 'Store' THEN NULL
   END AS Lev2Name
,CASE @GroupByHierarchy 
	WHEN 'RegionHierarchy' THEN ds.Lev3RegionGroupName 
	WHEN 'LegalHierarchy' THEN ds.Lev3LegalGroupName
	WHEN 'ChainHierarchy' THEN ds.Lev3ChainGroupName
	WHEN 'DistrictHierarchy' THEN ds.Lev3DistrictGroupName
	WHEN 'Store' THEN NULL
   END AS Lev3Name
,CASE @GroupByHierarchy 
	WHEN 'RegionHierarchy' THEN ds.Lev4RegionGroupName 
	WHEN 'LegalHierarchy' THEN ds.Lev4LegalGroupName
	WHEN 'ChainHierarchy' THEN ds.Lev4ChainGroupName
	WHEN 'DistrictHierarchy' THEN ds.Lev4DistrictGroupName
	WHEN 'Store' THEN NULL
   END AS Lev4Name
,CASE @GroupByHierarchy 
	WHEN 'RegionHierarchy' THEN ds.Lev5RegionGroupName 
	WHEN 'LegalHierarchy' THEN ds.Lev5LegalGroupName
	WHEN 'ChainHierarchy' THEN ds.Lev5ChainGroupName
	WHEN 'DistrictHierarchy' THEN ds.Lev5DistrictGroupName
	WHEN 'Store' THEN NULL
   END AS Lev5Name
,CASE @GroupByHierarchy 
	WHEN 'RegionHierarchy' THEN ds.NumOfRegionLevels
	WHEN 'LegalHierarchy' THEN ds.NumOfLegalLevels
	WHEN 'ChainHierarchy' THEN ds.NumOfChainLevels
	WHEN 'DistrictHierarchy' THEN ds.NumOfDistrictLevels
	WHEN 'Store' THEN 0
   END AS NumOfLevels
,ds.StoreName AS Store
,ds.StoreId
,da.ArticleName
,da.ArticleId
,da.Lev1ArticleHierarchyName
,da.Lev1ArticleHierarchyId
--,dd.FullDate
,f.[NumberOfArticlesSold]-[NumberOfArticlesInReturn] AS Quantity -- Antall                            -- RS-26969
--,f.[SalesAmount] AS SalesAmount -- Omsetning
,(f.[SalesAmount] + f.ReturnAmount) AS SalesRevenueInclVat	           -- Omsetning		              -- RS-26969
,(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS SalesRevenue     --NetSales --Netto Omsetning   -- RS-26969
,f.[GrossProfit] AS GrossProfit -- Brutto Kroner,SUM(f.SalesAmountExclVat) AS [SalesAmountExclVat]    -- RS-26969
,f.[SalesPrice]+f.[ReturnAmount] AS [Price] -- Pris                                                   -- RS-27090 not a price this is just for price calculation per article
--,(f.NetPurchasePriceDerived + f.NetPurchasePrice) AS [PurchaseAmount]-- Innverdi
,f.CostOfGoods AS CostOfGoods                                     --[PurchaseAmount]  -- Innverdi -- RS-26969  --RS-27090 Ne column and rename				
--,f.[SalesVatAmount]  AS [SalesVatAmount] -- MVA kroner
,f.SalesVatAmount + f.ReturnAmount - f.ReturnAmountExclVat AS SalesRevenueVat     -- RS-26969
		,f.UseDerivedNetPrice
		,f.IsDerivedNetPriceUsed 
FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
JOIN rbim.Dim_Date dd ON dd.DateIdx = f.ReceiptDateIdx 
JOIN rbim.Dim_Article da ON da.ArticleIdx = f.ArticleIdx 
JOIN Stores ds ON ds.storeidx = f.storeidx
WHERE 

 (
	(@PeriodType='D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo)
	/*or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
	or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
	or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)*/
	)
AND da.Lev4ArticleHierarchyId NOT IN ('241230','241231','241232','241010','241098','241013','241011','241010')
) 
(
SELECT 
	 CASE WHEN Lev1Name = '' THEN NULL ELSE Lev1Name END AS Lev1Name
	,CASE WHEN Lev2Name = '' THEN NULL ELSE Lev2Name END AS Lev2Name
	,CASE WHEN Lev3Name = '' THEN NULL ELSE Lev3Name END AS Lev3Name
	,CASE WHEN Lev4Name = '' THEN NULL ELSE Lev4Name END AS Lev4Name
  	,CASE WHEN Lev5Name = '' THEN NULL ELSE Lev5Name END AS Lev5Name
	--,NULL AS NumOfLevels 
	,Store
	,StoreId
	--,NULL AS Id
	--,FullDate
	,SUM(Quantity) AS Quantity 
	,SUM(SalesRevenueInclVat) AS SalesRevenueInclVat
	,SUM(SalesRevenue) AS SalesRevenue
	,SUM(GrossProfit) AS GrossProfit 
	,SUM(Price) AS [Price]
	,SUM(CostOfGoods) AS CostOfGoods
	,SUM(SalesRevenueVat) AS SalesRevenueVat
	--,NULL   AS Config	
FROM SelectedSales
--WHERE @GroupBy = 'StoreGroup' 
GROUP BY Lev1Name, Lev2Name, Lev3Name, Lev4Name, Lev5Name, Store, StoreId )

ORDER BY Lev1Name
END




GO

