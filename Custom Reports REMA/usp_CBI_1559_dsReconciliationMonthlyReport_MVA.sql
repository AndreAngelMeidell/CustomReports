USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_MVA]    Script Date: 15.01.2019 09:11:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_MVA]     
(
	@StoreOrGroupNo AS VARCHAR(MAX),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME 
	)
AS  
BEGIN 

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
,ReceiptTender AS 
(
SELECT ds.storeId
	,agg.VatGroup
	,SUM(agg.SalesAmount + agg.ReturnAmount) AS SalesAmount
	,SUM(agg.SalesVatAmount + agg.ReturnVatAmount) AS SalesVatAmount
	,SUM(agg.SalesAmountExclVat + agg.ReturnAmountExclVat) AS SalesAmountExclVat
FROM RBIM.Agg_VatGroupSalesAndReturnPerDay agg
	JOIN Stores ds ON ds.StoreIdx = agg.StoreIdx
	JOIN rbim.Dim_Date dd ON dd.DateIdx = agg.ReceiptDateIdx
WHERE 1=1
	AND dd.FullDate BETWEEN @DateFrom AND @DateTo 
	--AND ds.StoreId = @StoreOrGroupNo
	--AND ds.IsCurrentStore = 1
GROUP BY ds.StoreId, agg.VatGroup
)
SELECT 
	storeId
	,VatGroup
	,SalesAmount
	,SalesVatAmount
	,SalesAmountExclVat
FROM ReceiptTender

END 



GO

