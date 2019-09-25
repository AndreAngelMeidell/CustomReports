USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2158_dsTopNSalesReport_data]    Script Date: 06.09.2019 13:40:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_2158_dsTopNSalesReport_data]
(   
    @StoreOrGroupNo AS VARCHAR(MAX),
	--@StoreId AS VARCHAR(100), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@OrderBy AS VARCHAR(50) = 'TopNetSales', --'TopQuantity','TopNetSales','TopGrossProfit', 'LowGrossProfit', 'LowNetSales'
	@Top AS INTEGER ,
	@SupplierId AS VARCHAR(100),		
	@ArticleGroupId AS VARCHAR(100),
	@ReportType AS SMALLINT	
	
) 
AS  
BEGIN
  
------------------------------------------------------------------------------------------------------

--20190225: Korrigert av Andre Meidell 20190225: fjernet fast top line. Endret til Cov_CustomerFlightInfo
--20190401: Kopi av 1158 til 2158, butikk velger. 

----------------------------------------------------------------------
--Find stores
----------------------------------------------------------------------

DECLARE @stores TABLE(
StoreIdx INT,
StoreId VARCHAR(MAX),
StoreName VARCHAR(MAX))

INSERT INTO @stores
SELECT DISTINCT ds.StoreIdx, ds.StoreId, ds.StoreName
FROM RBIM.Dim_Store ds (NOLOCK)
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL AND ds.isCurrent=1 -- ds.IsCurrentStore=1 OLD


SELECT TOP (@Top) *
FROM (
SELECT 
StoreId
,StoreName
,ArticleName
,Gtin
,SupplierArticleNo
,SoldQuantity
,NetSales
,GrossProfit
FROM (
	SELECT
		ds.StoreId
		,ds.StoreName
		,da.ArticleName AS ArticleName 
		--,CASE WHEN ISNULL(dg.GtinIdx,-1) < 0 THEN NULL ELSE dg.Gtin END AS Gtin 
		, MAX(dg.Gtin) AS Gtin
		,OAEI.Value_ArticleReceiptText2 AS SupplierArticleNo           
		,SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS SoldQuantity -- Antall
		,SUM(f.[SalesAmountExclVat] + f.ReturnAmountExclVat) AS NetSales --Netto Omsetning
		,SUM(f.[GrossProfit]) AS GrossProfit -- Brutto Kroner
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f
		JOIN rbim.Dim_Date dd ON dd.DateIdx = f.ReceiptDateIdx 
		--JOIN rbim.Dim_Store ds ON ds.storeidx = f.storeidx
		JOIN @stores ds ON ds.StoreIdx = f.StoreIdx 
		JOIN rbim.Dim_Article da ON da.ArticleIdx = f.ArticleIdx
		LEFT JOIN RBIM.Out_ArticleExtraInfo AS OAEI ON OAEI.ArticleId = da.ArticleId AND OAEI.Name_ArticleReceiptText2='Bongtekst 2'
		JOIN rbim.Dim_Supplier dsup ON dsup.SupplierIdx = f.SupplierIdx
		JOIN RBIM.Dim_Gtin dg ON dg.GtinIdx = f.GtinIdx AND dg.isCurrent=1
		LEFT JOIN RBIM.Cov_CustomerFlightInfo AS se ON se.ReceiptHeadIdx = f.ReceiptHeadIdx
		--JOIN RBIM.Cov_CustomerSalesEvent AS CCSE ON FLOOR((CCSE.ReceiptIdx/1000)) = FLOOR((f.ReceiptIdx/1000)) AND CCSE.CashierUserIdx = f.CashierUserIdx AND CCSE.StoreIdx = f.StoreIdx
		WHERE 1=1
		--  filter on store
		-- AND @StoreId = ds.StoreId
		-- AND ds.isCurrentStore = 1   	
		-- make sure you only get the 'current store' 
		-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
		AND  dd.FullDate BETWEEN @DateFrom AND @DateTo
		--AND f.ArticleIdx > -1 
		AND da.Is3rdpartyArticle = 0
		--AND (@SupplierId=dsup.SupplierId OR ISNULL(@SupplierId,'-1')='-1')
		AND (@ArticleGroupId IN (da.Lev1ArticleHierarchyId, da.Lev2ArticleHierarchyId, da.Lev3ArticleHierarchyId, da.Lev4ArticleHierarchyId, da.Lev5ArticleHierarchyId) 
					OR ISNULL(@ArticleGroupId,'-1')='-1')
		--new for FlightType
		AND  

			 (	@ReportType = 0 -- all flights
					OR (@ReportType = 1 AND se.OriginCode = 'D') -- departure flights
					OR (@ReportType = 2 AND se.OriginCode = 'A') -- arrival flights
					OR (@ReportType = 3 AND (se.OriginCode = '' OR se.OriginCode IS NULL))) -- extra flights	
								  
		GROUP BY ds.StoreId,ds.StoreName,da.ArticleName, OAEI.Value_ArticleReceiptText2
		) AS f
) AS f
ORDER BY 
CASE WHEN @OrderBy = 'TopQuantity' THEN f.SoldQuantity ELSE NULL END DESC,
CASE WHEN @OrderBy = 'TopNetSales' THEN f.NetSales ELSE NULL END DESC,
CASE WHEN @OrderBy = 'TopGrossProfit' THEN f.GrossProfit ELSE NULL END DESC,
CASE WHEN @OrderBy = 'LowGrossProfit' THEN f.GrossProfit ELSE NULL END ASC,
CASE WHEN @OrderBy = 'LowNetSales' THEN f.NetSales ELSE NULL END ASC
END


GO

