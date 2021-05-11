USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]    Script Date: 11.05.2021 09:00:18 ******/
DROP PROCEDURE [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]    Script Date: 11.05.2021 09:00:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]
(   
   @StoreOrGroupNo AS VARCHAR(8000),
	@PeriodType AS VARCHAR(1), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@YearToDate AS INTEGER, 
	@RelativePeriodType AS VARCHAR(5),
	@RelativePeriodStart AS INTEGER, 
	@RelativePeriodDuration AS INTEGER ,	
	@StoreGroupCategory AS INTEGER,
	@GroupBy VARCHAR(100) = 'Article', -- StoreGroup,  Article, ArticleHierarchy
	@Filter VARCHAR(100) = null
) 
AS  
BEGIN
  
set nocount on;
------------------------------------------------------------------------------------------------------
DECLARE @GroupByHierarchy VARCHAR(100)
SET @GroupByHierarchy = CASE @StoreGroupCategory WHEN 1 THEN 'Store'
													WHEN 2 THEN 'RegionHierarchy'
													WHEN 3 THEN 'LegalHierarchy'
													WHEN 11 THEN 'ChainHierarchy'
													WHEN 12 THEN 'DistrictHierarchy' END


DECLARE  @DateFromIdx INTEGER  = cast(convert(char(8), @DateFrom, 112) as integer)
DECLARE  @DateToIdx INTEGER  = cast(convert(char(8), @DateTo, 112) as integer)

----------------------------------------------------------------------
--Find stores
----------------------------------------------------------------------

DECLARE @stores TABLE(
StoreIdx INT,
StoreId VARCHAR(MAX),
StoreName VARCHAR(MAX),
Lev1RegionGroupName VARCHAR(MAX),
Lev1LegalGroupName VARCHAR(MAX),
Lev1ChainGroupName VARCHAR(MAX),
Lev1DistrictGroupName VARCHAR(MAX),
Lev2RegionGroupName  VARCHAR(MAX),
Lev2LegalGroupName VARCHAR(MAX),
Lev2ChainGroupName VARCHAR(MAX),
Lev2DistrictGroupName VARCHAR(MAX),
Lev3RegionGroupName VARCHAR(MAX), 
Lev3LegalGroupName VARCHAR(MAX),
Lev3ChainGroupName VARCHAR(MAX),
Lev3DistrictGroupName VARCHAR(MAX),
Lev4RegionGroupName  VARCHAR(MAX),
Lev4LegalGroupName VARCHAR(MAX),
Lev4ChainGroupName VARCHAR(MAX),
Lev4DistrictGroupName VARCHAR(MAX),
Lev5RegionGroupName  VARCHAR(MAX),
Lev5LegalGroupName VARCHAR(MAX),
Lev5ChainGroupName VARCHAR(MAX),
Lev5DistrictGroupName VARCHAR(MAX),
NumOfRegionLevels INT,
NumOfLegalLevels INT,
NumOfChainLevels INT,
NumOfDistrictLevels INT
)

INSERT INTO @stores
SELECT DISTINCT ds.StoreIdx, ds.StoreId, ds.StoreName, Lev1RegionGroupName,Lev1LegalGroupName,Lev1ChainGroupName,Lev1DistrictGroupName,Lev2RegionGroupName,Lev2LegalGroupName,Lev2ChainGroupName ,Lev2DistrictGroupName ,Lev3RegionGroupName, Lev3LegalGroupName,Lev3ChainGroupName ,Lev3DistrictGroupName,Lev4RegionGroupName,Lev4LegalGroupName,Lev4ChainGroupName,Lev4DistrictGroupName,Lev5RegionGroupName,ds.Lev5LegalGroupName,Lev5ChainGroupName,Lev5DistrictGroupName,NumOfRegionLevels,NumOfLegalLevels,NumOfChainLevels,NumOfDistrictLevels	--(RS-27332)
FROM RBIM.Dim_Store ds (NOLOCK)
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL and ds.IsCurrentStore=1

----------------------------------------------------------------------


