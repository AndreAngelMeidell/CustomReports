USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_4805_Personalrabatt]    Script Date: 19.09.2018 14:41:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_4805_Personalrabatt]
(   
    @StoreOrGroupNo AS VARCHAR(max),
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@StoreGroupCategory AS INTEGER

) 
AS  
BEGIN
  
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
------------------------------------------------------------------------------------------------------
DECLARE @GroupByHierarchy VARCHAR(100)
SET @GroupByHierarchy = CASE @StoreGroupCategory WHEN 1 THEN 'Store'
													WHEN 2 THEN 'RegionHierarchy'
													WHEN 3 THEN 'LegalHierarchy'
													WHEN 11 THEN 'ChainHierarchy'
													WHEN 12 THEN 'DistrictHierarchy' END
------------------------------------------------------------------------------------------------------
-- CTE contains stores that meets filtering requirements and flag IsCurrentStore=1

;WITH Stores AS (
SELECT DISTINCT ds.*	--(RS-27332)
FROM RBIM.Dim_Store ds
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL and ds.IsCurrentStore=1) --to ensure we only get historical changes for the same store (defined by same GLN and same ORG number)
,SelectedSales as (
SELECT 
DD.FullDate,
DS.StoreId,
DS.StoreName,
dc.FirstName, 
DC.LastName,
dc.CustomerId,
SR.ReceiptId,
SR.CashierUserIdx,
SR.CashRegisterNo,
da.ArticleName, da.ArticleDisplayId,
SUM(SR.QuantityOfArticlesSold) AS QuantityOfArticlesSold,
SUM(SR.Amount) AS Amount,
SUM(SR.DiscountAmount) AS DiscountAmount,
TT.TransTypeName, 
dpt.PriceTypeName,
SR.RowIdx
FROM RBIM.Fact_ReceiptRowSalesAndReturn (NoLock) AS SR
JOIN RBIM.Dim_Customer (NoLock) AS DC ON DC.CustomerIdx = SR.CustomerIdx 
JOIN RBIM.Dim_Date (NoLock) AS DD ON DD.DateIdx = SR.ReceiptDateIdx 
JOIN Stores AS DS ON DS.StoreIdx = SR.StoreIdx  
JOIN RBIM.Dim_TransType (NoLock) AS TT ON TT.TransTypeIdx = SR.TransTypeIdx
JOIN RBIM.Dim_PriceType (NoLock) AS DPT ON DPT.PriceTypeIdx = SR.PriceTypeIdx
JOIN RBIM.Dim_Article (NoLock) AS DA ON DA.ArticleIdx = SR.ArticleIdx
WHERE 1=1
AND SR.CustomerIdx>0
AND DD.FullDate  BETWEEN @DateFrom  AND @DateTo
AND dc.IsCompany=0
AND DS.IsCurrentStore=1
GROUP BY
DD.FullDate,
DS.StoreId,
DS.StoreName,
dc.FirstName, DC.LastName,
dc.CustomerId,
SR.ReceiptId,
SR.CashierUserIdx,
SR.CashRegisterNo,
SR.RowIdx,
da.ArticleName, da.ArticleDisplayId,TT.TransTypeName, dpt.PriceTypeName ) 

SELECT * FROM SelectedSales SS
ORDER BY
SS.FullDate,
SS.StoreId,
SS.StoreName,
SS.FirstName, SS.LastName,
SS.CustomerId,
SS.ReceiptId,
SS.CashierUserIdx,
SS.CashRegisterNo,
SS.RowIdx,
SS.ArticleName, SS.ArticleDisplayId,SS.TransTypeName, SS.PriceTypeName


END
GO

