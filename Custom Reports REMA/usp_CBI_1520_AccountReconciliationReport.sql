USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1520_AccountReconciliationReport]    Script Date: 15.01.2019 09:10:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1520_AccountReconciliationReport]
(   
    @StoreId AS VARCHAR(100),
	@DateFrom AS DATE
)
AS  
BEGIN

DECLARE @DateTo AS DATE = @DateFrom

-- REMA VD-1900 lik kontoavstemming men hentet fra BI tabeller basert på bonger. Ikke Account
-- DECLARE @StoreOrGroupNo AS VARCHAR(MAX) = 2079
-- DECLARE @DateFrom AS DATE = '2018-10-15' 
-- DECLARE @DateTo AS DATE = '2018-10-15'

;WITH SalesAndReturnPerDay AS (
SELECT DS.StoreId, DD.FullDate
,SUM(CASE WHEN ASARPD.VatGroup=0  AND DA.Lev4ArticleHierarchyId<>'241232'  THEN ASARPD.SalesAmount+ASARPD.ReturnAmount ELSE 0.00 END) AS SalesLowVat
,SUM(CASE WHEN ASARPD.VatGroup=15 AND DA.Lev4ArticleHierarchyId<>'241232'  THEN ASARPD.SalesAmount+ASARPD.ReturnAmount ELSE 0.00 END) AS SalesMedVat
,SUM(CASE WHEN ASARPD.VatGroup=25 AND DA.Lev4ArticleHierarchyId<>'241232'  THEN ASARPD.SalesAmount+ASARPD.ReturnAmount ELSE 0.00 END) AS SalesHighVat
,SUM(CASE WHEN ASARPD.RoundingAmount IS NOT null  THEN ASARPD.RoundingAmount ELSE 0.00 END) AS RoundingAmount
,SUM(CASE WHEN ASARPD.SalesAmount IS NOT NULL AND DA.Lev4ArticleHierarchyId='241232'  THEN ASARPD.SalesAmount+ASARPD.ReturnAmount ELSE 0.00 END) AS PantoGevinst
FROM RBIM.Agg_VatGroupSalesAndReturnPerDay AS ASARPD (NOLOCK)
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_Date AS DD ON dd.DateIdx=ASARPD.ReceiptDateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
WHERE ds.StoreId =  @StoreId --AND ds.isCurrentStore = 1
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
AND da.Lev4ArticleHierarchyId NOT IN ('241230','241231','241232','241010','241098','241013','241011','241010') --SIK
AND da.Lev3ArticleHierarchyId NOT IN ('2410')  --Gavekort
GROUP BY DS.StoreId, DD.FullDate
)
--SELECT * FROM SalesAndReturnPerDay --OK
, ReciptTender AS (
SELECT 
 DS.StoreId
,DD.FullDate
,SUM(CASE WHEN frt.TenderIdx IN ('1','9') THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Kontant
,SUM(CASE WHEN frt.TenderIdx IN ('3','5','14') AND FRT.SubTenderIdx=1 THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Bankkort
,SUM(CASE WHEN frt.TenderIdx IN ('3','5','14') AND FRT.SubTenderIdx=2 THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Visa
,SUM(CASE WHEN frt.TenderIdx IN ('3','5','14') AND FRT.SubTenderIdx=3 THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS MasterCard
,SUM(CASE WHEN frt.TenderIdx IN ('3','5','14') AND FRT.SubTenderIdx=4 THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS AmericanExpress
,SUM(CASE WHEN frt.TenderIdx IN ('3','5','14') AND FRT.SubTenderIdx=9 THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Maestro
,SUM(CASE WHEN frt.TenderIdx IN ('6')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Kreditt 
,SUM(CASE WHEN frt.TenderIdx IN ('23')   THEN frt.Amount*ISNULL(NULLIF(frt.ExchangeRateToLocalCurrency,0.0),1.0) ELSE 0.00 END) AS Retting 
FROM RBIM.Fact_ReceiptTender AS FRT (NOLOCK)
JOIN RBIM.Dim_Date AS DD ON dd.DateIdx=frt.ReceiptDateIdx
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = FRT.StoreIdx
LEFT JOIN RBIM.Dim_Tender AS DT ON DT.TenderIdx = FRT.TenderIdx
WHERE ds.StoreId =  @StoreId --AND ds.isCurrentStore = 1
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
GROUP BY DS.StoreId, DD.FullDate
)
, Reconciliation AS ( 
  SELECT 
  DISTINCT ds.StoreId, st.CountingDateIdx, ZNR, st.Amount 
  FROM RBIM.Fact_ReconciliationCountingPerTender st (NOLOCK)
  JOIN RBIM.Dim_Store ds ON ds.StoreIdx = st.StoreIdx
  JOIN RBIM.Dim_TotalType dtt ON dtt.TotalTypeIdx = st.TotalTypeIdx
  JOIN rbim.Dim_Date dd ON dd.DateIdx = st.CountingDateIdx	
  JOIN RBIM.Dim_Tender dt ON dt.TenderIdx = st.TenderIdx
  WHERE ds.StoreId =  @StoreId --AND ds.isCurrentStore = 1
  AND dd.FullDate BETWEEN @DateFrom AND @DateTo
  AND dtt.TotalTypeId = 2 
  AND dt.TenderId in ('1','8') 
  )
, Opptalt AS (
SELECT  r.StoreId, dd.fulldate, SUM(Amount) AS TaltKontant FROM Reconciliation R (NOLOCK)
JOIN rbim.Dim_Date dd ON dd.DateIdx = r.CountingDateIdx
GROUP BY r.StoreId, dd.fulldate
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
WHERE ds.StoreId =  @StoreId --AND ds.isCurrentStore = 1
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
WHERE ds.StoreId =  @StoreId --AND ds.isCurrentStore = 1
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
WHERE ds.StoreId =  @StoreId --AND ds.isCurrentStore = 1
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
AND da.Lev3ArticleHierarchyId=2410 
GROUP BY DS.StoreId, DD.FullDate)
, Total AS (
SELECT SR.StoreId, SR.FullDate
,ISNULL((RT.Kreditt+PG.PantoGevist+RT.Bankkort+RT.MasterCard+RT.Visa+TA.TaltKontant)-((TA.TaltKontant-RT.Kontant)+SR.SalesHighVat+SR.SalesMedVat+SR.SalesLowVat+SR.RoundingAmount+SIK.SpilliKasse+GK.Gavekort),0) AS Interim
,ISNULL((TA.TaltKontant-RT.Kontant),0) AS KontantDifferanse
,ISNULL(SR.SalesHighVat,0) AS SalesHighVat
,ISNULL(SR.SalesMedVat,0) AS SalesMedVat
,ISNULL(SR.SalesLowVat,0) AS SalesLowVat
,ISNULL(SR.RoundingAmount,0) AS RoundingAmount
,ISNULL(RT.Kreditt,0) AS KontoSalg
,ISNULL(PG.PantoGevist,0) AS PantoGevist
,ISNULL(RT.Bankkort,0) AS Bankkort
,ISNULL(RT.MasterCard,0) AS MasterCard
,ISNULL(RT.Visa,0) AS Visa
,ISNULL(RT.AmericanExpress,0) AS AmericanExpress
,ISNULL(RT.Maestro,0) AS Maestro
,ISNULL(TA.TaltKontant,0) AS Nattsafe
,ISNULL(SIK.SpilliKasse,0) AS Spillikasse
,ISNULL(GK.Gavekort,0) AS Gavekort
FROM SalesAndReturnPerDay SR
LEFT JOIN ReciptTender RT	ON RT.StoreId = SR.StoreId  AND RT.FullDate = SR.FullDate
LEFT JOIN Opptalt TA		ON TA.StoreId = SR.StoreId  AND TA.FullDate = SR.FullDate
LEFT JOIN Spill SIK			ON SIK.StoreId = SR.StoreId AND SIK.FullDate = SR.FullDate
LEFT JOIN PantoGevinst PG	ON PG.StoreId = SR.StoreId  AND PG.FullDate = SR.FullDate
LEFT JOIN GaveKort GK		ON GK.StoreId = SR.StoreId  AND GK.FullDate = SR.FullDate 
)

SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.Interim AS 'Kredittbeløp', 'Interim' AS KredittTekst  FROM Total t
UNION all
SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.KontantDifferanse AS 'Kredittbeløp', 'KontantDifferanse' AS KredittTekst  FROM Total t
UNION all
SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.SalesHighVat AS 'Kredittbeløp', 'Salg 25%' AS KredittTekst  FROM Total t
UNION all
SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.SalesMedVat AS 'Kredittbeløp', 'Salg 15%' AS KredittTekst  FROM Total t
UNION all
SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.SalesLowVat AS 'Kredittbeløp', 'Salg 0%' AS KredittTekst  FROM Total t
UNION ALL
SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.Spillikasse AS 'Kredittbeløp', 'Spill i kasse' AS KredittTekst  FROM Total t
UNION ALL
SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.Gavekort AS 'Kredittbeløp', 'Gavekort' AS KredittTekst  FROM Total t
UNION all
SELECT 0 AS 'Debetbeløp', '' AS DebetTekst, t.RoundingAmount AS 'Kredittbeløp', 'Øreavrunding' AS KredittTekst  FROM Total t
UNION all
SELECT t.KontoSalg AS 'Debetbeløp', 'Kontosalg' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t
UNION all
SELECT t.PantoGevist AS 'Debetbeløp', 'PantoGevinst' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t
UNION all
SELECT t.Bankkort AS 'Debetbeløp', 'Bankkort' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t
UNION all
SELECT t.MasterCard AS 'Debetbeløp', 'MasterCard' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t
UNION ALL
SELECT t.Visa AS 'Debetbeløp', 'Visa' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t
UNION ALL
SELECT t.AmericanExpress AS 'Debetbeløp', 'AmericanExpress' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t
UNION ALL
SELECT t.Maestro AS 'Debetbeløp', 'Maestro' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t
UNION all
SELECT t.Nattsafe AS 'Debetbeløp', 'Nattsafe' AS DebetTekst, 0 AS 'Kredittbeløp', '' AS KredittTekst   FROM Total t


END






GO

