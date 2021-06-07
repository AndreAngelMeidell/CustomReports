USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Drift]    Script Date: 15.01.2019 09:11:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Drift]     
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
,ReceiptTender AS (
		SELECT	
			dd.FullDate AS Date
			,DS.StoreID
			,SUM(CASE WHEN dat.AccumulationId = '1' THEN f.Count ELSE 0 END) AS NumberOfCustomers		-- kunder
			,SUM(CASE WHEN dat.AccumulationId = '11' THEN f.Count ELSE 0 END) AS NumberOfReturn			-- antall retur
			,SUM(CASE WHEN dat.AccumulationId = '11' THEN f.Amount ELSE 0 END) AS ReturnAmount			-- retur belop
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN f.Count ELSE 0 END) AS NumberOfCorrection	-- antall korrigerte (Past void)
			,SUM(CASE WHEN dat.AccumulationId IN ('5') THEN f.Amount ELSE 0 END) AS CorrectionAmount	-- korrigerte belop
			,SUM(CASE WHEN dat.AccumulationId = '10' THEN f.Count ELSE 0 END) AS NumberOfCanceled		-- antall kansellerte
			,SUM(CASE WHEN dat.AccumulationId = '19' THEN f.Count ELSE 0 END) AS Price					-- prisforesporsel
			,SUM(CASE WHEN dat.AccumulationId ='6' THEN f.Amount ELSE 0 END) AS Discount				-- rabatt
		FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType f
		JOIN stores AS DS ON DS.StoreIdx = f.StoreIdx
		JOIN RBIM.Dim_Date AS DD ON dd.DateIdx= f.ReconciliationDateIdx
		JOIN RBIM.Dim_AccumulationType dat ON dat.AccumulationTypeIdx = f.AccumulationTypeIdx
		WHERE dd.FullDate BETWEEN @DateFrom AND @DateTo
		--AND ds.StoreId = @StoreOrGroupNo
		GROUP BY dd.FullDate, DS.StoreId
)
			SELECT	
			 Date
			,StoreID
			,NumberOfCustomers		-- kunder
			,NumberOfReturn			-- antall retur
			,ReturnAmount			-- retur belop
			,NumberOfCorrection	-- antall korrigerte (Past void)
			,CorrectionAmount	-- korrigerte belop
			,NumberOfCanceled		-- antall kansellerte
			,Price					-- prisforesporsel
			,Discount				-- rabatt
		FROM ReceiptTender
		

END 


GO

