USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_EOD_Report_xml_data]    Script Date: 06.10.2020 07:51:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_EOD_Report_xml_data]
(
@StoreIds varchar(100),
@Level1FuelHierarchyId varchar(100),
@toDate DateTime,
@ignoreLastStopRowIdx bit
)
AS  
BEGIN
  
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

CREATE TABLE #Stores(StoreIdx int)
INSERT INTO  #Stores
SELECT DISTINCT ds.StoreIdx	
FROM [BI_Mart].RBIM.Dim_Store ds
LEFT JOIN ( SELECT ParameterValue FROM [BI_Mart].[dbo].[ufn_RBI_SplittParameterString](@StoreIds,',')) n  ON n.ParameterValue IN (
				ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
				ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
				ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
				ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
				ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL and ds.IsCurrentStore=1

SELECT rrsar.RowIdx, rrsar.Receiptheadidx, rrsar.StoreIdx, ds.StoreId, CAST(CONCAT(dd.FullDate, ' ', dt.TimeDescription) AS datetime) AS ReceiptDate, da.Lev1ArticleHierarchyName, da.Lev1ArticleHierarchyId, da.Lev2ArticleHierarchyName, da.Lev2ArticleHierarchyId, da.ArticleName, da.ArticleId
,CASE Lev1ArticleHierarchyId 
	WHEN @Level1FuelHierarchyId
	THEN 'FUEL'
	ELSE 'CR'
END as GroupType
,dc.FirstName + ' ' + dc.LastName AS CustomerName
,rrsar.[QuantityOfArticlesSold] - rrsar.[QuantityOfArticlesInReturn] AS Quantity
,rrsar.[UnitOfMeasureAmount] as UnitOfMeasureAmount
,rrsar.[SalesAmount] + rrsar.ReturnAmount AS SalesRevenueInclVat	             
,rrsar.[SalesVatAmount] + rrsar.[ReturnAmount] - rrsar.[ReturnAmountExclVat] AS SalesRevenueVat 
,rrsar.[SalesAmountExclVat] + rrsar.ReturnAmountExclVat AS SalesRevenueExclVat
FROM [BI_Mart].[RBIM].[Fact_ReceiptRowSalesAndReturn] rrsar
JOIN [BI_Mart].[RBIM].[Dim_Article] da ON da.ArticleIdx = rrsar.ArticleIdx 
JOIN [BI_Mart].[RBIM].[Dim_Store] ds ON ds.StoreIdx = rrsar.StoreIdx 
LEFT JOIN [BI_Mart].[RBIM].[Dim_Customer] dc ON dc.CustomerIdx = rrsar.CustomerIdx 
LEFT JOIN [BI_Mart].[RBIM].[Dim_Date] dd ON dd.DateIdx = rrsar.ReceiptDateIdx 
LEFT JOIN [BI_Mart].[RBIM].[Dim_Time] dt ON dt.TimeIdx = rrsar.ReceiptTimeIdx
JOIN #Stores s ON s.StoreIdx = rrsar.StoreIdx
WHERE rrsar.ArticleIdx <> -1
and (rrsar.SalesAmount != 0 or rrsar.ReturnAmount != 0)
and CAST(CONCAT(dd.FullDate, ' ', dt.TimeDescription) AS datetime) < @toDate
and (@ignoreLastStopRowIdx = 1 or rrsar.RowIdx > ISNULL((SELECT LastStopRowIdx FROM [IDC].[dbo].[NextDeltaForEODFileExport] WHERE ExtractSourceName = 'BI_Mart.RBIM.Fact_ReceiptRowSalesAndReturn' and LoadDestinationName = 'EndOfDay.File.Exporter' and StoreIdx = rrsar.StoreIdx),0))

DROP TABLE #Stores

END
GO

