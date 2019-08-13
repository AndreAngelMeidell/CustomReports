USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Oppgjor]    Script Date: 15.05.2018 08:41:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationMonthlyReport_Oppgjor]     
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
, ReceiptTender AS 		
(
SELECT 
			 dd.FullDate AS Date
			,ds.StoreID
			,ds.StoreName
			,SUM(CASE WHEN dt.TenderId IN ('1','2','3','5','6', '8','14','19','22') THEN fc.Amount ELSE NULL END) AS TotalAmount		-- Total
			,SUM(CASE WHEN dt.TenderId = '1' THEN fc.Amount ELSE NULL END) AS CountedCash										-- SYSTEM CASH
			,SUM(CASE WHEN dt.TenderId IN ('3','14','5') THEN fc.Amount ELSE NULL END) AS PaymentCard								-- kort og reserveløsning
			,SUM(CASE WHEN dt.TenderId = '6' THEN fc.Amount ELSE NULL END) AS AccountSale                                       -- kundekreditt
			,SUM(CASE WHEN dt.TenderId = '22' THEN fc.Amount ELSE NULL END) AS MobilePay                                        -- mobil betaling
			,SUM(CASE WHEN dt.TenderId IN ('2','19') THEN fc.Amount ELSE NULL END) AS GiftCardAndVoucher                       -- kupong og gavekort
			,SUM(CASE WHEN dt.TenderId = '8' THEN fc.Amount ELSE NULL END) AS Currency                                          -- valuta
			,SUM(CASE WHEN dt.TenderId = '25' THEN fc.Amount ELSE NULL END) AS Panto											--25	Panto
			,SUM(CASE WHEN dt.TenderId = '23' THEN fc.Amount ELSE NULL END) AS Coupon											--23 Coupon
			,0 AS TaltKontant
			,0 AS SpilliKasse
			,0 AS Cash
		FROM RBIM.Fact_ReconciliationSystemTotalPerTender AS fc
		JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
		JOIN RBIM.Dim_Date dd ON dd.DateIdx = fc.ReconciliationDateIdx
		JOIN Stores AS DS ON DS.StoreIdx = fc.StoreIdx
		WHERE 1=1
		--AND ds.StoreId = @StoreOrGroupNo
		--AND DS.isCurrent=1
		AND dd.FullDate BETWEEN @DateFrom AND @DateTo
		GROUP BY dd.FullDate , ds.StoreId, ds.StoreName
		--ORDER BY ds.StoreId, dd.FullDate 
UNION all
SELECT 
			 dd.FullDate AS Date
			,ds.StoreID
			,ds.StoreName
			,0 AS TotalAmount				
			,0 AS CountedCash									
			,0 AS PaymentCard				        
			,0 AccountSale                                  
			,0 AS MobilePay                                       
			,0 AS GiftCardAndVoucher                       
			,0 AS Currency                                         
			,0 AS Panto
			,0 AS Coupon	
			,SUM(fc.Amount) AS TaltKontant												--Kontant
			,0 AS SpilliKasse
			,SUM(CASE WHEN dt.TenderId = '1' THEN fc.Amount ELSE NULL END) AS Cash		--Talt kontant
		FROM RBIM.Fact_ReconciliationCountingPerTender AS fc
		JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = fc.TenderIdx
		JOIN RBIM.Dim_Date dd ON dd.DateIdx = fc.CountingDateIdx
		JOIN Stores AS DS ON DS.StoreIdx = fc.StoreIdx
		WHERE 1=1
		--AND ds.StoreId = @StoreOrGroupNo
		--AND DS.isCurrent=1
		AND dd.FullDate BETWEEN @DateFrom AND @DateTo
		GROUP BY dd.FullDate , ds.StoreId, ds.StoreName
UNION ALL
SELECT 
			 dd.FullDate AS Date
			,ds.StoreID
			,ds.StoreName
			,0 AS TotalAmount	
			,0 AS CountedCash								
			,0 AS PaymentCard								
			,0 AccountSale                                 
			,0 AS MobilePay                                
			,0 AS GiftCardAndVoucher						
			,0 AS Currency                                  
			,0 AS Panto
			,0 AS Coupon	
			,0 AS TaltKontant
			,SUM(fr.Amount*ISNULL(NULLIF(fr.ExchangeRateToLocalCurrency,0.0),1.0)) AS SpilliKasse -- Spill i Kasse
			,0 AS Cash
FROM RBIM.Fact_Receipt AS FR
		INNER JOIN Stores AS DS ON DS.StoreIdx = FR.StoreIdx
		INNER JOIN RBIM.Dim_Date AS DD ON fr.ReceiptDateIdx = dd.DateIdx
		JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = FR.ArticleIdx
WHERE 1=1
		AND da.Lev4ArticleHierarchyId='241230' --Spill i kasse
		--AND ds.StoreId = @StoreOrGroupNo
		--AND DS.isCurrent=1
		AND dd.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY dd.FullDate , ds.StoreId,ds.StoreName
		
)
select		Date
			,StoreID
			,StoreName
			,SUM(TotalAmount) AS TotalAmount	
			,SUM(CountedCash) AS  CountedCash										-- kontant
			,SUM(PaymentCard) AS PaymentCard										-- kort og reserveløsning
			,SUM(AccountSale) AS AccountSale                                       -- kundekreditt
			,SUM(MobilePay) AS MobilePay											-- mobil betaling
			,SUM(GiftCardAndVoucher) AS GiftCardAndVoucher							-- kupong og gavekort
			,SUM(Currency) AS Currency												-- valuta
			,SUM(Panto) AS Panto
			,SUM(Coupon) AS Coupon	
			,SUM(TaltKontant) AS TaltKontant										-- Talt kontant
			,SUM(SpilliKasse) AS SpilliKasse
			,SUM((ISNULL(CountedCash,0)-ISNULL(Cash,0))) AS CashDeviation
FROM ReceiptTender 
GROUP by date, storeid, StoreName
order by date

END 



GO

