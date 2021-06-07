USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1521_AccountReconciliationMonth]    Script Date: 15.01.2019 09:11:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1521_AccountReconciliationMonth]
(   
    @StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME,
	@DateTo AS DATETIME
)
AS  
BEGIN

--DECLARE @StoreId AS VARCHAR(100) = 2301
--DECLARE @DateFrom AS DATE = '2018-09-01' 
--DECLARE @DateTo AS DATE = '2018-09-30'

;WITH SalesAndReturnPerDay AS (
SELECT 
 DS.StoreId
,DD.FullDate
,SUM(ASARPD.SalesRevenue) AS NettoOmsetning
,SUM(ASARPD.SalesRevenueInclVat) AS  BruttoOmsetning
,SUM(ASARPD.ReceiptRounding) AS RoundingAmount
FROM RBIM.Agg_SalesAndReturnPerDay AS ASARPD (NOLOCK)
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_Date AS DD ON dd.DateIdx=ASARPD.ReceiptDateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
WHERE ds.StoreId =  @StoreId AND ds.isCurrentStore = 1
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
--AND da.Lev3ArticleHierarchyId<>2412 -- SIK
--AND da.Lev4ArticleHierarchyId<>'241230'
AND da.Lev4ArticleHierarchyId NOT IN ('241230','241231','241232','241010','241098','241013','241011','241010')
GROUP BY DS.StoreId, DD.FullDate)
, ReciptTender AS (
SELECT 
DS.StoreId
,DD.FullDate
,SUM(CASE WHEN frt.TenderIdx IN ('3','5','14')  THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS BankAxept 
,SUM(CASE WHEN frt.TenderIdx IN ('6')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Kreditt 
,SUM(CASE WHEN frt.TenderIdx IN ('1','9') THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Kontant
,SUM(CASE WHEN frt.TenderIdx IN ('3') AND frt.SubTenderIdx IN ('33')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS RemaGavekort
,SUM(CASE WHEN frt.TenderIdx IN ('7')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS GavekortAnnet 
,SUM(CASE WHEN frt.TenderIdx IN ('23')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Retting 
FROM  RBIM.Fact_ReceiptTender AS FRT (NOLOCK)
JOIN RBIM.Dim_Date AS DD ON dd.DateIdx=frt.ReceiptDateIdx
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = FRT.StoreIdx
LEFT JOIN RBIM.Dim_Tender AS DT ON DT.TenderIdx = FRT.TenderIdx
WHERE ds.StoreId =  @StoreId AND ds.isCurrentStore = 1 
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY DS.StoreId, DD.FullDate
)
--, Reconciliation AS ( 
--  SELECT 
--  DISTINCT ds.StoreId, st.ReconciliationDateIdx, ZNR, st.Amount 
--  FROM RBIM.Fact_ReconciliationSystemTotalPerTender st (NOLOCK)
--  JOIN RBIM.Dim_Store DS ON ds.StoreIdx = st.StoreIdx
--  JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = st.TotalTypeIdx
--  JOIN rbim.Dim_Date dd ON dd.DateIdx = st.ReconciliationDateIdx	
--  JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = st.TenderIdx
--  WHERE ds.StoreId =  @StoreId AND ds.isCurrentStore = 1
--  AND dd.FullDate BETWEEN @DateFrom AND @DateTo
--  AND dtt.TotalTypeId = 2 
--  AND dt.TenderId in ('1','8') 
--  )
--, Opptalt AS (
--SELECT  r.StoreId, dd.fulldate, SUM(Amount) AS TaltKontant FROM Reconciliation R (NOLOCK)
--JOIN rbim.Dim_Date dd ON dd.DateIdx = r.ReconciliationDateIdx
--GROUP BY r.StoreId, dd.fulldate
--)
, Reconciliation AS ( 
  SELECT 
  DISTINCT ds.StoreId, dd.FullDate, ZNR 
  FROM RBIM.Fact_ReconciliationSystemTotalPerTender st (NOLOCK)
  JOIN RBIM.Dim_Store DS ON ds.StoreIdx = st.StoreIdx
  JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = st.TotalTypeIdx
  JOIN rbim.Dim_Date dd ON dd.DateIdx = st.ReconciliationDateIdx	
  JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = st.TenderIdx
  WHERE ds.StoreId =  @StoreId AND ds.isCurrentStore = 1
  AND dd.FullDate BETWEEN @DateFrom AND @DateTo
  AND dtt.TotalTypeId = 2 
  AND dt.TenderId in ('1','8','9') 
  )
, OpptaltZ AS (
SELECT DISTINCT re.StoreId, re.FullDate, re.ZNR , FRCPT.Amount
FROM Reconciliation re (NOLOCK)
JOIN RBIM.Dim_Store AS DS ON DS.StoreId = re.StoreId
LEFT JOIN RBIM.Fact_ReconciliationCountingPerTender AS FRCPT ON FRCPT.ZNR = re.ZNR AND FRCPT.StoreIdx = DS.StoreIdx
AND FRCPT.RowIdx = (SELECT TOP 1 RowIdx FROM RBIM.Fact_ReconciliationCountingPerTender R WHERE R.StoreIdx=FRCPT.StoreIdx AND r.ZNR=FRCPT.ZNR ORDER BY R.RowIdx DESC  )
)
, Opptalt AS (
SELECT o.StoreId, o.FullDate, SUM(o.Amount) AS TaltKontant FROM OpptaltZ o
GROUP BY o.StoreId, o.FullDate
)
, Spill AS (
SELECT 
 DS.StoreId
,DD.FullDate
,SUM(ASARPD.SalesRevenueInclVat) AS SpilliKasse
FROM RBIM.Agg_SalesAndReturnPerDay AS ASARPD (NOLOCK)
JOIN RBIM.Dim_Store ds ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_Date AS DD ON dd.DateIdx=ASARPD.ReceiptDateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
WHERE ds.StoreId =  @StoreId AND ds.isCurrentStore = 1
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
AND da.Lev4ArticleHierarchyId='241230'
GROUP BY DS.StoreId, DD.FullDate
)
, PantoGevinst AS (
SELECT 
ds.StoreId
,DD.FullDate
,SUM(f.TotalAmount) AS PantoGevist
FROM RBIM.Fact_RvmReceipt f (NOLOCK)
JOIN RBIM.Dim_Store ds ON ds.StoreIdx = f.StoreIdx
JOIN RBIM.Dim_Date AS DD ON DD.DateIdx = f.DateIdx
WHERE ds.StoreId =  @StoreId AND ds.isCurrentStore = 1
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
AND transtypeIdx = 90307
GROUP BY DS.StoreId, DD.FullDate
)
, GaveKort AS (
SELECT 
 DS.StoreId
,DD.FullDate
,SUM(ASARPD.SalesRevenue-ASARPD.ReturnAmountExclVat) AS Gavekort
FROM RBIM.Agg_SalesAndReturnPerDay AS ASARPD (NOLOCK)
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_Date AS DD ON dd.DateIdx=ASARPD.ReceiptDateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
WHERE ds.StoreId =  @StoreId AND ds.isCurrentStore = 1
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
AND da.Lev3ArticleHierarchyId=2410 
GROUP BY DS.StoreId, DD.FullDate)

SELECT sr.StoreId, sr.FullDate 
,SR.NettoOmsetning
,SR.BruttoOmsetning
,RT.BankAxept
,RT.Kreditt
,RT.Kontant
,ISNULL(TA.TaltKontant,0) AS TaltKontant
--,RT.Kontant-TA.TaltKontant AS KontDifferanse
,ISNULL(TA.TaltKontant-RT.Kontant,0) AS KontDifferanse
,ISNULL(SIK.SpilliKasse,0) AS SpilliKasse
,ISNULL(RT.Retting,0) AS Retting
,ISNULL(PG.PantoGevist,0) AS PantoGevist
,ISNULL(GK.Gavekort,0) AS Gavekort
--,ISNULL(((RT.Kreditt+PG.PantoGevist+RT.BankAxept+TA.TaltKontant)-((TA.TaltKontant-RT.Kontant)+sr.BruttoOmsetning+SR.RoundingAmount))+SR.RoundingAmount,0) AS Interim
--,(RT.Kreditt+PG.PantoGevist+RT.BankAxept+NATTSAFE)
,ISNULL(SR.RoundingAmount,0) AS RoundingAmount
,ISNULL((SR.BruttoOmsetning-(RT.BankAxept+RT.Kreditt))-(TA.TaltKontant+(TA.TaltKontant-RT.Kontant)+SIK.SpilliKasse+RT.Retting+PG.PantoGevist+GK.Gavekort),0) AS SUM
FROM SalesAndReturnPerDay SR
LEFT JOIN ReciptTender RT	ON RT.StoreId = SR.StoreId  AND RT.FullDate = SR.FullDate
LEFT JOIN Opptalt TA		ON TA.StoreId = SR.StoreId  AND TA.FullDate = SR.FullDate
LEFT JOIN Spill SIK			ON SIK.StoreId = SR.StoreId AND SIK.FullDate = SR.FullDate
LEFT JOIN PantoGevinst PG	ON PG.StoreId = SR.StoreId  AND PG.FullDate = SR.FullDate
LEFT JOIN GaveKort GK		ON GK.StoreId = SR.StoreId  AND GK.FullDate = SR.FullDate 
ORDER BY 1, 2


END






GO

