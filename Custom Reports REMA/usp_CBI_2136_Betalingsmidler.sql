USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2136_Betalingsmidler]    Script Date: 15.01.2019 09:12:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[usp_CBI_2136_Betalingsmidler] 
(   
    @StoreOrGroupNo AS VARCHAR(MAX),
	@DateFrom AS DATE, 
	@DateTo AS DATE
	
) 
AS 
BEGIN
SET NOCOUNT ON;

;WITH Stores AS (
SELECT DISTINCT ds.*	--(RS-27332)
FROM RBIM.Dim_Store ds
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL AND ds.IsCurrentStore=1 AND ds.isCurrent=1) --to ensure we only get historical changes for the same store (defined by same GLN and same ORG number)

,SelectedSales AS (
 SELECT  ds.StoreId, ds.StoreName, ds.Lev1RegionGroupName, ds.Lev2RegionGroupName, ds.Lev3RegionGroupName, ds.Lev4RegionGroupName
,SUM(CASE WHEN frt.TenderIdx IN ('1','9') THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Kontant
,SUM(CASE WHEN frt.TenderIdx IN ('3','5','14') AND frt.SubTenderIdx IN ('1','4')  THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS BankAxept 
,SUM(CASE WHEN frt.TenderIdx IN ('3') AND frt.SubTenderIdx IN ('2')  THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Visa
,SUM(CASE WHEN frt.TenderIdx IN ('3') AND frt.SubTenderIdx IN ('3')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS MasterCard 
,SUM(CASE WHEN frt.TenderIdx IN ('3') AND frt.SubTenderIdx IN ('9')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Maestro
,SUM(CASE WHEN frt.TenderIdx IN ('6')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Kreditt 
,SUM(CASE WHEN frt.TenderIdx IN ('3') AND frt.SubTenderIdx IN ('33')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS RemaGavekort
,SUM(CASE WHEN frt.TenderIdx IN ('7')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS GavekortAnnet 
,SUM(CASE WHEN frt.TenderIdx IN ('22')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Mobilbetaling 
,SUM(CASE WHEN frt.TenderIdx IN ('23')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Coupon
	, 0 AS Bank1
	, 0 AS Bank2
	, 0 AS Bank3
	, 0 AS Div1
	, 0 AS Div2
	, 0 AS Div3
FROM RBIM.Fact_ReceiptTender AS frt
	JOIN Stores AS ds ON ds.StoreIdx = frt.StoreIdx	
	INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = frt.ReceiptDateIdx
	LEFT JOIN RBIM.Dim_SubTender AS DST ON DST.SubTenderIdx = frt.SubTenderIdx	
WHERE 1=1 
		--AND ds.StoreId IN  (@StoreOrGroupNo)
		--(SELECT STOREID FROM RBIM.Dim_Store WHERE Lev2RegionGroupNo='3991' AND isCurrent=1) --Kodet til Oslo
		AND DS.isCurrent=1
		AND dd.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY ds.StoreId, ds.StoreName,ds.Lev1RegionGroupName, ds.Lev2RegionGroupName, ds.Lev3RegionGroupName, ds.Lev4RegionGroupName
--ORDER BY  ds.StoreId
) 
(
SELECT  StoreId, StoreName, Lev1RegionGroupName, Lev2RegionGroupName, Lev3RegionGroupName, Lev4RegionGroupName
,Kontant
,BankAxept 
,Visa 
,MasterCard
,Maestro
,Kreditt 
,RemaGavekort
,GavekortAnnet 
,Mobilbetaling 
,Coupon
	,Bank1
	,Bank2
	,Bank3
	,Div1
	,Div2
	,Div3
FROM SelectedSales)
--GROUP BY ds.StoreId, ds.StoreName,ds.Lev1RegionGroupName, ds.Lev2RegionGroupName, ds.Lev3RegionGroupName, ds.Lev4RegionGroupName
ORDER BY  StoreId


END




GO