IF  @GroupBy = 'StoreGroup' 
BEGIN 
SELECT 
	 CASE WHEN Lev1Name = '' THEN NULL ELSE Lev1Name END AS Lev1Name
	,CASE WHEN Lev2Name = '' THEN NULL ELSE Lev2Name END AS Lev2Name
	,CASE WHEN Lev3Name = '' THEN NULL ELSE Lev3Name END AS Lev3Name
	,CASE WHEN Lev4Name = '' THEN NULL ELSE Lev4Name END AS Lev4Name
  	,CASE WHEN Lev5Name = '' THEN NULL ELSE Lev5Name END AS Lev5Name
	,NumOfLevels 
	,Store
	,StoreId
	,NULL AS Id
	,SUM(RevenueInclVat) AS RevenueInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(SalesVatAmount) AS SalesVatAmount
FROM 
	(SELECT 
		 case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev1RegionGroupName 
			when 'LegalHierarchy' then ds.Lev1LegalGroupName
			when 'ChainHierarchy' then ds.Lev1ChainGroupName
			when 'DistrictHierarchy' then ds.Lev1DistrictGroupName
			when 'Store' then null
			end as Lev1Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev2RegionGroupName 
			when 'LegalHierarchy' then ds.Lev2LegalGroupName
			when 'ChainHierarchy' then ds.Lev2ChainGroupName
			when 'DistrictHierarchy' then ds.Lev2DistrictGroupName
			when 'Store' then null
			end as Lev2Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev3RegionGroupName 
			when 'LegalHierarchy' then ds.Lev3LegalGroupName
			when 'ChainHierarchy' then ds.Lev3ChainGroupName
			when 'DistrictHierarchy' then ds.Lev3DistrictGroupName
			when 'Store' then null
			end as Lev3Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev4RegionGroupName 
			when 'LegalHierarchy' then ds.Lev4LegalGroupName
			when 'ChainHierarchy' then ds.Lev4ChainGroupName
			when 'DistrictHierarchy' then ds.Lev4DistrictGroupName
			when 'Store' then null
			end as Lev4Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev5RegionGroupName 
			when 'LegalHierarchy' then ds.Lev5LegalGroupName
			when 'ChainHierarchy' then ds.Lev5ChainGroupName
			when 'DistrictHierarchy' then ds.Lev5DistrictGroupName
			when 'Store' then null
			end as Lev5Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.NumOfRegionLevels
			when 'LegalHierarchy' then ds.NumOfLegalLevels
			when 'ChainHierarchy' then ds.NumOfChainLevels
			when 'DistrictHierarchy' then ds.NumOfDistrictLevels
			when 'Store' then 0
			end as NumOfLevels
		,ds.StoreName as Store
		,ds.StoreId
		,da.ArticleName
		,da.ArticleId
		,da.Lev1ArticleHierarchyName
		,da.Lev1ArticleHierarchyId
		,da.Lev2ArticleHierarchyName
		,da.Lev2ArticleHierarchyId
		,f.ReceiptDateIdx
		,f.[SalesAmount] + f.[ReturnAmount] AS RevenueInclVat -- Omsetning
		,(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS Revenue --Netto Omsetning
		,f.[SalesVatAmount]  AS [SalesVatAmount] -- MVA kroner
		--INTO #temp_Selected_Sales
		from BI_Mart.RBIM.Agg_SalesAndReturnPerDay f (NOLOCK) 
		--join rbim.Dim_Date dd (NOLOCK)  ON dd.DateIdx = f.ReceiptDateIdx 
		join rbim.Dim_Article da (NOLOCK)  ON da.ArticleIdx = f.ArticleIdx 
		join @Stores ds on ds.storeidx = f.storeidx
		WHERE 1=1 																																		
		--  filter on period
		 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)
		 AND f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
	) s
WHERE ISNULL(@Filter,s.ArticleId) IN (s.Lev1ArticleHierarchyId, s.Lev2ArticleHierarchyId, s.ArticleId)
GROUP BY Lev1Name, Lev2Name, Lev3Name, Lev4Name, Lev5Name, NumOfLevels, Store, StoreId 
ORDER BY Lev1Name

END


ELSE
BEGIN

