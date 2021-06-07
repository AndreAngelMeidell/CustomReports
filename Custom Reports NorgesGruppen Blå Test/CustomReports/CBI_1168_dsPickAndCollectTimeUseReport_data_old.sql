USE [PickAndCollectDB]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1168_dsPickAndCollectTimeUseReport_data_old]    Script Date: 23.09.2020 09.25.32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[usp_CBI_1168_dsPickAndCollectTimeUseReport_data_old](
@StoreId	INT
,@DateFrom	DATE
,@DateTo	DATE
)
AS
BEGIN

--NG-321 Rapport for tidsforbruk
-- for test:
--DECLARE @StoreId AS INT = 4836
--DECLARE @DateFrom AS DATE = '2017-12-13'
--DECLARE @DateTo AS DATE = '2017-12-14'



; WITH 
PickedOrdre AS (
SELECT DCOCT.CustomerOrderNo, MAX(DCOCT.RecordCreated) as  MaxRecordCreated 
FROM  dbo.DeliveryCustomerOrderChangeTracking AS DCOCT 
JOIN dbo.DeliveryCustomerOrders AS DCO ON DCO.CustomerOrderNo = DCOCT.CustomerOrderNo
WHERE DCOCT.OrderStatus=50
AND CAST(DCOCT.RecordCreated AS DATE) >= @DateFrom 
AND CAST(DCOCT.RecordCreated AS DATE) <= @DateTo
AND DCO.StoreNo=@StoreId
GROUP BY DCOCT.CustomerOrderNo
)
,
StartInfo AS (SELECT DCOCT.CustomerOrderNo, MIN(DCOCT.RecordCreated) AS  MinRecordCreated
FROM  dbo.DeliveryCustomerOrderChangeTracking AS DCOCT 
JOIN dbo.DeliveryCustomerOrders AS DCO ON DCO.CustomerOrderNo = DCOCT.CustomerOrderNo
WHERE DCOCT.OrderStatus=40
AND dco.CustomerOrderNo IN (SELECT DISTINCT PickedOrdre.CustomerOrderNo FROM  PickedOrdre)
GROUP BY DCOCT.CustomerOrderNo
)
, SumPicked AS (
SELECT DCOL.CustomerOrderNo,SUM(DCOL.DeliveredQty) AS DeliveredQty, SUM(DCOL.ArticleDeliveredPrice*DCOL.DeliveredQty) AS DeliveredPrice 
FROM dbo.DeliveryCustomerOrderLines AS dcol WHERE dcol.CustomerOrderLineStatus >= 60
AND DCOL.CustomerOrderNo IN (SELECT DISTINCT PickedOrdre.CustomerOrderNo FROM  PickedOrdre)
GROUP BY DCOL.CustomerOrderNo
)

SELECT DCO.StoreName,dco.OrderID, DCO.OrderPickedDate,dco.PickedByEmployee as DeliveredByEmployee, DCO.ShoppingBagsDry, DCO.ShoppingBagsCool, DCO.ShoppingBagsFridge
,SP.DeliveredQty, dco.ActualAmount
,Si.MinRecordCreated AS StartedPicked, pi.MaxRecordCreated AS Picked
,CONVERT(VARCHAR(8),DATEADD(ms,DATEDIFF(SECOND,MinRecordCreated, MaxRecordCreated)*1000,104),114)  AS 'Time_Used'
FROM PickedOrdre pi
JOIN StartInfo Si ON si.CustomerOrderNo = pi.CustomerOrderNo
JOIN dbo.DeliveryCustomerOrders AS DCO ON DCO.CustomerOrderNo = pi.CustomerOrderNo
JOIN SumPicked SP ON sp.CustomerOrderNo=dco.CustomerOrderNo
ORDER BY pi.MaxRecordCreated


END  


GO

