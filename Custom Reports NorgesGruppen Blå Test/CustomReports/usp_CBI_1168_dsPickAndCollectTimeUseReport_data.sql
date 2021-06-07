USE [PickAndCollectDB]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1168_dsPickAndCollectTimeUseReport_data]    Script Date: 25.09.2020 12:13:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1168_dsPickAndCollectTimeUseReport_data](
@StoreId	INT
,@DateFrom	DATE
,@DateTo	DATE
)
AS
BEGIN

--NG-321 Rapport for tidsforbruk
-- for test:
--DECLARE @StoreId AS INT = 10446
--DECLARE @DateFrom AS DATE = '2017-12-13'
--DECLARE @DateTo AS DATE = '2021-12-14'

IF OBJECT_ID('tempdb..#DCOCT') IS NOT NULL 
BEGIN 
    DROP TABLE #DCOCT
END

IF OBJECT_ID('tempdb..#PickTime') IS NOT NULL 
BEGIN 
    DROP TABLE #PickTime
END

IF OBJECT_ID('tempdb..#DCOCL') IS NOT NULL 
BEGIN 
    DROP TABLE #DCOCL
END

SELECT
	dco.CustomerOrderNo
	,dco.StoreName
	,dcoct.OrderStatus
	,dcoct.RecordCreated
	,dcoct.ModifiedByUserID
	,dcoct.DeliveryCustomerOrderChangeTrackingNo
	,DCO.OrderPickedDate
	,DCO.OrderID
	,dco.ShoppingBagsDry
	,dco.ShoppingBagsCool
	,dco.ShoppingBagsFridge
	,dco.ActualAmount
INTO
	#DCOCT
FROM
	dbo.DeliveryCustomerOrderChangeTracking dcoct
		LEFT JOIN
	dbo.DeliveryCustomerOrders dco ON dcoct.CustomerOrderNo = dco.CustomerOrderNo
WHERE	
	CAST(dco.OrderPickedDate AS DATE) >= @DateFrom 
	AND CAST(DCO.OrderPickedDate AS DATE) <= @DateTo
	AND DCO.StoreNo=@StoreId	
	AND dcoct.OrderStatus IN (40,50)

--select * from #DCOCT

SELECT
	dcol.CustomerOrderNo
	,dcol.CustomerOrderLineNo
	,dcol.ModifiedDate
	,'' AS ChangeTrackingStatus
INTO
	#DCOCL
FROM
	dbo.DeliveryCustomerOrderLines dcol
WHERE
	dcol.CustomerOrderNo IN (SELECT CustomerOrderNo FROM #DCOCT)
	AND dcol.CustomerOrderLineStatus=60


SELECT
	DCOCT_START.CustomerOrderNo
	,DCOCT_START.ModifiedByUserID AS Picker
	,MIN(DCOCT_START.RecordCreated) AS StartPicked
	,MAX(COALESCE(DCOCT_STOP.RecordCreated,DCOCL_STOP.ModifiedDate)) AS StopPicked
	,SUM(DATEDIFF(SECOND,DCOCT_START.RecordCreated,COALESCE(DCOCT_STOP.RecordCreated,DCOCL_STOP.ModifiedDate))) AS SecondsUsed
INTO #PickTime
FROM 
	#DCOCT DCOCT_START
		OUTER APPLY
			(
			SELECT
				TOP 1 DCOCT.RecordCreated
			FROM
				#DCOCT DCOCT
			WHERE
				DCOCT.CustomerOrderNo=DCOCT_start.CustomerOrderNo
				AND DCOCT.OrderStatus=50
				AND DCOCT.DeliveryCustomerOrderChangeTrackingNo > dcoct_START.DeliveryCustomerOrderChangeTrackingNo
				ORDER BY
					1 ASC
			) DCOCT_STOP
		OUTER APPLY
			(
			SELECT
				TOP 1 DCOCL.ModifiedDate
			FROM
				#DCOCL DCOCL
			WHERE
				DCOCL.ModifiedDate > DCOCT_START.RecordCreated 
				AND DCOCL.CustomerOrderNo = DCOCT_START.CustomerOrderNo				
				AND DCOCL.ModifiedDate < (SELECT max(D.RecordCreated) FROM #DCOCT D WHERE D.CustomerOrderNo = DCOCL.CustomerOrderNo AND d.RecordCreated > DCOCL.ModifiedDate AND d.OrderStatus=40)
			ORDER BY
				DCOCL.ModifiedDate asc
			) DCOCL_STOP

WHERE
	DCOCT_START.OrderStatus=40
	--AND DCOCT_STOP.RecordCreated IS NOT NULL
GROUP BY
	DCOCT_START.CustomerOrderNo
	,DCOCT_START.ModifiedByUserID
WITH rollup

DELETE FROM #PickTime WHERE CustomerOrderNo IS NULL AND Picker IS NULL
UPDATE #PickTime SET Picker = 'Total' WHERE Picker IS NULL
UPDATE #PickTime SET StopPicked = StartPicked, SecondsUsed = 0 WHERE StopPicked IS NULL
--SELECT * FROM #PickTime pt


; WITH 
PickedOrdre AS (
SELECT
	PT.CustomerOrderNo
	,PT.Picker
	,PT.StartPicked
	,PT.StopPicked
	,PT.SecondsUsed

FROM 
	#PickTime pt
), 

SumPicked AS (
SELECT 
		DCOL.CustomerOrderNo,
		SUM(DCOL.DeliveredQty) AS DeliveredQty
		,SUM(DCOL.ArticleDeliveredPrice*DCOL.DeliveredQty) AS DeliveredPrice 
FROM 
	dbo.DeliveryCustomerOrderLines AS dcol 
		INNER JOIN
	#DCOCT d ON dcol.CustomerOrderNo = d.CustomerOrderNo
WHERE 
	dcol.CustomerOrderLineStatus >= 60
	
GROUP BY 
	DCOL.CustomerOrderNo
)
SELECT 
	DCO.StoreName
	,dco.OrderID
	,DCO.OrderPickedDate
	,pi.Picker as DeliveredByEmployee
	,DCO.ShoppingBagsDry
	,DCO.ShoppingBagsCool
	,DCO.ShoppingBagsFridge
	,SP.DeliveredQty
	,sp.DeliveredPrice AS ActualAmount
	,pi.StartPicked AS StartedPicked
	,pi.StopPicked AS Picked
	,CONVERT(VARCHAR(8),DATEADD(ss,PI.SecondsUsed,0),114)  AS 'Time_Used'

FROM 
	PickedOrdre pi
		JOIN 
	dbo.DeliveryCustomerOrders AS DCO ON DCO.CustomerOrderNo = pi.CustomerOrderNo
		JOIN 
	SumPicked SP ON sp.CustomerOrderNo=dco.CustomerOrderNo
ORDER BY 
	dco.CustomerOrderNo



END  




GO