SELECT CASE 
			WHEN @GroupBy ='Article' THEN ArticleName 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NULL THEN  Lev1ArticleHierarchyName 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NOT NULL THEN  Lev2ArticleHierarchyName 
	END AS Lev1Name
	,NULL AS Lev2Name
	,NULL AS Lev3Name
	,NULL AS Lev4Name
  	,NULL AS Lev5Name
	,CASE 
			WHEN @GroupBy ='Article' THEN 0 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NULL THEN  2
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NOT NULL THEN  1 
			END AS NumOfLevels 
	,NULL AS Store
	,NULL AS StoreId
	,CASE 
			WHEN @GroupBy ='Article' THEN ArticleId 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NULL THEN  Lev1ArticleHierarchyId 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NOT NULL THEN  Lev2ArticleHierarchyId 
	END AS Id 
	,SUM(RevenueInclVat) AS RevenueInclVat 
	,SUM(Revenue) AS Revenue 
	,SUM(SalesVatAmount) AS SalesVatAmount
FROM 	
	(SELECT 
		 case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev1RegionGroupName 
			when 'LegalHierarchy' then ds.Lev1LegalGroupName
			when 'ChainHierarchy' then ds.Lev1ChainGroupName
			when 'DistrictHierarchy' then ds.Lev1DistrictGroupName
			when 'Store' then null
			end as Lev1Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev2RegionGroupName 
			when 'LegalHierarchy' then ds.Lev2LegalGroupName
			when 'ChainHierarchy' then ds.Lev2ChainGroupName
			when 'DistrictHierarchy' then ds.Lev2DistrictGroupName
			when 'Store' then null
			end as Lev2Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev3RegionGroupName 
			when 'LegalHierarchy' then ds.Lev3LegalGroupName
			when 'ChainHierarchy' then ds.Lev3ChainGroupName
			when 'DistrictHierarchy' then ds.Lev3DistrictGroupName
			when 'Store' then null
			end as Lev3Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev4RegionGroupName 
			when 'LegalHierarchy' then ds.Lev4LegalGroupName
			when 'ChainHierarchy' then ds.Lev4ChainGroupName
			when 'DistrictHierarchy' then ds.Lev4DistrictGroupName
			when 'Store' then null
			end as Lev4Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.Lev5RegionGroupName 
			when 'LegalHierarchy' then ds.Lev5LegalGroupName
			when 'ChainHierarchy' then ds.Lev5ChainGroupName
			when 'DistrictHierarchy' then ds.Lev5DistrictGroupName
			when 'Store' then null
			end as Lev5Name
		,case @GroupByHierarchy 
			when 'RegionHierarchy' then ds.NumOfRegionLevels
			when 'LegalHierarchy' then ds.NumOfLegalLevels
			when 'ChainHierarchy' then ds.NumOfChainLevels
			when 'DistrictHierarchy' then ds.NumOfDistrictLevels
			when 'Store' then 0
			end as NumOfLevels
		,ds.StoreName as Store
		,ds.StoreId
		,da.ArticleName
		,da.ArticleId
		,da.Lev1ArticleHierarchyName
		,da.Lev1ArticleHierarchyId
		,da.Lev2ArticleHierarchyName
		,da.Lev2ArticleHierarchyId
		,f.ReceiptDateIdx
		,f.[SalesAmount] + f.[ReturnAmount] AS RevenueInclVat -- Omsetning
		,(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS Revenue --Netto Omsetning
		,f.[SalesVatAmount]  AS [SalesVatAmount] -- MVA kroner
		--INTO #temp_Selected_Sales
		from BI_Mart.RBIM.Agg_SalesAndReturnPerDay f (NOLOCK) 
		--join rbim.Dim_Date dd (NOLOCK)  ON dd.DateIdx = f.ReceiptDateIdx 
		join rbim.Dim_Article da (NOLOCK)  ON da.ArticleIdx = f.ArticleIdx 
		join @Stores ds on ds.storeidx = f.storeidx
		WHERE 1=1 																																		
		--  filter on period
		 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)
		 AND f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
	) s
WHERE ISNULL(@Filter,s.ArticleId) IN (s.Lev1ArticleHierarchyId, s.Lev2ArticleHierarchyId, s.ArticleId)
GROUP BY CASE 
			WHEN @GroupBy ='Article' THEN ArticleName 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NULL THEN  Lev1ArticleHierarchyName 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NOT NULL THEN  Lev2ArticleHierarchyName 
			END
			,CASE 
			WHEN @GroupBy ='Article' THEN ArticleId 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NULL THEN  Lev1ArticleHierarchyId 
			WHEN @GroupBy ='ArticleHierarchy' AND @Filter IS NOT NULL THEN  Lev2ArticleHierarchyId 
			END
ORDER BY Lev1Name
END

END


GO

