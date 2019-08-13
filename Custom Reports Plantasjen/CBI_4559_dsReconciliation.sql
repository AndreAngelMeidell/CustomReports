USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_4559_dsReconciliation]    Script Date: 21.06.2018 13:50:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_4559_dsReconciliation] 
(   
    @StoreOrGroupNo AS VARCHAR(MAX),
	@DateFrom AS DATE, 
	@DateTo AS DATE
	
) 
AS 
BEGIN
SET NOCOUNT ON;



--EXEC usp_CBI_4559_dsReconciliation 
--	@StoreOrGroupNo = '12655', 
--	@DateFrom = '01-jan-2018',
--	@DateTo = '05-may-2018'


;WITH Stores AS (
SELECT DISTINCT ds.*	
FROM RBIM.Dim_Store ds
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1 AND ds.isCurrent=1)

,SelectedDates AS (
SELECT * FROM RBIM.Dim_Date AS DD 
WHERE 1=1
AND  dd.FullDate BETWEEN @DateFrom AND @DateTo
)

 
SELECT DISTINCT ds.StoreId, dd.FullDate FROM RBIM.Agg_SalesAndReturnPerDay asr
   JOIN Stores ds ON ds.StoreIdx = asr.StoreIdx
   JOIN SelectedDates dd ON dd.DateIdx = asr.ReceiptDateIdx 
WHERE 1=1 


END





GO

